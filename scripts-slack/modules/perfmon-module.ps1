
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
        if (-not [String]::IsNullOrWhiteSpace($CounterPath) {
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

function Get-PmParametersString($Parameters, $RoundValueSign = '') {
    $ParamStr = ''
    # Is HashTable or OrderedDictionary
    if ($Parameters -is [hashtable] -or ($Parameters -is [System.Object] -and $Parameters.GetType().name -eq 'OrderedDictionary')) {
        foreach ($ParamKey in $Parameters.Keys) {
            $ParamVal = $Parameters[$ParamKey]
            if ($ParamVal -eq $null -or ($ParamVal -is [boolean] -and $ParamVal -eq $true)) {
                $ParamStr = $ParamStr + ' -' + $ParamKey
            }
            elseif ($ParamVal -is [boolean] -and $ParamVal -eq $false) {
                $ParamStr = $ParamStr + ' --' + $ParamKey # switch-off parameter
            }
            else {
                $ParamStr = $ParamStr + ' -' + $ParamKey + ' ' + $RoundValueSign + $ParamVal + $RoundValueSign
            }  
        }
    }
    else {
        $ParamStr = ' ' + [string]$Parameters
    }
    $ParamStr
}
