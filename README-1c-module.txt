# ps1c
PowerShell 1C-module
Version 1.3

# Parameters
Get-1CV8($Ver, $Dir)
Get-1CConn($V8, $File, $Srvr, $Ref, $Usr, $Pwd, $CRPath, $CRUsr, $CRPwd)
Get-1CLog($Dir, $Name, $Dump, $ClearDump)

# Service
Start-1CService($Log)
Stop-1CService($Log)
Restart-1CService($Log)

# Configuration
Invoke-1CUpdateDBCfg($Conn, $Dynamic, ..., $Log)
Invoke-1CCompareCfg($Conn, $FirstConfigurationType, ..., $SecondConfigurationType, ..., $ReportFormat, $ReportFile, $Log)
Invoke-1CDumpCfg($Conn, $CfgFile, $Log)
Invoke-1CLoadCfg($Conn, $CfgFile, $Log)

# Configuration repository
Invoke-1CCRUpdateCfg($Conn, [int]$v, $Revised, $force, $Objects, [switch]$includeChildObjectsAll, $Log)
Invoke-1CCRLock($Conn, $Objects, [switch]$includeChildObjectsAll, $Revised, $Log)
Invoke-1CCRCommit($Conn, $Objects, [switch]$includeChildObjectsAll, $comment, $keepLocked, $force, $Log)
Invoke-1CCRUnlock($Conn, $Objects, [switch]$includeChildObjectsAll, $force, $Log)
Invoke-1CCRClearChache($Conn, $ChacheType, $Log)
Invoke-1CCRAddUser($Conn, $User, $Pwd, $Rights, [switch]$RestoreDeletedUser, $Log)
Invoke-1CCRCopyUsers($Conn, $Path, $User, $Pwd, $Rights, [switch]$RestoreDeletedUser, $Log)
Invoke-1CCRReport($Conn, $ReportFile, $NBegin, $NEnd, [switch]$GroupByObject, [switch]$GroupByComment, $Log)

# 1C-administration
Test-1CConfigurationChanged($Conn)
Terminate-1CInfoBaseSessions($Conn, $TermMsg, $Log)
Set-1CInfoBaseSessionsDenied($Conn, [switch]$Denied, $From, $To, $Msg, $PermissionCode)
Get-1CInfoBaseSessions($Conn)
Get-1CInfoBaseInfo($Conn)
Get-1CWorkingProcess($Conn, [switch]$Auth)
Get-1CCluster($Conn, [switch]$Auth)
Get-1CAgent($Conn, [switch]$Auth)

# Com-connector
Convert-1CMXLtoTXT($ComConn, $MXLFile, $TXTFile)
Get-1CComConnection($Conn)
Get-1CComConnectionString($Conn)
Register-1CComConnector($V8)
Get-1CComConnector($V8)
Get-1CComObjectString($ComConn, $ComObject)

# Managing 1C-module
Get-1CModuleVersion
Update-1CModule($Log)
