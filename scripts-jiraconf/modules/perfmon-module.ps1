
function Create-PmCounter{
    param (
        $Name,
        $Counters,
        [ValidateSet('bin', 'bincirc', 'csv', 'tsv', 'sql')]
        $Format,
        $SelectionInterval,
        $SelectionCount
    )

    $CountersString = ''
    foreach ($CounterPath in $Counters) {
        if (-not [String]::IsNullOrWhiteSpace($CounterPath)) {
            $CountersString = $CountersString + ' "' + $CounterPath + '"'
        }
    }

    if ($SelectionInterval -is [TimeSpan]) {
        $SelectionInterval = ([TimeSpan]$SelectionInterval).ToString('c')
    }

    $Parameters = @{
        name = '"' + $Name + '"';
        c = $CountersString;
        f = $Format;
        si = $SelectionInterval;
        y = $true;
    }

    if ($SelectionCount -ne $null) {
        $Parameters.sc = $SelectionCount
    }

    Invoke-PmLogmanCommand -Verb create -Adverb counter -Parameters $Parameters

}

function Export-PmGroup ($Name, $XMLFile) {

    $Parameters = @{
        name = $Name;
        xml = $XMLFile;
    }

    $Parameters = Get-PmParametersString -Parameters $Parameters -RoundValueSign '"'

    Invoke-PmLogmanCommand -Verb export -Parameters $Parameters

}

function Invoke-PmRelogCommand {
    param (
        $InputFiles,
        [switch]$AddToExistFile,
        $InputCounters,
        $InputCountersFile,
        [ValidateSet('CSV', 'TSV', 'BIN', 'SQL')]
        $OutFormat,
        $RecordsInterval,
        $OutPath,
        $Begin,
        $End,
        $ConfigFile,
        [switch]$CountersListInInput
    )

    # https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/relog

    # RecordsInterval - Specifies sample intervals in "N" records.
    # Includes every nth data point in the relog file. Default is every data point

    $ArgsStr = Get-PmParameterValueString -ParamVal $InputFiles -RoundValueSign '"'

    $Begin = Get-PmParameterValueString -ParamVal $Begin -NullIfNull
    $End = Get-PmParameterValueString -ParamVal $End -NullIfNull

    $TArgs = [ordered]@{
        a = $AddToExistFile;
        c = $InputCounters;
        cf = $InputCountersFile;
        f = $OutFormat;
        t = $RecordsInterval;
        o = $OutPath;
        b = $Begin;
        e = $End;
        config = $ConfigFile;
        q = $CountersListInInput;
        y = $true
    }

    $ArgsStr = $ArgsStr + ' ' + (Get-PmRelogParameters -Parameters $TArgs)
    Start-Process -FilePath 'relog' -ArgumentList $ArgsStr -Wait -WindowStyle Hidden -Verbose
}

function Invoke-PmLogmanCommand {
    param (
        [ValidateSet('create', 'query', 'start', 'stop', 'delete', 'update', 'import', 'export')]
        $Verb,
        [ValidateSet('counter', 'trace', 'alert', 'cfg', 'providers')]
        $Adverb,
        $Parameters        
    )
    $ArgsStr = $Verb + (Get-PmParametersString -Parameters $Adverb) + (Get-PmParametersString -Parameters $Parameters)
    $Ret = Start-Process -FilePath 'logman' -ArgumentList $ArgsStr -Wait -NoNewWindow -Verbose
}

function Create-PmMonitorAlertTask {
    param (
        [String]$SendMsgScript = 'c:\scripts\send-slackmsg'
    )

    $ActionAgrs = '-f "' + $SendMsgScript + '" $(Arg0)'
    $Action = New-ScheduledTaskAction -Execute 'PowerShell' -Argument $ActionAgrs

 
    $Settings = New-ScheduledTaskSettingsSet
    $Principal = New-ScheduledTaskPrincipal -UserId 'LOCALSERVICE'

    $Task = New-ScheduledTask -Action $Action -Description 'Sends alert message by send-message-script.' -Principal $Principal -Settings $Settings
  
    Register-ScheduledTask 'MonitorAlert' -InputObject $Task -TaskPath '\PmAlerts'
}

function Create-PmIamAliveAlertTask {
    param (
        [String]$SendMsgScript = 'c:\scripts\send-slackmsg',
        [DateTime]$At = [DateTime]::new(2000, 1, 1, 8, 0, 0)
    )

    $ActionAgrs = '-f "' + $SendMsgScript + '" "I''am alive!"'
    $Action = New-ScheduledTaskAction -Execute 'PowerShell' -Argument $ActionAgrs

    $Trigger = New-ScheduledTaskTrigger -At $At -Daily
 
    $Settings = New-ScheduledTaskSettingsSet
    $Principal = New-ScheduledTaskPrincipal -UserId 'LOCALSERVICE'

    $Task = New-ScheduledTask -Action $Action -Description 'Sends alert message by send-message-script.' -Principal $Principal -Settings $Settings -Trigger $Trigger
  
    Register-ScheduledTask 'IamAliveAlert' -InputObject $Task -TaskPath 'PmAlerts'
}

function Get-PmLogmanParameters($Parameters, $RoundValueSign = '') {
    Get-PmParametersString -Parameters $Parameters -RoundValueSign $RoundValueSign -UseSwitchOffParameters $true
}

function Get-PmRelogParameters($Parameters, $RoundValueSign = '') {
    Get-PmParametersString -Parameters $Parameters -RoundValueSign $RoundValueSign -UseSwitchOffParameters $false
}

function Get-PmParametersString($Parameters, $RoundValueSign = '', $UseSwitchOffParameters = $true) {
    $ParamStr = ''
    # Is HashTable or OrderedDictionary
    if ($Parameters -is [hashtable] -or ($Parameters -is [System.Object] -and $Parameters.GetType().name -eq 'OrderedDictionary')) {
        foreach ($ParamKey in $Parameters.Keys) {
            $ParamVal = $Parameters[$ParamKey]
            if ($ParamVal -eq $null ) {}
            elseif ($ParamVal -is [boolean] -or $ParamVal -is [switch]) { 
                if ($ParamVal) {$ParamStr = $ParamStr + ' -' + $ParamKey}
            }
            elseif ($ParamVal -is [boolean] -and $ParamVal -eq $false) {
                $ParamStr = $ParamStr + ' --' + $ParamKey # switch-off parameter
            }
            else {
                $ParamStr = $ParamStr + ' -' + $ParamKey + ' ' + (Get-PmParameterValueString -ParamVal $ParamVal -RoundValueSign $RoundValueSign)
            }  
        }
    }
    else {
        $ParamStr = ' ' + [string]$Parameters
    }
    $ParamStr
}

function Get-PmParameterValueString($ParamVal, $RoundValueSign = '', [switch]$NullIfNull) {
    $ParamValString = ''
    if ($ParamVal -eq $null) {
        if ($NullIfNull) {
            $ParamValString = $null
        }
    }
    elseif ($ParamVal -is [System.Array]) {
        foreach ($ArrItem in $ParamVal) {
            $ParamValString = $ParamValString + ' ' + $RoundValueSign + $ArrItem + $RoundValueSign
        }
    }
    elseif ($ParamVal -is [datetime]) {
        $ParamValString = $ParamVal.ToString()
    }
    else {
        $ParamValString = $RoundValueSign + $ParamVal + $RoundValueSign
    }  
    $ParamValString
}
