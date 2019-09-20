# Update test-bases

$ModulePath = $PSScriptRoot + "\modules\1c-module.ps1"
Import-Module $ModulePath -Force

# Delay for updating IB with blocking.
$BlockDelayMin = 15
$BlockPeriodMin = 5

# 1C-agent adress
$AgentAddr = 'localhost'

# Current Powershell command file
$PSCmdFile = Get-Item -Path $PSCommandPath

# Log
$Log = Get-1CLog -Dir ($PSCmdFile.DirectoryName + '\logs') -Name $PSCmdFile.BaseName

# Updating bases array form configuration file.
$ConfigFile = $PSCmdFile.DirectoryName + '\config\' + $PSCmdFile.BaseName + ".conf";
$ConfigData =  Get-Content -Path $ConfigFile;

# Default values
$DefConn = Get-1CConn -Srvr 'localhost'  -Ref '' -Usr 'robot_updater' -Pwd '' -CRPath 'tcp://localhost/[CRName]' -CRUsr 'test' -CRPwd '' -AgSrvr $AgentAddr

$ConnArray = @()

# Read connection to test IB to $ConnArray
foreach ($ConfigStr in $ConfigData) {

    $ConfigStr = [String]$ConfigStr

    # Data before comment
    $ConfigStrData = $ConfigStr.Split("#").Get(0);
    if ($ConfigStrData -eq '') {continue}

    # Update base description.
    # Descr format: ibserver;ibname;ibusr;ibpwd;crpath;crusr;crpwd
    $ConnArr = $ConfigStrData.Split(';');
    if ($ConnArr.Count -lt 7) {
        $Msg = 'Ошибка чтения параметров обновления базы: ' + $ConfigStrData
        Add-1CLog -Log $Log -ProcessName 'UpdateScript' -LogHead 'Error' -LogText $Msg
        continue
    } 

    $Conn = Get-1CConn -Srvr ($ConnArr.Get(0)) -Ref ($ConnArr.Get(1)) -Usr ($ConnArr.Get(2)) -Pwd ($ConnArr.Get(3)) -CRPath ($ConnArr.Get(4)) -CRUsr ($ConnArr.Get(5)) -CRPwd ($ConnArr.Get(6))
 
    foreach ($ConnKey in $DefConn.Keys) {
        if ($ConnKey -like 'CRPath') {
            if (-not $Conn.CRPath.Contains('/') -and -not $Conn.CRPath.Contains('\')) {
                $Conn.CRPath = $DefConn.CRPath.Replace('[CRName]', $Conn.CRPath)    
            }
        }
        else {
            $Conn[$ConnKey] = Get-ValueIfEmpty -Value $Conn[$ConnKey] -IfEmptyValue $DefConn[$ConnKey] -AddEmptyValues '*'
        }
    }
    
    $ConnArray += $Conn
}

$ToBlockConn = @()
$ScriptMsg = 'Обновление конфигурации тестовой базы'

# Terminate Designers
$IsTerminatedSessions = $false
foreach ($Conn in $ConnArray) {
    $Result = Terminate-1CInfoBaseSessions -Conn $Conn -TermMsg $ScriptMsg -AppID 'Designer' -Log $Log
    if ($Result.TerminatedSessions.Count -gt 0) {
        $IsTerminatedSessions = $true
    }
}
if ($IsTerminatedSessions) {
    Start-Sleep -Seconds 15
}

# Get conf from CR and attempt dynamic updating DB.
foreach ($Conn in $ConnArray) {
    $Result = Invoke-1CCRUpdateCfg -Conn $Conn -Log $Log
    if (($Result.ProcessedObjects.Count -gt 0) -or (Test-1CConfigurationChanged -Conn $Conn)) {
        Invoke-1CUpdateDBCfg -Conn $Conn -Dynamic -Log $Log
        if (Test-1CConfigurationChanged -Conn $Conn) {
            $ToBlockConn += $Conn
        }
    }
}

if ($ToBlockConn.Count -eq 0) {
    break
}

$PermissionCode = 'CfgUpdate-' + (Get-Date).ToString('HHMMss')

# Block IB for updating
foreach ($Conn in $ToBlockConn) {
    $BlockFrom = (Get-Date).AddMinutes($BlockDelayMin)
    $BlockTo = ($BlockFrom).AddMinutes($BlockPeriodMin)
    $BlockMsg = $ScriptMsg + ' с ' + $BlockFrom.ToString('HH:mm') + ' в течении ' + $BlockPeriodMin + ' минут.'
    Add-1CLog -Log $Log -ProcessName '1CInfoBaseSessions' -LogHead 'Block' -LogText $BlockMsg
    Set-1CInfoBaseSessionsDenied -Conn $Conn -Denied -From $BlockFrom -To $BlockTo -Msg $BlockMsg -PermissionCode $PermissionCode
}

# Delay
Add-1CLog -Log $Log -ProcessName 'UpdateTestBasesCfg' -LogHead 'Delay' -LogText ('Minutes ' + $BlockDelayMin)
Start-Sleep -Seconds ($BlockDelayMin * 60)

# Terminate sessions and update IB
foreach ($Conn in $ToBlockConn) {
    $Conn.UC = $PermissionCode
    Terminate-1CInfoBaseSessions -Conn $Conn -TermMsg $ScriptMsg -Log $Log
    Invoke-1CUpdateDBCfg -Conn $Conn -Log $Log
    Set-1CInfoBaseSessionsDenied -Conn $Conn
}
