Import-Module perfmon-module -Force
Import-Module slack-module

$HookUrl = 'https://hooks.slack.com/services/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'

$TaskPeriodMin = 5
$TestPeriodSec = 15

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
    $MonitorFiles = Get-ChildItem -Path C:\PerfLogs\Admin\HourAvgMonitor -File -Recurse -Filter '*.csv' | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 2

    $CountersBegin = $CurStart - (New-TimeSpan -Seconds (2 * $TestPeriodSec))
    $MonitorValues = Get-PmCountersFromCsv -Files $MonitorFiles -Begin $CountersBegin

    # processor
    $Result = Test-PmCounter -Counters $MonitorValues.Counters -CounterType PctProcessorTime -Script {$_.Avg -gt 60}
    if (-not $Result.OK) {
        Send-SlackWebHook -HookUrl $HookUrl -Text $Result.Msg 
    }

    # processor queue
    $Result = Test-PmCounter -Counters $MonitorValues.Counters -CounterType ProcessorQueueLength -Script {$_.Avg -gt 0.8}
    if (-not $Result.OK) {
        Send-SlackWebHook -HookUrl $HookUrl -Text $Result.Msg 
    }

    # disk queue
    $Result = Test-PmCounter -Counters $MonitorValues.Counters -CounterType AvgDiskQueueLength -Script {$_.Avg -gt 0.8}
    if (-not $Result.OK) {
        Send-SlackWebHook -HookUrl $HookUrl -Text $Result.Msg 
    }
}
