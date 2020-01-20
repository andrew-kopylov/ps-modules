
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

function Remove-BakFiles($BakPolicy, $Path, [switch]$Recurse) {

    if (-not [string]::IsNullOrEmpty($Path)) {
        $BakPath = $Path
    }
    else {
        $BakPath = $BakPolicy.Path
    }

    $RemovedFiles = @()
    $FilesWithDate = Get-BakFilesWithDate -BakPath $BakPath -DatePattern $BakPolicy.DatePattern -Prefix $BakPolicy.Prefix -Postfix $BakPolicy.Postfix -Recurse:$Recurse
    $FilesToRemove = Get-BakFilesToRemove -BakFilesWithDate $FilesWithDate -BakPolicy $BakPolicy
    foreach ($Item in $FilesToRemove) {
        $RemovedFiles += $Item.FullName
        Remove-Item -Path $Item.Fullname -Force
    }
    $RemovedFiles
}

function Get-BakFilesWithDate($BakPath, $DatePattern, $Prefix, $Postfix, [switch]$Recurse) {

    # yyyyMMdd-HHddss -> (?<y>\d{4})(?<mon>\d{2})(?<d>\d{2})-(?<h>\d{2})(?<min>\d{2})(?<s>\d{2})
    $DatePattern = $DatePattern.Replace('yyyy', '(?<y>\d{4})')
    $DatePattern = $DatePattern.Replace('yy', '(?<y>\d{2})')
    $DatePattern = $DatePattern.Replace('MM', '(?<mon>\d{2})')
    $DatePattern = $DatePattern.Replace('dd', '(?<d>\d{2})')
    $DatePattern = $DatePattern.Replace('HH', '(?<h>\d{2})')
    $DatePattern = $DatePattern.Replace('mm', '(?<min>\d{2})')
    $DatePattern = $DatePattern.Replace('ss', '(?<s>\d{2})')
    $DatePattern = '(\D|^)' + $DatePattern + '(\D|$)'

    $BakFiles = Get-ChildItem -Path $BakPath -File -Filter ($Prefix + '*' + $Postfix) -Recurse:$Recurse

    $FilesWithDate = @()

    foreach ($BakItem in $BakFiles) {

        $BaseName = $BakItem.BaseName
        if ($BaseName -match $DatePattern) {
            $Year = $Matches.y
            if (($Year -gt 0) -and ($Year -lt 100)) {
                $Year = 2000 + $Year
            }  
            $BakDate = [datetime]::new($Year, $Matches.mon, $Matches.d, $Matches.h, $Matches.min, $Matches.s)
            $FileWithDate = @{
                Item = $BakItem;
                Date = $BakDate;
            }
            $FilesWithDate += New-Object PSCustomObject -Property $FileWithDate
        }
    }

    $FilesWithDate
}

function Get-BakFilesToRemove($BakFilesWithDate, $BakPolicy) {

    $FilesToKeep = @()
    $FilesToKeep += Get-BakFilesToKeep -BakFilesWithDate $BakFilesWithDate -Period 'y' -PeriodCount $BakPolicy.Annual
    $FilesToKeep += Get-BakFilesToKeep -BakFilesWithDate $BakFilesWithDate -Period 'm' -PeriodCount $BakPolicy.Monthly
    $FilesToKeep += Get-BakFilesToKeep -BakFilesWithDate $BakFilesWithDate -Period 'w' -PeriodCount $BakPolicy.Weekly
    $FilesToKeep += Get-BakFilesToKeep -BakFilesWithDate $BakFilesWithDate -Period 'd' -PeriodCount $BakPolicy.Daily

    $BakFilesToRemove = @()
    foreach ($BakFileWithDate in $BakFilesWithDate) {
        if ($BakFileWithDate.Item -notin $FilesToKeep) {
            $BakFilesToRemove += $BakFileWithDate.Item
        }
    }

    $BakFilesToRemove
}

function Get-BakFilesToKeep($BakFilesWithDate, $Period, $PeriodCount) {
    
    $NextPeriodBegin = Get-BakPeriodBegin -Date (Get-Date) -Period $Period
    $NextPeriodEnd = Get-BakNextPeriod -Date $NextPeriodBegin -Period $Period

    $BakFilesToKeep = @()
    for ($i = 0; $i -le $PeriodCount; $i++) {
        $PeriodBegin = $NextPeriodBegin 
        $PeriodEnd = $NextPeriodEnd
        $FindedItems = $BakFilesWithDate.Where({($_.Date -ge $PeriodBegin) -and ($_.Date -lt $PeriodEnd)}) | Sort-Object -Property Date | Select-Object -Property Item -First 1
        if ($FindedItems.Item -ne $null) {
            $BakFilesToKeep += $FindedItems.Item
        }
        # Next period is erler
        $NextPeriodBegin = Get-BakNextPeriod -Date $PeriodBegin -Period $Period -PeriodCount -1 
        $NextPeriodEnd = $PeriodBegin
    }
    $BakFilesToKeep
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
