
# backup-module: 1.0

function Get-BakPolicy() {
    param (
        $Path,
        $DatePattern,
        $Prefix,
        $Postfix,
        $Daily,
        $Weekly,
        $Monthly,
        $Annual
    )
    @{
        Path = $Path;
        DatePattern = $DatePattern;
        Prefix = $Prefix;
        Postfix = $Postfix;
        Daily = $Daily;
        Weekly = $Weekly;
        Monthly = $Monthly;
        Annual = $Annual;
    }
}

function Remove-BakFiles($BakPolicy, $Path, [switch]$Recurse, $FtpConn, $Log) {
    
    $LogLabel = 'Remove-BakFiles'

    if (-not [string]::IsNullOrEmpty($Path)) {
        $BakPath = $Path
    }
    else {
        $BakPath = $BakPolicy.Path
    }

    $RemovedFiles = @()

    Out-Log -Log $Log -Label $LogLabel -Text ('Get all backup files: ' + $BakPath)
    $FilesWithDate = Get-BakFilesWithDate -BakPath $BakPath -DatePattern $BakPolicy.DatePattern -Prefix $BakPolicy.Prefix -Postfix $BakPolicy.Postfix -Recurse:$Recurse -FtpConn $FtpConn

    Out-Log -Log $Log -Label $LogLabel -Text 'Get backup files to remove...'
    [object[]]$FilesToRemove = (Get-BakFilesToRemove -BakFilesWithDate $FilesWithDate -BakPolicy $BakPolicy)

    if ($FilesToRemove.Count -gt 0) {
        
        Out-Log -Log $Log -Label $LogLabel -Text ('Removing (' + $FilesToRemove.count + ') backup files...')

        foreach ($FileItem in $FilesToRemove) {
            $Item = $FileItem.Item
            if ($FtpConn -ne $null) {
                $IsRemoved = Remove-FtpItem -Conn $FtpConn -Path $Item.FilePath
                if ($IsRemoved) {
                    $RemovedFiles += $Item.FullName
                }
            }
            else {
                Remove-Item -Path $Item.FullName -Force
                $RemovedFiles += $Item.FullName
            }
        }

        Out-Log -Log $Log -Label $LogLabel -Text 'Removed backup files:'
        foreach ($FileName in $RemovedFiles) {
            Out-Log -Log $Log -Label $LogLabel -Text ('- ' + $FileName)
        }

    }
    else {
        Out-Log -Log $Log -Label $LogLabel -Text 'No backup files to remove.'
    }

    $RemovedFiles
}

function Get-BakFilesWithDate($BakPath, $DatePattern, $Prefix, $Postfix, [switch]$Recurse, $FtpConn) {

    # yyyyMMdd-HHddss -> (?<y>\d{4})(?<mon>\d{2})(?<d>\d{2})-(?<h>\d{2})(?<min>\d{2})(?<s>\d{2})
    $DatePattern = $DatePattern.Replace('yyyy', '(?<y>\d{4})')
    $DatePattern = $DatePattern.Replace('yy', '(?<y>\d{2})')
    $DatePattern = $DatePattern.Replace('MM', '(?<mon>\d{2})')
    $DatePattern = $DatePattern.Replace('dd', '(?<d>\d{2})')
    $DatePattern = $DatePattern.Replace('HH', '(?<h>\d{2})')
    $DatePattern = $DatePattern.Replace('mm', '(?<min>\d{2})')
    $DatePattern = $DatePattern.Replace('ss', '(?<s>\d{2})')
    $DatePattern = '(\D|^)' + $DatePattern + '(\D|$)'

    if ($FtpConn -ne $null) {
        $FtpItems = Get-FtpChildItem -Conn $FtpConn -Path $BakPath -Recurse:$Recurse;
        $BakFiles = $FtpItems.Where({$_.Name -Like ($Prefix + '*' + $Postfix)})
    }
    else {
        $BakFiles = Get-ChildItem -Path $BakPath -File -Filter ($Prefix + '*' + $Postfix) -Recurse:$Recurse
    }

    $FilesWithDate = @()

    foreach ($BakItem in $BakFiles) {

        $BaseName = $BakItem.BaseName
        if ($BaseName -match $DatePattern) {
            $Year = $Matches.y
            if (($Year -gt 0) -and ($Year -lt 100)) {
                $Year = 2000 + $Year
            }  
            $BakDate = [datetime]::new($Year, $Matches.mon, $Matches.d)
            $BakDateTime = [datetime]::new($Year, $Matches.mon, $Matches.d, $Matches.h, $Matches.min, $Matches.s)
            $FileWithDate = @{
                Item = $BakItem;
                Date = $BakDate;
                DateTime = $BakDate;
            }
            $FilesWithDate += New-Object PSCustomObject -Property $FileWithDate
        }
    }

    $FilesWithDate
}

function Get-BakFilesToRemove($BakFilesWithDate, $BakPolicy) {

    $BakDates = $BakFilesWithDate | Select-Object -Property Date -Unique

    $BakDatesToKeep = @()
    $BakDatesToKeep += Get-BakDatesToKeep -BakDates $BakDates -Period 'y' -PeriodCount $BakPolicy.Annual
    $BakDatesToKeep += Get-BakDatesToKeep -BakDates $BakDates -Period 'm' -PeriodCount $BakPolicy.Monthly
    $BakDatesToKeep += Get-BakDatesToKeep -BakDates $BakDates -Period 'w' -PeriodCount $BakPolicy.Weekly
    $BakDatesToKeep += Get-BakDatesToKeep -BakDates $BakDates -Period 'd' -PeriodCount $BakPolicy.Daily
    $BakDatesToKeep  = $BakDatesToKeep | Select-Object -Unique | Sort-Object

    $BakFilesToRemove = @()
    if ($BakDatesToKeep.Count -gt 0) {
        foreach ($BakFileWithDate in $BakFilesWithDate) {
            if ($BakFileWithDate.Date -notin $BakDatesToKeep) {
                $BakFilesToRemove += $BakFileWithDate
            }
        }
    }

    $BakFilesToRemove
}

function Get-BakDatesToKeep($BakDates, $Period, $PeriodCount) {
    
    $NextPeriodBegin = Get-BakPeriodBegin -Date (Get-Date) -Period $Period
    $NextPeriodEnd = Get-BakNextPeriod -Date $NextPeriodBegin -Period $Period

    $BakDatesToKeep = @()
    for ($i = 0; $i -le $PeriodCount; $i++) {
        $PeriodBegin = $NextPeriodBegin 
        $PeriodEnd = $NextPeriodEnd
        $FindedDates = $BakDates.Where({($_.Date -ge $PeriodBegin) -and ($_.Date -lt $PeriodEnd)}) | Sort-Object -Property Date | Select-Object -Property Date -First 1
        if ($FindedDates.Date -ne $null) {
            $BakDatesToKeep += $FindedDates.Date
        }
        # Next period is erler
        $NextPeriodBegin = Get-BakNextPeriod -Date $PeriodBegin -Period $Period -PeriodCount -1 
        $NextPeriodEnd = $PeriodBegin
    }

    $BakDatesToKeep
}

function Get-BakPeriodBegin([datetime]$Date, $Period) {
    if ($Period -like 'd') {
        return [datetime]::new($Date.Year, $Date.Month, $Date.Day) 
    }
    elseif ($Period -like 'w') {
        $Date = Get-BakPeriodBegin -Date $Date -Period 'd'
        return $Date.AddDays(-$Date.DayOfWeek.value__ + 1)
    }
    elseif ($Period -like 'm') {
        return [datetime]::new($Date.Year, $Date.Month, 1)
    }
    elseif ($Period -like 'y') {
        return [datetime]::new($Date.Year, 1, 1)
    }
}

function Get-BakNextPeriod([datetime]$Date, $Period, [int]$PeriodCount = 1) {
    if ($Period -like 'd') {
        return $Date.AddDays($PeriodCount)
    }
    elseif ($Period -like 'w') {
        return $Date.AddDays(($PeriodCount * 7))
    }
    elseif ($Period -like 'm') {
        return $Date.AddMonths($PeriodCount)
    }
    elseif ($Period -like 'y') {
        return $Date.AddYears($PeriodCount)
    }
}
