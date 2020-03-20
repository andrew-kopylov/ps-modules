param(
    $BaseDescr = '',
    $V8,
    $Srvr = '',
    $Ref,
    $Usr,
    $Pwd = '',
    $CRPath,
    $CRPathExt,
    $CRUsr,
    $CRPwd = '',
    $Extension,
    $AgentSrvr,
    $UseDynamicUpdate = $false,
    $BlockDelayMinutes = 15,
    $BlockPeriodMinutes = 15,
    $TerminateDesigner = $true,
    $DesignerOpenHours = 0,
    $SlackHookUrl = '',
    $SlackHookUrlAlerts = '',
    $AttemptsOnFailureCount = 3,
    $ExternalProcessor = '',
    $ExecuteTimeout = 0,
    $AgClUsr,
    $AgClPwd
)

Import-Module 1c-module -Force

$PSCmdFile = Get-Item -Path $PSCommandPath

# Use Slack
$UseSlackInfo = (-not [String]::IsNullOrWhiteSpace($SlackHookUrl)) -or (-not [String]::IsNullOrWhiteSpace($SlackHookUrlAlerts))
if ($UseSlackInfo) {
    Import-Module slack-module -Force
}

if ($UseSlackInfo -and [String]::IsNullOrWhiteSpace($SlackHookUrlAlerts)) {
    $SlackHookUrlAlerts = $SlackHookUrl
}

if ($UseSlackInfo) {
    $UpdateStage = $BaseDescr + ' Запуск обновления конфигурации информационной базы'
    Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
}

# Log
$Log = Get-1CLog -Dir ($PSScriptRoot + '\logs') -Name $PSCmdFile.BaseName

$UpdateBeginDate = Get-Date

# Connextions parameters
$Conn = Get-1CConn -V8 $V8 -Srvr $Srvr  -Ref $Ref -Usr $Usr -Pwd $Pwd -CRPath $CRPath -CRUsr $CRUsr -CRPwd $CRPwd -AgSrvr $AgentSrvr -AgUsr $AgClUsr -AgPwd $AgClPwd -ClUsr $AgClUsr -ClPwd $AgClPwd
$ConnExt = Get-1CConn -V8 $V8 -Srvr $Srvr  -Ref $Ref -Usr $Usr -Pwd $Pwd -CRPath $CRPathExt -CRUsr $CRUsr -CRPwd $CRPwd -AgSrvr $AgentSrvr -Extension $Extension -AgUsr $AgClUsr -AgPwd $AgClPwd -ClUsr $AgClUsr -ClPwd $AgClPwd


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
        Send-SlackWebHook -HookUrl $SlackHookUrlAlerts -Text $ErrorInfo | Out-Null
        break
    }
}
if ($IsTerminatedSessions) {
    Start-Sleep -Seconds 30
}

try {
    
    # Get conf from CR updating DB.
    $IsRequiredUpdate = $false
    
    # Update from config CR
    if ($UseSlackInfo) {
        $UpdateStage = $BaseDescr + ' Получение изменений основной конфигурации из хранилища'
        Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
    }
    $Result = Invoke-1CCRUpdateCfg -Conn $Conn -Log $Log
    if ($Result.OK) {
        if ($Result.ProcessedObjects) {
            if ($UseSlackInfo) {
                $UpdateStage = $BaseDescr + ' Изменено объектов: ' + $Result.ProcessedObjects.Count
                Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
            }
            $IsRequiredUpdate = $True
        }
    }
    else {
        $ErrorInfo = $BaseDescr + ' ОШИБКА обновления базы: ' + $_ + '; ' + $Result.out
        Send-SlackWebHook -HookUrl $SlackHookUrlAlerts -Text $ErrorInfo | Out-Null
        return
    }

    # Update extension from CR
    if (-not [string]::IsNullOrEmpty($Extension)) {
        if ($UseSlackInfo) {
            $UpdateStage = $BaseDescr + ' Получение изменений расширения конфигурации "' + $Extension + '" из хранилища'
            Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
        }
        $ResultExt = Invoke-1CCRUpdateCfg -Conn $ConnExt -Log $Log
        if ($ResultExt.OK) {
            if ($ResultExt.ProcessedObjects) {
                if ($UseSlackInfo) {
                    $UpdateStage = $BaseDescr + ' Изменено объектов: ' + $ResultExt.ProcessedObjects.Count
                    Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
                }
                $IsRequiredUpdate = $True
            }
        }
        else {
            $ErrorInfo = $BaseDescr + ' ОШИБКА обновления базы: ' + $_ + '; ' + $ResultExt.out
            Send-SlackWebHook -HookUrl $SlackHookUrlAlerts -Text $ErrorInfo | Out-Null
            return
        }
    }

    if (-not $IsRequiredUpdate -and (Test-1CCfChanged -Conn $Conn)) {
        $IsRequiredUpdate = $True
    }
}
catch {
    $ErrorInfo = $BaseDescr + ' ОШИБКА обновления базы: ' + $_ + '; ' + $Result.out
    Send-SlackWebHook -HookUrl $SlackHookUrlAlerts -Text $ErrorInfo | Out-Null
    return
}

if (-not $IsRequiredUpdate) {
    if ($UseSlackInfo) {
        $UpdateStage = $BaseDescr + ' Не требуется обновление конфигурации информационной базы'
        Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
    }
    return
}

if ($UseDynamicUpdate) {
    $UpdateStage = $BaseDescr + ' Запуск динамического обновления конфигурации базы данных...'
    Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
    $Result = Invoke-1CUpdateDBCfg -Conn $Conn -Dynamic -Log $Log
    if ((-not $Result.OK) -or (Test-1CCfChanged -Conn $Conn)) {
        $UpdateStage = $BaseDescr + ' Ошибка динамического обновления. ' + $Result.Out
        Send-SlackWebHook -HookUrl $SlackHookUrlAlerts -Text $UpdateStage | Out-Null
        $IsRequiredUpdate = $True
    }
    else {
        $UpdateStage = $BaseDescr + ' Динамическое обновление успешно завершено.'
        Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
        break
    }
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

$Conn.UC = $PermissionCode
$ConnExt.UC = $PermissionCode

# Terminate sessions and update IB
Remove-1CIBSessions -Conn $Conn -TermMsg $ScriptMsg -Log $Log
Remove-1CIBConnections -Conn $Conn -Log $Log

$Result = Invoke-1CUpdateDBCfg -Conn $Conn -Log $Log
$ResultExt = @{OK = 1}
if (-not [string]::IsNullOrEmpty($Extension)) {
    $ResultExt = Invoke-1CUpdateDBCfg -Conn $ConnExt -Log $Log
}
$IsFailure = (-not $Result.OK) -or (-not $ResultExt.OK) -or (Test-1CCFChanged -Conn $Conn);

$AttemtsCounter = 1

$WaitSecOnFailure = 0
if ($AttemptsOnFailureCount -gt 0) {
    $WaitSecOnFailure = [int]($BlockPeriodMinutes * 60 / $AttemptsOnFailureCount)
}

While ($IsFailure) {

    if ($UseSlackInfo) {
        $UpdateStage = $BaseDescr + ' ОШИБКА обновления ИБ: ' + $Result.out
        if (-not [string]::IsNullOrEmpty($Extension)) {
            $UpdateStage = $UpdateStage + ", ext " + $ResultExt.out
        }
        Send-SlackWebHook -HookUrl $SlackHookUrlAlerts -Text $UpdateStage | Out-Null
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
    $ResultExt = @{OK = 1}
    if (-not [string]::IsNullOrEmpty($Extension)) {
        $ResultExt = Invoke-1CUpdateDBCfg -Conn $ConnExt -Log $Log
    }
    $IsFailure = (-not $Result.OK) -or (-not $ResultExt.OK) -or (Test-1CCFChanged -Conn $Conn);

}

if ((-not $IsFailure) -and (-not [string]::IsNullOrEmpty($ExternalProcessor))) {
    if ($UseSlackInfo) {
        $UpdateStage = $BaseDescr + ' Выполнение внешней обработки после обновления: ' + $ExternalProcessor;
        Send-SlackWebHook -HookUrl $SlackHookUrl -Text $UpdateStage | Out-Null
    }
    $Result = Invoke-1CExecute -Conn $Conn -ExternalProcessor $ExternalProcessor -Timeout $ExecuteTimeout -Log $Log
    $IsFailure = (-not $Result.OK)
    if ($UseSlackInfo -and $IsFailure) {
        $UpdateStage = $BaseDescr + ' Ошибка выполнения обработки данных после обновления конфигурации: ' + $Result.Out;
        Send-SlackWebHook -HookUrl $SlackHookUrlAlerts -Text $UpdateStage | Out-Null
    }
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
        $UpdateStage = $BaseDescr + ' ОШИБКА!!! Обновление НЕ выполнено по причине: ' + $Result.out + ' ' + $Result.msg;
        Send-SlackWebHook -HookUrl $SlackHookUrlAlerts -Text $UpdateStage | Out-Null
    }
}
