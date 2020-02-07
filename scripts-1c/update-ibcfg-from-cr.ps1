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
    $SlackHookUrlAlerts = '',
    $AttemptsOnFailureCount = 3
)

Import-Module 1c-module -Force

$PSCmdFile = Get-Item -Path $PSCommandPath

# Use Slack
$UseSlackInfo = (-not [String]::IsNullOrWhiteSpace($SlackHookUrl))
$UseSlackAlets = (-not [String]::IsNullOrWhiteSpace($SlackHookUrlAlerts))
if ($UseSlackInfo -or $UseSlackAlets) {
    Import-Module slack-module -Force
}

if ($UseSlackInfo) {
    $UpdateStage = $BaseDescr + ' Запуск обновления конфигурации информационной базы'
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
$Conn = Get-1CConn -V8 $V8 -Srvr $Srvr  -Ref $Ref -Usr $Usr -Pwd $Pwd -CRPath $CRPath -CRUsr $CRUsr -CRPwd $CRPwd

$ScriptMsg = $BaseDescr + ' Обновление конфигурации ИБ'

# Terminate Designers
$IsTerminatedSessions = $false
if ($TerminateDesigner) {
    $DesignerStartedBefore = (Get-date).AddHours(-$DisgnerOpenHours);

    try {
        $Result = Remove-1CIBSessions -Conn $Conn -TermMsg $ScriptMsg -AppID 'Designer' -StartedBefore $DesignerStartedBefore -Log $Log
        if ($Result.TerminatedSessions.Count -gt 0) {
            $IsTerminatedSessions = $true
        }
    }
    catch {
        $ErrorInfo = $BaseDescr + ' ОШИБКА обновления базы: ' + $_
        Send-SlackWebHook -HookUrl $SlackHookUrl -Text $ErrorInfo | Out-Null
        break
    }

}
if ($IsTerminatedSessions) {
    Start-Sleep -Seconds 30
}

try {

    # Get conf from CR updating DB.
    $IsRequiredUpdate = $false
    $Result = Invoke-1CCRUpdateCfg -Conn $Conn -Log $Log
    if (Test-1CCfChanged -Conn $Conn) {
        if ($UseDynamicUpdate) {
            Invoke-1CUpdateDBCfg -Conn $Conn -Dynamic -Log $Log
            if (Test-1CCfChanged -Conn $Conn) {
                $IsRequiredUpdate = $True
            }
        }
        else {
            $IsRequiredUpdate = $True
        }
    }

}
catch {
    $ErrorInfo = $BaseDescr + ' ОШИБКА обновления базы: ' + $_ + '; ' + $Result.out
    Send-SlackWebHook -HookUrl $SlackHookUrl -Text $ErrorInfo | Out-Null
    break
}

if (-not $IsRequiredUpdate) {
    if ($UseSlackInfo) {
        $UpdateStage = $BaseDescr + ' Не требуется обновление конфигурации информационной базы'
        Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
    }
    break
}

$PermissionCode = 'CfgUpdate-' + (Get-Date).ToString('HHmmss')

# Block IB for updating
$BlockFrom = (Get-Date).AddMinutes($BlockDelayMinutes)
$BlockTo = ($BlockFrom).AddMinutes($BlockPeriodMinutes)
#$UpdatePeriodInfo = ' в ' + $BlockFrom.ToString('HH:mm') + ' в течении ' + $BlockPeriodMinutes + ' минут.'
$UpdatePeriodInfo = ' в ' + $BlockFrom.ToString('HH:mm') + ' в течении 1-3 минут.'
$BlockMsg = 'Обновление базы ' + $UpdatePeriodInfo
Add-1CLog -Log $Log -ProcessName '1CInfoBaseSessions' -LogHead 'Block' -LogText $BlockMsg
Set-1CIBSessionsDenied -Conn $Conn -Denied -From $BlockFrom -To $BlockTo -Msg $BlockMsg -PermissionCode $PermissionCode | Out-Null

if ($UseSlackInfo) {
    $UpdateStage = $BaseDescr + ' Установлена блокировка базы ' + $UpdatePeriodInfo
    Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
}

# Delay
Add-1CLog -Log $Log -ProcessName 'UpdateTestBasesCfg' -LogHead 'Delay' -LogText ('Minutes ' + $BlockDelayMinutes)

Start-Sleep -Seconds ($BlockDelayMinutes * 60)

if ($UseSlackInfo) {
    $UpdateStage = $BaseDescr + ' Запуск обновления конфигурации базы данных...'
    Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
}

# Terminate sessions and update IB
$Conn.UC = $PermissionCode
Remove-1CIBSessions -Conn $Conn -TermMsg $ScriptMsg -Log $Log
Remove-1CIBConnections -Conn $Conn -Log $Log

$Result = Invoke-1CUpdateDBCfg -Conn $Conn -Log $Log

$IsFailure = -not $Result.OK -or (Test-1CCFChanged -Conn $Conn);

$AttemtsCounter = 1

$WaitSecOnFailure = 0
if ($AttemptsOnFailureCount -gt 0) {
    $WaitSecOnFailure = [int]($BlockPeriodMinutes * 60 / $AttemptsOnFailureCount)
}

While ($IsFailure) {

    if ($UseSlackInfo) {
        $UpdateStage = $BaseDescr + ' ОШИБКА обновления ИБ: ' + $Result.out
        Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
    }
    
    $AttemtsCounter++        
    if ($AttemtsCounter -gt $AttemptsOnFailureCount) {
        break
    }

    Start-Sleep -Seconds $WaitSecOnFailure

    if ($UseSlackInfo) {
        $UpdateStage = $BaseDescr + ' Запуск обновления конфигурации базы данных... Попытка ' + $AttemtsCounter + ' из ' + $AttemptsOnFailureCount 
        Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
    }

    Remove-1CIBSessions -Conn $Conn -TermMsg $ScriptMsg -Log $Log
    Remove-1CIBConnections -Conn $Conn -Log $Log

    $Result = Invoke-1CUpdateDBCfg -Conn $Conn -Log $Log
    $IsFailure = -not $Result.OK -or (Test-1CCfChanged -Conn $Conn);

}

Set-1CIBSessionsDenied -Conn $Conn | Out-Null

if (-not $IsFailure) {
    if ($UseSlackInfo) {
        $UpdateStage = $BaseDescr + ' Обновление успешно завершено';
        Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
    }
} 
else {
    if ($UseSlackInfo) {
        $UpdateStage = $BaseDescr + ' ОШИБКА!!! Обновление НЕ выполнено по причине: ' + $Result.out;
        Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
    }
}
