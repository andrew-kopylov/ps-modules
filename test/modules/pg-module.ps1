# PostgreSQL: version 1.0

function Get-PgConnParams($DbName = $null, $Usr = $null, $Srvr = $null, $Port = $null) {
    @{DbName = $DbName; Usr = $Usr; Srvr = $Srvr; Port = $Port}
}

function Add-PgArg($Args, $Name, $Value, $DefValue) {
    if ($Value -ne $null) {
        $Args = $Args + ' --' + $Name + '=' + $Value
    }
    elseif ($DefValue -ne $null) {
        $Args = $Args + ' --' + $Name + '=' + $DefValue
    }
    $Args
} 

function Get-PgBackupExtention() {
    'backup'
}

function Repeat-PgString($Str, $Count) {
    $ResStr = ''
    for ($i = 1; $i -le $Count; $i++) {
        $ResStr = $ResStr + $Str;
    }
    $ResStr
}

function Get-PgDaysInPeriod($Period) {
    if     ($Period -eq 'd') {$Result = 1}
    elseif ($Period -eq 'w') {$Result = 7}
    elseif ($Period -eq 'm') {$Result = 31}
    elseif ($Period -eq 'y') {$Result = 366}
    else {$Result = 0}
    $Result
}

function Parce-PgBackupDate($BackupName) {

    $Result = @{OK = 0; Period = ""; StorePeriods = 0; StoreDays = 0; BackupDate = $null; DbName = ""}

    $MatchBacupName = '(.+)_(\d{8})_(\d{6})_([dwmy])(\d+)\.' + (Get-PgBackupExtention) + '$'

    if ($BackupName -match $MatchBacupName) {
        
        $Result.OK = 1
        $Result.DbName = $Matches.1  
        $Result.Period = $Matches.4
        $Result.StorePeriods = [int]$Matches.5
        $Result.StoreDays = $Result.StorePeriods * (Get-PgDaysInPeriod -Period $Result.Period)
         
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

function Find-PgBackup($DbName, $BackupDir, $Period, [int]$StorePeriods, $BackupDate = $null) {

    $WcNum6 = Repeat-PgString -Str '[0-9]' -Count 6

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
        $WcBackup = $DbName + '_' + $WcDay + '_' + $WcNum6 + '_' + $Period + $StorePeriods.ToString() + '.' + (Get-PgBackupExtention)
        $Result = Get-ChildItem -Path ($BackupDir + '\*') -Include $WcBackup -File
        if ($Result.Count -gt 0) {break}
    }

    $Result
}

function Invoke-PgBackup($ConnParams, $BackupDir, $Period = "", [int]$StorePeriods = 0) {

    # Period: d - day (default), w - week, m - month, y - year
    
    $DbName = $ConnParams.DbName;
    $BackupDate = (Get-Date).ToString('yyyyMMdd_HHmmss')

    $BackupName = $DbName + '_' + $BackupDate;

    if ($StorePeriods -gt 0) {
        if ($Period -eq '') {$Period = 'd'} # day by default
        $FindedBackups = Find-PgBackup -DbName $DbName -BackupDir $BackupDir -Period $Period -StorePeriods $StorePeriods
        if ($FindedBackups.Count -gt 0) {
            Return ''
        };
        $BackupName = $BackupName + '_' + $Period + $StorePeriods.ToString()
    }

    $BackupFile = $BackupDir + '\' + $BackupName + '.' + (Get-PgBackupExtention)

    $PgArgs = '';
    $PgArgs = Add-PgArg -Args $PgArgs -Name 'host' -Value $ConnParams.Srvr
    $PgArgs = Add-PgArg -Args $PgArgs -Name 'port' -Value $ConnParams.Port

    # Addition parameters.
    $PgArgs = $PgArgs + ' --no-password --format=custom --encoding=UTF8'
    
    # Database and Backup file.
    $PgArgs = Add-PgArg -Args $PgArgs -Name 'file' -Value $BackupFile
    $PgArgs = $PgArgs + ' ' + $DbName

    $PgArgs = $PgArgs.Trim()
    $PgArgs
    Start-Process -FilePath "pg_dump" -ArgumentList $PgArgs -NoNewWindow -Wait

    Return $BackupFile
}

function Remove-PgBackups($BackupDir) {

    $RemovedBackups = @();

    $WcNum6 = Repeat-PgString -Str '[0-9]' -Count 6
    $WcNum8 = Repeat-PgString -Str '[0-9]' -Count 8
    $WcBackup = '*_' + $WcNum8 + '_' + $WcNum6 + '_[dwmy][0-9]*.' + (Get-PgBackupExtention)

    $ItemList = Get-ChildItem -Path ($BackupDir + '\*') -Include $WcBackup -File
    foreach ($Item in $ItemList) {
    
        $Backup = Parce-PgBackupDate -BackupName ($Item.Name)
        if ($Backup.OK -ne 1) {continue}

        $TimeSpan = New-TimeSpan -Start $Backup.BackupDate -End (Get-Date)
        if ($TimeSpan.TotalDays -gt $Backup.StoreDays) {
            $RemovedBackups += $Item.FullName 
            Remove-Item -Path $Item.FullName
        }
    }

}

function Invoke-PgSql($ConnParams, $Sql) {

    $PgArgs = "";

    $PgArgs = Add-PgArg -Args $PgArgs -Name 'dbname' -Value $ConnParams.DbName -DefValue 'postgres'
    $PgArgs = Add-PgArg -Args $PgArgs -Name 'username' -Value $ConnParams.Usr
    $PgArgs = Add-PgArg -Args $PgArgs -Name 'host' -Value $ConnParams.Srvr
    $PgArgs = Add-PgArg -Args $PgArgs -Name 'port' -Value $ConnParams.Port

    # Addition parameters.
    $PgArgs = $PgArgs + ' --no-password'
    
    $PgArgs = $PgArgs.Trim()
    $Return = Start-Process -FilePath "psql" -ArgumentList $PgArgs -NoNewWindow -Wait

    $Return
}

function Get-PgDatabases($ConnParams) {




}

function Invoke-PgReindex($DbName, $TabName) {

}