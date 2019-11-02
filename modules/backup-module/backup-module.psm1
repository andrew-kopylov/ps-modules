
function Remove-BakFiles($BackupDir, $BackupExt) {

    $RemovedBackups = @();

    $WcNum6 = Repeat-BakString -Str '[0-9]' -Count 6
    $WcNum8 = Repeat-BakString -Str '[0-9]' -Count 8
    $WcBackup = '*_' + $WcNum8 + '_' + $WcNum6 + '_[dwmy][0-9]*.' + $BackupExt

    $ItemList = Get-ChildItem -Path ($BackupDir + '\*') -Include $WcBackup -File
    foreach ($Item in $ItemList) {
    
        $Backup = Parce-BakDate -BackupName ($Item.Name)
        if ($Backup.OK -ne 1) {continue}

        $TimeSpan = New-TimeSpan -Start $Backup.BackupDate -End (Get-Date)
        if ($TimeSpan.TotalDays -gt $Backup.StoreDays) {
            $RemovedBackups += $Item.FullName 
            Remove-Item -Path $Item.FullName
        }
    }

}

function Parce-BakDate($BackupName, $BackupExt) {

    $Result = @{OK = 0; Period = ""; StorePeriods = 0; StoreDays = 0; BackupDate = $null; BakName = ""}

    $MatchBacupName = '(.+)_(\d{8})_(\d{6})_([dwmy])(\d+)\.' + $BackupExt + '$'

    if ($BackupName -match $MatchBacupName) {
        
        $Result.OK = 1
        $Result.BakName = $Matches.1  
        $Result.Period = $Matches.4
        $Result.StorePeriods = [int]$Matches.5
        $Result.StoreDays = $Result.StorePeriods * (Get-BakDaysInPeriod -Period $Result.Period)
         
        # Date
        $Date = $Matches.2
        $Year = [int]$Date.Substring(0, 4)
        $Month = [int]$Date.Substring(4, 2)
        $Day = [int]$Date.Substring(6, 2)
       
        # Time
        $Time = $Matches.3
        $Hour = [int]$Time.Substring(0, 2)
        $Minute = [int]$Time.Substring(2, 2)
        $Second = [int]$Time.Substring(4, 2)

        $Result.BackupDate = (Get-Date -Year $Year -Month $Month -Day $Day -Hour $Hour -Minute $Minute -Second $Second)

    }

    $Result
}

function Find-BakFile($BakName, $BackupDir, $BackupExt, $Period, [int]$StorePeriods, $BackupDate = $null) {

    $WcNum6 = Repeat-BakString -Str '[0-9]' -Count 6

    if ($BackupDate -eq $null) {$BackupDate = Get-Date}
   
    $ArrWcDay = @();
    
    # Define wildcards of the days.
    if ($Period -eq 'd') {
        $ArrWcDay += $BackupDate.ToString('yyyyMMdd')
    }
    elseif ($Period -eq 'w') {
        $StartOfWeek = $BackupDate.AddDays(-$BackupDate.DayOfWeek + 1)
        for ($i = 1; $i -le 7; $i++) {
            $ArrWcDay += ($StartOfWeek.AddDays($i - 1)).ToString('yyyyMMdd')
        }
    }
    elseif ($Period -eq 'm') {
        $ArrWcDay += $BackupDate.ToString('yyyyMM') + '[0-9][0-9]'
    }
    elseif ($Period -eq 'y') {
        $ArrWcDay += $BackupDate.ToString('yyyy') + '[0-9][0-9][0-9][0-9]'
    }
    else {}
  
    $Result = @();  
    foreach ($WcDay in $ArrWcDay) {
        $WcBackup = $BakName + '_' + $WcDay + '_' + $WcNum6 + '_' + $Period + $StorePeriods.ToString() + '.' + $BackupExt
        $Result = Get-ChildItem -Path ($BackupDir + '\*') -Include $WcBackup -File
        if ($Result.Count -gt 0) {break}
    }

    $Result
}

function Repeat-BakString($Str, $Count) {
    $ResStr = ''
    for ($i = 1; $i -le $Count; $i++) {
        $ResStr = $ResStr + $Str;
    }
    $ResStr
}

function Get-BakDaysInPeriod($Period) {
    if     ($Period -eq 'd') {$Result = 1}
    elseif ($Period -eq 'w') {$Result = 7}
    elseif ($Period -eq 'm') {$Result = 31}
    elseif ($Period -eq 'y') {$Result = 366}
    else {$Result = 0}
    $Result
}
