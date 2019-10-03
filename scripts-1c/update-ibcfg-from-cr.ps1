param(
    $BaseDescr = '',
    $V8,
    $Srvr = '',
    $Ref,
    $Usr,
    $Pwd = '',
    $CRPath,
    $CRUsr,
    $CRPwd = '',
    $AgentSrvr,
    $UseDynamicUpdate = $false,
    $BlockDelayMinutes = 15,
    $BlockPeriodMinutes = 15,
    $TerminateDesigner = $true,
    $DesignerOpenHours = 0,
    $SlackHookUrl = '',
    $SlackHookUrlAlerts = ''
)


Import-Module ($PSScriptRoot + '\modules\1c-module.ps1') -Force

# Use Slack
$UseSlackInfo = (-not [String]::IsNullOrWhiteSpace($SlackHookUrl))
$UseSlackAlets = (-not [String]::IsNullOrWhiteSpace($SlackHookUrlAlerts))
if ($UseSlackInfo -or $UseSlackAlets) {
    Import-Module ($PSScriptRoot + '\modules\slack-module.ps1') -Force
}

if ($UseSlackInfo) {
    $UpdateStage = 'Запуск обновления конфигурации информационной базы: ' + $BaseDescr;
    Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
}

# Log
$Log = Get-1CLog -Dir ($PSScriptRoot + '\logs') -Name $PSCmdFile.BaseName

$UpdateBeginDate = Get-Date

# 1C-agent adress
if ([string]::IsNullOrEmpty($AgentSrvr)) {
    $AgentSrvr = $Srvr
}

# Default values
$Conn = Get-1CConn -V8 $V8 -Srvr $Srvr  -Ref $Ref -Usr $Usr -Pwd $Pwd -CRPath $CRPath -CRUsr $CRUsr -CRPwd $CRPwd -AgSrvr $AgentSrvr

$ScriptMsg = 'Обновление конфигурации ИБ - ' + $BaseDescr

# Terminate Designers
$IsTerminatedSessions = $false
if ($TerminateDesigner) {
    $DesignerStartedBefore = (Get-date).AddHours(-$DisgnerOpenHours);
    $Result = Terminate-1CInfoBaseSessions -Conn $Conn -TermMsg $ScriptMsg -AppID 'Designer' -StartedBefore $DesignerStartedBefore -Log $Log
    if ($Result.TerminatedSessions.Count -gt 0) {
        $IsTerminatedSessions = $true
    }
}
if ($IsTerminatedSessions) {
    Start-Sleep -Seconds 30
}

# Get conf from CR updating DB.
$IsRequiredUpdate = $false
$Result = Invoke-1CCRUpdateCfg -Conn $Conn -Log $Log
if (Test-1CConfigurationChanged -Conn $Conn) {
    if ($UseDynamicUpdate) {
        Invoke-1CUpdateDBCfg -Conn $Conn -Dynamic -Log $Log
        if (Test-1CConfigurationChanged -Conn $Conn) {
            $IsRequiredUpdate = $True
        }
    }
    else {
        $IsRequiredUpdate = $True
    }
}

if (-not $IsRequiredUpdate) {
    if ($UseSlackInfo) {
        $UpdateStage = 'Не требуется обновление конфигурации информационной базы: ' + $BaseDescr
        Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
    }
    break
}

$PermissionCode = 'CfgUpdate-' + (Get-Date).ToString('HHmmss')

# Block IB for updating
$BlockFrom = (Get-Date).AddMinutes($BlockDelayMinutes)
$BlockTo = ($BlockFrom).AddMinutes($BlockPeriodMinutes)
$BlockMsg = $ScriptMsg + ' с ' + $BlockFrom.ToString('HH:mm') + ' в течении ' + $BlockPeriodMinutes + ' минут.'
Add-1CLog -Log $Log -ProcessName '1CInfoBaseSessions' -LogHead 'Block' -LogText $BlockMsg
Set-1CInfoBaseSessionsDenied -Conn $Conn -Denied -From $BlockFrom -To $BlockTo -Msg $BlockMsg -PermissionCode $PermissionCode

if ($UseSlackInfo) {
    $UpdateStage = 'Выполнена блокировка информационной базы: ' + $BaseDescr + '. ' + $BlockMsg
    Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
}

# Delay
Add-1CLog -Log $Log -ProcessName 'UpdateTestBasesCfg' -LogHead 'Delay' -LogText ('Minutes ' + $BlockDelayMinutes)
Start-Sleep -Seconds ($BlockDelayMinutes * 60)

# Terminate sessions and update IB
$Conn.UC = $PermissionCode
Terminate-1CInfoBaseSessions -Conn $Conn -TermMsg $ScriptMsg -Log $Log
Invoke-1CUpdateDBCfg -Conn $Conn -Log $Log
Set-1CInfoBaseSessionsDenied -Conn $Conn

if ($UseSlackInfo) {
    $UpdateStage = 'Завершено обновление конфигурации информационной базы: ' + $BaseDescr;
    Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
}
