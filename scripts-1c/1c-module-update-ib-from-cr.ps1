param(
    $BaseDescr = '',
    $Srvr = '',
    $Ref,
    $Usr,
    $Pwd = '',
    $CRPath,
    $CRUsr,
    $CRPwd = '',
    $AgentSrvr,
    $BlockDelayMinutes = 15,
    $BlockPeriodMinutes = 15,
    $TerminateDesigner = $true,
    $DesignerOpenHours = 0,
    $SlackHookUrl = ''
)


Import-Module ($PSScriptRoot + '\1c-module.ps1') -Force
Import-Module ($PSScriptRoot + '\slack-module.ps1') -Force

$UpdateStage = 'Запуск обновления конфигурации информационной базы: ' + $BaseDescr;
Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null

# Log
$Log = Get-1CLog -Dir ($PSCmdFile.DirectoryName + '\logs') -Name $PSCmdFile.BaseName

$UpdateBeginDate = Get-Date

# 1C-agent adress
if ([string]::IsNullOrEmpty($AgentSrvr)) {
    $AgentSrvr = $Srvr
}

# Default values
$Conn = Get-1CConn -Srvr $Srvr  -Ref $Ref -Usr $Usr -Pwd $Pwd -CRPath $CRPath -CRUsr $CRUsr -CRPwd $CRPwd -AgSrvr $AgentSrvr

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

# Get conf from CR and attempt dynamic updating DB.
$IsRequiredUpdate = $false
$Result = Invoke-1CCRUpdateCfg -Conn $Conn -Log $Log
if (($Result.ProcessedObjects.Count -gt 0)) {
    Invoke-1CUpdateDBCfg -Conn $Conn -Dynamic -Log $Log
    if (Test-1CConfigurationChanged -Conn $Conn) {
        $ToBlockConn = $True
    }
}

if (-not $IsRequiredUpdate) {
    break
}

$PermissionCode = 'CfgUpdate-' + (Get-Date).ToString('HHmmss')

# Block IB for updating
$BlockFrom = (Get-Date).AddMinutes($BlockDelayMinutes)
$BlockTo = ($BlockFrom).AddMinutes($BlockPeriodMinutes)
$BlockMsg = $ScriptMsg + ' с ' + $BlockFrom.ToString('HH:mm') + ' в течении ' + $BlockPeriodMinutes + ' минут.'
Add-1CLog -Log $Log -ProcessName '1CInfoBaseSessions' -LogHead 'Block' -LogText $BlockMsg
Set-1CInfoBaseSessionsDenied -Conn $Conn -Denied -From $BlockFrom -To $BlockTo -Msg $BlockMsg -PermissionCode $PermissionCode

# Delay
Add-1CLog -Log $Log -ProcessName 'UpdateTestBasesCfg' -LogHead 'Delay' -LogText ('Minutes ' + $BlockDelayMinutes)
Start-Sleep -Seconds ($BlockDelayMinutes * 60)

# Terminate sessions and update IB
$Conn.UC = $PermissionCode
Terminate-1CInfoBaseSessions -Conn $Conn -TermMsg $ScriptMsg -Log $Log
Invoke-1CUpdateDBCfg -Conn $Conn -Log $Log
Set-1CInfoBaseSessionsDenied -Conn $Conn
