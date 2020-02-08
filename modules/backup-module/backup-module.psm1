
# backup-module: 1.1

$FtpPostfix = '-up2ftp'

function Get-BakPolicy() {
    param (
        $Path,
        $DatePattern,
        $Prefix,
        $Postfix,
        $Daily,
        $Weekly,
        $Monthly,
        $Annual,
        $BakPolicy
    )

    # Init structure.
    $Result = @{
        Path = $Path;
        DatePattern = $DatePattern;
        Prefix = $Prefix;
        Postfix = $Postfix;
        Daily = $Daily;
        Weekly = $Weekly;
        Monthly = $Monthly;
        Annual = $Annual;
    }
    
    # Copy null keys from BakPolicy.
    if ($BakPolicy -ne $null) {
        foreach ($Key in $BakPolicy.Keys) {
            if ($Result[$Key] -eq $null) {
                $Result[$Key] = $BakPolicy[$Key]
            }
        }
    }

    $Result
}

function Invoke-BakSendToFtpAndRemoveOutdated($BakPolicyLocal, $FtpConn, $BakPolicyFtp, [switch]$Recurse, $Log) {
    
    $LogLable = 'Send-Remove'

    Out-Log -Log $Log -Label $LogLable, Start

    Out-Log -Log $Log -Label $LogLable, Send2Ftp -Text ('Local: ' + $BakPolicyLocal.Path + ', FTP: ' + $BakPolicyFtp.Path)

    # Send backup-fiels to FTP-server
    Send-BakToFtp -BakPolicy $BakPolicyLocal -FtpConn $FtpConn -FtpPath $BakPolicyFtp.Path -Log $Log -Recurse:$Recurse | Out-Null

    Out-Log -Log $Log -Label $LogLable, Remove-Local

    # Remove outdated backup-files on local/net file system
    Remove-BakFiles -BakPolicy $BakPolicyLocal -Recurse:$Recurse -Log $Log -OnlyUploadedToFtp | Out-Null

    Out-Log -Log $Log -Label $LogLable, Remove-FTP

    # Remove outdated backup-files on FTP-server
    Remove-BakFiles -BakPolicy $BakPolicyFtp -Recurse:$Recurse -Log $Log -FtpConn $FtpConn | Out-Null

    Out-Log -Log $Log -Label $LogLable, End

}

function Send-BakToFtp($BakPolicy, $LocalPath, $FtpConn, $FtpPath, [switch]$Recurse, $Log) {

    $LogLabel = 'Send-BakToFtp'
    
    if ($LocalPath -eq $null) {
        $LocalPath = $BakPolicy.Path
    }
    
    Out-Log -Log $Log -Label $LogLabel, Start

    $SendedFiles = @()
    $CheckedFtpPaths = @()

    $BakFiles = Get-AuxBakFilesWithDate -BakPolicy $BakPolicy -Path $LocalPath -FtpConn $null -Recurse:$Recurse
    $BakFiles = ([PSCustomObject[]]$BakFiles).Where({-not $_.Item.BaseName.EndsWith($FtpPostfix)})

    foreach ($BakFileLine in $BakFiles) {

        $BakItem = $BakFileLine.Item

        $RelativePath = ([string]$BakItem.DirectoryName).Substring($LocalPath.Length)
        $FtpDirectoryPath = Add-FtpUrlPath -Url $FtpPath -SubUrl $RelativePath.Replace('\', '/')

        if (($FtpDirectoryPath -gt '/') -and ($FtpDirectoryPath -notin $CheckedFtpPaths)) {
            if (-not (Test-FtpItem -Conn $FtpConn -Path $FtpDirectoryPath -Recurse)) {
                New-FtpDirectory -Conn $FtpConn -Path $FtpDirectoryPath -Force | Out-Null
            }
            $CheckedFtpPaths += $FtpDirectoryPath
        }

        Out-Log -Log $Log -Label $LogLabel, Send-backup -Text $BakItem.FullName

        $FileSended = Send-FtpFile -Conn $FtpConn -Path $FtpDirectoryPath -LocalPath $BakItem.FullName
        if ($FileSended) {
            $SendedFiles += $BakItem
            Rename-Item -Path $BakItem.FullName -NewName ($BakItem.BaseName + $FtpPostfix + $BakItem.Extension) -Force
        }
        else {
            Out-Log -Log $Log -Label $LogLabel, Error -Text ('File not sended to ftp: ' + $BakItem.FullName)
        }
    
    }

    Out-Log -Log $Log -Label $LogLabel, End

    $SendedFiles
}

function Remove-BakFiles($BakPolicy, $Path, [switch]$Recurse, $FtpConn, $Log, [switch]$OnlyUploadedToFtp) {
    
    $LogLabel = 'Remove-BakFiles'

    if (-not [string]::IsNullOrEmpty($Path)) {
        $BakPath = $Path
    }
    else {
        $BakPath = $BakPolicy.Path
    }

    $RemovedFiles = @()

    $Prefix = $BakPolicy.Prefix
    $Postfix = $BakPolicy.Postfix

    Out-Log -Log $Log -Label $LogLabel -Text ('Get all backup files: ' + $BakPath)
    $FilesWithDate = Get-AuxBakFilesWithDate -BakPolicy $BakPolicy -Path $BakPath -Recurse:$Recurse -FtpConn $FtpConn

    if (($FtpConn -eq $null) -and $OnlyUploadedToFtp) {
        $FilesWithDate = ([PSCustomObject[]]$FilesWithDate).Where({$_.Item.BaseName.EndsWith($FtpPostfix)})
    }

    Out-Log -Log $Log -Label $LogLabel -Text 'Get backup files to remove...'
    [object[]]$FilesToRemove = Get-AuxBakFilesToRemove -BakFilesWithDate $FilesWithDate -BakPolicy $BakPolicy

    if ($FilesToRemove.Count -gt 0) {
        
        Out-Log -Log $Log -Label $LogLabel -Text ('Removing (' + $FilesToRemove.count + ') backup files...')

        foreach ($FileItem in $FilesToRemove) {
            $Item = $FileItem.Item
            if ($FtpConn -ne $null) {
                $IsRemoved = Remove-FtpItem -Conn $FtpConn -Path $Item.Path
                if ($IsRemoved) {
                    Out-Log -Log $Log -Label $LogLabel -Text ('Removed: ' + $Item.FullName)
                    $RemovedFiles += $Item.FullName
                }
                else {
                    Out-Log -Log $Log -Label $LogLabel, Error -Text ('Not removed: ' + $Item.Path)
                }
            }
            else {
                Remove-Item -Path $Item.FullName -Force
                Out-Log -Log $Log -Label $LogLabel -Text ('Removed: ' + $Item.FullName)
                $RemovedFiles += $Item.FullName
            }
        }

        Out-Log -Log $Log -Label $LogLabel, End -Text 'Removed backup files.'

    }
    else {
        Out-Log -Log $Log -Label $LogLabel, End -Text 'No backup files to remove.'
    }

    $RemovedFiles
}

function Get-AuxBakFilesWithDate($BakPolicy, $Path, [switch]$Recurse, $FtpConn) {

    $DatePattern = $BakPolicy.DatePattern
    $Prefix = $BakPolicy.Prefix
    $Postfix = $BakPolicy.Postfix

    # yyyyMMdd-HHddss -> (?<y>\d{4})(?<mon>\d{2})(?<d>\d{2})-(?<h>\d{2})(?<min>\d{2})(?<s>\d{2})
    $DatePattern = $DatePattern.Replace('yyyy', '(?<y>\d{4})')
    $DatePattern = $DatePattern.Replace('yy', '(?<y>\d{2})')
    $DatePattern = $DatePattern.Replace('MM', '(?<mon>\d{2})')
    $DatePattern = $DatePattern.Replace('dd', '(?<d>\d{2})')
    $DatePattern = $DatePattern.Replace('HH', '(?<h>\d{2})')
    $DatePattern = $DatePattern.Replace('mm', '(?<min>\d{2})')
    $DatePattern = $DatePattern.Replace('ss', '(?<s>\d{2})')

    if ($FtpConn -ne $null) {
        $FtpItems = Get-FtpChildItem -Conn $FtpConn -Path $BakPath -Recurse:$Recurse;
        $BakFiles = ([PSCustomObject[]]$FtpItems).Where({$_.Name -Like ($Prefix + '*' + $Postfix)})
    }
    else {
        $BakFiles = Get-ChildItem -Path $Path -File -Filter ($Prefix + '*' + $Postfix) -Recurse:$Recurse
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

function Get-AuxBakFilesToRemove($BakFilesWithDate, $BakPolicy) {

    [object[]]$BakDates = $BakFilesWithDate | Select-Object -Property Date -Unique

    $BakDatesToKeep = @()
    $BakDatesToKeep += Get-AuxBakDatesToKeep -BakDates $BakDates -Period 'y' -PeriodCount $BakPolicy.Annual
    $BakDatesToKeep += Get-AuxBakDatesToKeep -BakDates $BakDates -Period 'm' -PeriodCount $BakPolicy.Monthly
    $BakDatesToKeep += Get-AuxBakDatesToKeep -BakDates $BakDates -Period 'w' -PeriodCount $BakPolicy.Weekly
    $BakDatesToKeep += Get-AuxBakDatesToKeep -BakDates $BakDates -Period 'd' -PeriodCount $BakPolicy.Daily
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

function Get-AuxBakDatesToKeep($BakDates, $Period, $PeriodCount) {
    
    $NextPeriodBegin = Get-AuxBakPeriodBegin -Date (Get-Date) -Period $Period
    $NextPeriodEnd = Get-AuxBakNextPeriod -Date $NextPeriodBegin -Period $Period

    $BakDatesToKeep = @()
    for ($i = 0; $i -le $PeriodCount; $i++) {
        $PeriodBegin = $NextPeriodBegin 
        $PeriodEnd = $NextPeriodEnd
        $FindedDates = ([PSCustomObject[]]$BakDates).Where({($_.Date -ge $PeriodBegin) -and ($_.Date -lt $PeriodEnd)}) | Sort-Object -Property Date | Select-Object -Property Date -First 1
        if ($FindedDates.Date -ne $null) {
            $BakDatesToKeep += $FindedDates.Date
        }
        # Next period is erler
        $NextPeriodBegin = Get-AuxBakNextPeriod -Date $PeriodBegin -Period $Period -PeriodCount -1 
        $NextPeriodEnd = $PeriodBegin
    }

    $BakDatesToKeep
}

function Get-AuxBakPeriodBegin([datetime]$Date, $Period) {
    if ($Period -like 'd') {
        return [datetime]::new($Date.Year, $Date.Month, $Date.Day) 
    }
    elseif ($Period -like 'w') {
        $Date = Get-AuxBakPeriodBegin -Date $Date -Period 'd'
        return $Date.AddDays(-$Date.DayOfWeek.value__ + 1)
    }
    elseif ($Period -like 'm') {
        return [datetime]::new($Date.Year, $Date.Month, 1)
    }
    elseif ($Period -like 'y') {
        return [datetime]::new($Date.Year, 1, 1)
    }
}

function Get-AuxBakNextPeriod([datetime]$Date, $Period, [int]$PeriodCount = 1) {
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

Export-ModuleMember -Function '*-Bak*'
