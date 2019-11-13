Import-Module perfmon-module
Import-Module slack-module

$Config = Get-Content -Path ($PSScriptRoot + '\config\config.json') | ConvertFrom-Json
$HookUrl = $Config.MonitoringHookUrl
$HostDescr = $Config.hostDescr

$TaskPeriodMin = 5   # Windows task start period
$TestPeriodSec = 60  # Start test (alert) period
$StatPeriodMin = 5   # Statistic period for calc Avg, Min, Max

$StartDate = Get-Date
$EndDate = $StartDate + (New-TimeSpan -Minutes $TaskPeriodMin)

$NextStart = $StartDate

while (((Get-Date) -lt $EndDate)) {

    if ((Get-Date) -lt $NextStart) {
        Start-Sleep -Seconds 5
        continue
    }

    $CurStart = Get-Date
    $NextStart = $CurStart + (New-TimeSpan -Seconds $TestPeriodSec)

    $CountersHashtable = Get-PmCountersHashtable
    $MonitorFiles = Get-ChildItem -Path C:\PerfLogs\Admin\PmAlerts -File -Recurse -Filter '*.csv' | Sort-Object -Property LastWriteTime -Descending | Select-Object -First ($StatPeriodMin + 1)

    $CountersBegin = $CurStart - (New-TimeSpan -Minutes $StatPeriodMin)
    $MonitorValues = Get-PmCountersFromCsv -Files $MonitorFiles -Begin $CountersBegin
    $Counters = $MonitorValues.Counters

    # processor
    $Result = Test-PmCounter -Counters $Counters -CounterType PctProcessorTime -Script {$_.Avg -gt 70}
    if (-not $Result.OK) {
        Send-SlackWebHook -HookUrl $HookUrl -Text ($HostDescr + "`n" + $Result.Msg)
    }

    # processor queue
    $Result = Test-PmCounter -Counters $Counters -CounterType ProcessorQueueLength -Script {$_.Avg -gt 2}
    if (-not $Result.OK) {
        Send-SlackWebHook -HookUrl $HookUrl -Text ($HostDescr + "`n" + $Result.Msg)
    }

    # disk queue
    $Result = Test-PmCounter -Counters $Counters -CounterType AvgDiskQueueLength -Script {$_.Avg -gt 2}
    if (-not $Result.OK) {
        Send-SlackWebHook -HookUrl $HookUrl -Text ($HostDescr + "`n" + $Result.Msg)
    }

    # disk read byte/s
    $Result = Test-PmCounter -Counters $Counters -CounterType DiskReadBytesPerSec -Script {$_.Avg -gt 200MB}
    if (-not $Result.OK) {
        Send-SlackWebHook -HookUrl $HookUrl -Text ($HostDescr + "`n" + $Result.Msg)
    }

    # disk write byte/s
    $Result = Test-PmCounter -Counters $Counters -CounterType DiskWriteBytesPerSec -Script {$_.Avg -gt 200MB}
    if (-not $Result.OK) {
        Send-SlackWebHook -HookUrl $HookUrl -Text ($HostDescr + "`n" + $Result.Msg)
    }

    # network receive byte/s
    $Result = Test-PmCounter -Counters $Counters -CounterType BytesReceivedPerSec -Script {$_.Avg -gt 20MB}
    if (-not $Result.OK) {
        Send-SlackWebHook -HookUrl $HookUrl -Text ($HostDescr + "`n" + $Result.Msg)
    }

    # network sent byte/s
    $Result = Test-PmCounter -Counters $Counters -CounterType BytesReceivedPerSec -Script {$_.Avg -gt 20MB}
    if (-not $Result.OK) {
        Send-SlackWebHook -HookUrl $HookUrl -Text ($HostDescr + "`n" + $Result.Msg)
    }

}
