
Import-Module 1c-common-module


####
# 1C-Administration
####

function Test-1CCfChanged($Conn) {
    $ComConn = Get-1CComConnection -Conn $Conn
    $IsChanged = Invoke-ComObjectMethod -ComObject $ComConn -MethodName 'ConfigurationChanged'
    Remove-Variable -Name 'ComConn'
    $IsChanged
}

function Remove-1CIBConnections() {
    param (
        $Conn,
        [ValidateSet('1CV8', '1CV8C', 'Designer', 'COMConsole', 'SrvrConsole', 'BackgroundJob', 'COMConnection', 'WebClient', 'WSConnection')]
        $Application,
        $ConnectedBefore,
        $Log
    )
    
    $ProcessName = 'TeminateConnections'
    
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'Start'
    $ConnectionsInfo = Get-1CIBConnections -Conn $Conn

    $TerminatedConnections = @()
    foreach ($Connection in $ConnectionsInfo.Connections) {

        # Filter by AppID (1CV8, 1CV8C, Designer, COMConsole, SrvrConsole, ...)
        if ($Application -ne $null -and $Connection.Application -notin $Application) {continue}
        if ($ConnectedBefore -ne $null -and $Connection.ConnectedAt -ge $ConnectedBefore) {continue}
        if ($Connection.Application -like 'SrvrConsole') {continue}
        
        $ConnectionsInfo.WPConnection.Disconnect($Connection)
        $ConnectionDescr = [ordered]@{
            ConnID = $Connection.ConnID;
            Application = $Connection.Application;
            Host = $Connection.Host;
            ConnectedAt = $Connection.ConnectedAt;
            SessionID = $Connection.SessionID;
            Process = $Connection.Process;
        }
        $TerminatedConnections += $Connection;
        $ConnectionDescr = Get-1CArgs -TArgs $ConnectionDescr -ArgEnter '' -ValueSep '=' -ArgSep ' '
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Done' -LogText ('Connection ' + $ConnectionDescr)
    }    
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'End'
}

function Get-1CIBConnections($Conn) {
    $IBInfo = Get-1CIBInfo -Conn $Conn
    $Connections = $IBInfo.WPConnection.GetInfoBaseConnections($IBInfo.InfoBase)
    @{
        Agent = $IBInfoShort.Agent;
        Cluster = $IBInfoShort.Cluster;
        InfoBase = $IBInfoShort.InfoBase;
        WPConnection = $IBInfo.WPConnection;
        WorkingProcess = $IBInfo.WorkingProcess;
        Connections = $Connections;
    }
}

function Remove-1CIBSessions() {
    param (
        $Conn,
        [string]$TermMsg,
        [ValidateSet('1CV8', '1CV8C', 'Designer', 'COMConsole', 'SrvrConsole', 'BackgroundJob', 'COMConnection', 'WebClient', 'WSConnection')]
        $AppID,
        $StartedBefore,
        $Log
    )
    $ProcessName = 'TeminateSessions'
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogText ('Start "' + $TermMsg + '"')
    $SessionsInfo = Get-1CIBSessions -Conn $Conn
    $Agent = $SessionsInfo.Agent
    $Sessions = $SessionsInfo.Sessions
    $TerminatedSessions = @()
    foreach ($Session in $Sessions) {

        # Filter by AppID (1CV8, 1CV8C, Designer, COMConsole, SrvrConsole, ...)
        if ($AppID -ne $null -and $Session.AppID -notin $AppID) {continue}
        if ($StartedBefore -ne $null -and $Session.StartedAt -ge $StartedBefore) {continue}
        if ($Session.AppID -like 'SrvrConsole') {continue}
        
        $Agent.TerminateSession($SessionsInfo.Cluster, $Session, $TermMsg)
        $SessionDescr = [ordered]@{
            ID = $Session.SessionID;
            User = $Session.UserName;
            AppID = $Session.AppID;
            Host = $Session.Host;
            Started = $Session.StartedAt;
            cpuCurr = $Session.cpuTimeCurrent;
            cpu5min = $Session.cpuTimeLast5Min;
        }
        $TerminatedSessions += $Session;
        $SessionDescr = Get-1CArgs -TArgs $SessionDescr -ArgEnter '' -ValueSep '=' -ArgSep ' '
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Done' -LogText ('Session ' + $SessionDescr)

    }    
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'End'
}

function Get-1CIBSessions($Conn) {
    $IBInfoShort = Get-1CIBInfo -Conn $Conn -ShortInfo
    $Sessions = $IBInfoShort.Agent.GetInfoBaseSessions($IBInfoShort.Cluster, $IBInfoShort.InfoBase)
    @{
        Agent = $IBInfoShort.Agent;
        Cluster = $IBInfoShort.Cluster;
        InfoBase = $IBInfoShort.InfoBase;
        Sessions = $Sessions;
    }
}

function Set-1CIBSessionsDenied($Conn, [switch]$Denied, $From, $To, [string]$Msg, [string]$PermissionCode) {

    if ($From -is [datetime]) {
        $From = $From.ToString('yyyy-MM-dd HH:mm:ss')
    }

    if ($To -is [datetime]) {
        $To = $To.ToString('yyyy-MM-dd HH:mm:ss')
    }
    
    $IBInfo = Get-1CIBInfo -Conn $Conn
    $InfoBase = $IBInfo.InfoBase
    $InfoBase.ConnectDenied = $Denied
    if ($Denied) {
        $InfoBase.DeniedFrom = $From
        $InfoBase.DeniedTo = $To
        $InfoBase.DeniedMessage = $Msg
        if ($PermissionCode -ne '') {
            $InfoBase.PermissionCode = $PermissionCode
        }
    }
    $IBInfo.WPConnection.UpdateInfoBase($InfoBase)
    $IBInfo
}

function Get-1CIBInfo($Conn, [switch]$ShortInfo) {

    if ($ShortInfo) {

        $ClusterInfo = Get-1CCluster -Conn $Conn -Auth
  
        $Agent = $ClusterInfo.Agent
        $Cluster = $ClusterInfo.Cluster
        $InfoBases = $Agent.GetInfoBases($Cluster)

        $WPConnection = $null
        $WorkingProcess = $null

    }
    else {
    
        $WPInfo = Get-1CWPConnection -Conn $Conn -Auth

        $WPConnection = $WPInfo.WPConnection
        if ($Conn.Usr -ne $null -and $Conn.Usr -ne '') {
            $WPConnection.AddAuthentication($Conn.Usr, $Conn.Pwd)
        } 

        $Agent = $WPInfo.Agent;
        $Cluster = $WPInfo.Cluster;
        $WorkingProcess = $WPInfo.WorkingProcess;
        $InfoBases = $WPConnection.GetInfoBases()

    }

    $FindedInfoBase = $null
    
    if (-not [string]::IsNullOrEmpty($Conn.Ref)) {
        foreach ($InfoBase in $InfoBases) {
            if ($InfoBase.Name -like $Conn.Ref) {
                $FindedInfoBase = $InfoBase;
                break
            }
        }
    }
   
    @{
        Agent = $Agent;
        Cluster = $Cluster;
        InfoBase = $FindedInfoBase;
        WorkingProcess = $WorkingProcess;
        WPConnection = $WPConnection;
    }
}

function Get-1CWPConnection($Conn, $WorkingProcess, [switch]$Auth) {

    $ClusterInfo = Get-1CCluster -Conn $Conn -Auth:$Auth   
    if ($ClusterInfo -eq $null -or $ClusterInfo.Cluster -eq $null) {
        return $null
    }

    if ($WorkingProcess -eq $null) {
        $WorkingProcesses = $ClusterInfo.Agent.GetWorkingProcesses($ClusterInfo.Cluster)
        if ($WorkingProcesses -eq $null -or $WorkingProcesses.GetLength(0) -eq 0) {
            return $null
        }
        $WorkingProcess = $WorkingProcesses.GetValue($WorkingProcesses.GetUpperBound(0))
    }
    
    $ComConntector = Get-1CComConnector -V8 $Conn.V8
    $WPConnection = $ComConntector.ConnectWorkingProcess($WorkingProcess.hostname + ':' + $WorkingProcess.MainPort)

    if ($Auth -and $WPConnection -ne $null) {
        $WPConnection.AuthenticateAdmin($Conn.ClUsr, $Conn.ClPwd)
    }

    @{
        Agent = $ClusterInfo.Agent;
        Cluster = $ClusterInfo.Cluster;
        WorkingProcess = $WorkingProcess;
        WPConnection = $WPConnection;
    }
}

function Get-1CWorkingProcesses($Conn, $Agent, $Cluster, [switch]$Auth) {

    if ($Agent -eq $null) {
        $Agent = Get-1CAgent -Conn $Conn -Auth:$Auth
    }

    if ($Cluster -eq $null) {
        $ClusterInfo = Get-1CCluster -Conn $Conn -Agent $Agent -Auth:$Auth   
        if ($ClusterInfo -eq $null -or $ClusterInfo.Cluster -eq $null) {
            return $null
        }
        $Agent = $ClusterInfo.Agent
        $Cluster = $ClusterInfo.Cluster
    }
    
    $WorkingProcesses = $Agent.GetWorkingProcesses($Cluster)

    @{
        Agent = $Agent;
        Cluster = $Cluster;
        WorkingProcesses = $WorkingProcesses;
    }
}

function Get-1CAllClusters($Conn, $Agent, [switch]$Auth) {
    
    if ($Agent -eq $null) {
        $Agent = Get-1CAgent -Conn $Conn -Auth:$Auth
    }
    if ($Agent -eq $null) {
        return $null
    }
    $Clusters = $Agent.GetClusters()

    foreach ($Cluster in $Clusters) {
        # Authentication on Cluster
        if ($Auth) {
            $Agent.Authenticate($Cluster, $Conn.ClUsr, $Conn.ClPwd)
        }
    }
    @{Agent = $Agent; Clusters = $Clusters}
}

function Get-1CCluster($Conn, $Agent, [switch]$Auth) {
    
    if ($Agent -eq $null) {
        $Agent = Get-1CAgent -Conn $Conn -Auth:$Auth
    }
    if ($Agent -eq $null) {
        return $null
    }
    $Clusters = $Agent.GetClusters()

    $FindedCluster = $null

    # Cluster search
    if ($Clusters.GetLength(0) -eq 0) {
        # No clasters.
    } elseif ($Clusters.GetLength(0) -eq 1) {
       $FindedCluster = $Clusters.GetValue($Clusters.GetUpperBound(0))
    } else {
        foreach ($Cluster in $Clusters) {
            if (Test-1CClusterConn -Cluster $Cluster -Conn $Conn) {
                $FindedCluster = $Cluster
                break;
            }     
        }
        if ($FindedCluster -eq $null -and $Clusters.GetLength(0) -gt 1) {
            $FindedCluster = $Clusters.GetValue($Clusters.GetUpperBound(0))
        }
    }

    # Authentication on Cluster
    if ($Auth -and $FindedCluster -ne $null) {
        $Agent.Authenticate($FindedCluster, $Conn.ClUsr, $Conn.ClPwd)
    }

    @{Agent = $Agent; Cluster = $FindedCluster}
}

function Test-1CClusterConn($Cluster, $Conn) {
    if (Test-1CClusterSrvrString -Cluster $Cluster -Srvr $Conn.ClSrvr) {
        return ($true)
    } elseif (Test-1CClusterSrvrString -Cluster $Cluster -Srvr $Conn.Srvr) {
        return ($true)
    } elseif ($Conn.AgSrvr -is [string] -and $Conn.AgSrvr -ne '') {
        $AgSrvr = $Conn.AgSrvr.Split(':')[0];
        $AgPort = $Conn.AgSrvr.Split(':')[1];
        $AgPort = Get-ValueIfEmpty -Value $AgPort -IfEmptyValue '1540'
        $ClPort = [decimal]$AgPort + 1
        if ($Cluster.HostName -eq $AgSrvr -and $Cluster.MainPort -eq $ClPort) {
            return ($true)
        }
    }
    ($false)
}

function Test-1CClusterSrvrString($Cluster, [string]$Srvr) {
    [string]$ClusterConnStr = $Cluster.HostName + ':' + $Cluster.MainPort
    return ($ClusterConnStr.ToUpper() -eq $Srvr.ToUpper() -or $ClusterConnStr.ToUpper() -eq ($Srvr + ':1541').ToUpper())
}

function Get-1CAgent($Conn, [switch]$Auth) {
    $ComConnector = Get-1CComConnector -V8 $Conn.V8
    $AgentConnStr = $Conn.AgSrvr;
    if ([string]::IsNullOrEmpty($AgentConnStr)) {
        $SubstrSrvr = $Conn.Srvr.Split(':')
        $AgentSrv = $SubstrSrvr[0]
        $ClusterMngrPort = $SubstrSrvr[1]
        if ([string]::IsNullOrEmpty($ClusterMngrPort)) {
            $AgentConnStr = $AgentSrv
        }
        else {
            $AgentPort = ([int]$ClusterMngrPort - 1)
            $AgentConnStr = $AgentSrv + ':' + $AgentPort.ToString()
        }
    }
    if ([string]::IsNullOrEmpty($AgentConnStr)) {
        $AgentConnStr = 'localhost';
    }
    $AgentConn = $ComConnector.ConnectAgent($AgentConnStr)
    if ($Auth) {
        $AgentConn.AuthenticateAgent($Conn.AgUsr, $Conn.AgPwd)
    }
    $AgentConn;
}


####
# COM-Connector (work with com-objects)
####

function Get-1CComConnection($Conn) {
    $ComConnector = Get-1CComConnector -V8 $Conn.V8
    $ComConnStr = Get-1CComConnectionString -Conn $Conn
    $ComConn = $ComConnector.Connect($ComConnStr)
    return $ComConn
}

function Get-1CComConnectionString($Conn) {
    $TArgs = [ordered]@{
        File = $Conn.File;
        Srvr = $Conn.Srvr;
        Ref = $Conn.Ref;
        Usr = $Conn.Usr;
        Pwd = $Conn.Pwd;
        UC = $Conn.UC;
    }
    $ArgsStr = Get-1CArgs -TArgs $TArgs -ArgEnter '' -ValueSep '=' -ArgSep ';'
    $ArgsStr
}

function Register-1CComConnector($V8) {
    $BinDir = Get-1CV8Bin -V8 $V8
    $DllPath = Add-1CPath -Path $BinDir -AddPath 'comcntr.dll'
    $ProcessArgs = '/s "' + $DllPath + '"'
    Start-Process -FilePath 'regsvr32.exe' -ArgumentList $ProcessArgs -NoNewWindow
}

function Get-1CComConnector($V8) {
    New-Object -ComObject 'V83.ComConnector' -Strict 
}

function Get-1CComObjectString($ComConn, $ComObject) {
    Invoke-ComObjectMethod -ComObject $ComConn -MethodName 'String' -Parameters $ComObject
}

function Get-ComObjectProperty($ComObject, $PropertyName) {
    $PropertyValue = [System.__ComObject].InvokeMember($PropertyName, [System.Reflection.BindingFlags]::GetProperty, $null, $ComObject, $null)
    $PropertyValue
}

function Invoke-ComObjectMethod($ComObject, $MethodName, $Parameters) {
    $MethodReturn = [System.__ComObject].InvokeMember($MethodName, [System.Reflection.BindingFlags]::InvokeMethod, $null, $ComObject, $Parameters)
    $MethodReturn
}
