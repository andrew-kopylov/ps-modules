
Import-Module common-module
Import-Module log-module

####
# INIT PARAMETERS FUNCTION
####

# Platform parameters {Ver, Cat}.
function Get-1CV8 {
    param (
        $Ver = '',
        $Dir = '',
        [ValidateSet('x32', 'x64')]
        $Arch
    )
    @{Ver = $Ver; Dir = $Dir; Arch = $Arch}
}

# Base connection parameters.
function Get-1CConn {
    param (
        $V8,
        $File,
        $Srvr,
        $Ref,
        $Usr,
        $Pwd,
        $CRPath,
        $CRUsr,
        $CRPwd,
        $Extension,
        $UC,
        $AgSrvr,
        $AgUsr,
        $AgPwd,
        $ClSrvr,
        $ClUsr,
        $ClPwd,
        $Visible,
        $DisableStartupMessages,
        $DisableStartupDialogs = $True,
        $Local,
        $VLocal,
        $Timeout,
        $Conn
    )
    
    $NewConn = @{
        V8 = $V8;
        File = $File;
        Srvr = $Srvr;
        Ref = $Ref;
        Usr = $Usr;
        Pwd = $Pwd;
        CRPath = $CRPath;
        CRUsr = $CRUsr;
        CRPwd = $CRPwd;
        Extension = $Extension;
        UC = $UC;
        AgSrvr = $AgSrvr;
        AgUsr = $AgUsr;
        AgPwd = $AgPwd;
        ClSrvr = $ClSrvr;
        ClUsr = $ClUsr;
        ClPwd = $ClPwd;
        Visible = $Visible;
        DisableStartupMessages = $DisableStartupMessages;
        DisableStartupDialogs = $DisableStartupDialogs;
        Local = $Local;
        VLocal = $VLocal;
        Timeout = $Timeout;
    }

    if ($Conn -ne $null) {
        $UnionConn = @{}
        foreach ($Key in $Conn.Keys) {
            if ($NewConn.$Key -eq $null) {
                $NewConn.$Key = $Conn.$Key
            }
        }
    }

    $NewConn.AgUsr = [string]$NewConn.AgUsr;
    $NewConn.AgPwd = [string]$NewConn.AgPwd;
    $NewConn.ClUsr = [string]$NewConn.ClUsr;
    $NewConn.ClPwd = [string]$NewConn.ClPwd;

    return $NewConn
}

# Log parameters.
function Get-1CLog($Dir, $Name, $Dump, $ClearDump = $true) {
    New-Log -Dir $Dir -Name $Name
}

# Log text for 1C process. 
function Add-1CLog($Log, $ProcessName, $LogHead = "", $LogText, $Result = $null, $OK = $null) {
    Out-Log -Log $Log -Label (Add-CmnString -Str $ProcessName -Add $LogHead -Sep ".") -Text $LogText
    if ($Result -ne $null) {
         if ($OK -ne $null) {$Result.OK = $OK}
         $Result.Msg = Add-CmnString -Str $Result.Msg -Add $LogText
    }
}

# Get arguments string.
function Get-1CArgs($TArgs, $ArgsStr = '', $ArgEnter = '/', $ValueSep = ' ', $ArgSep = ' ', $RoundValueSign = '', [switch]$IsMandatoryRoundSign) {
    foreach ($ArgKey in $TArgs.Keys) {
        $ArgValue = $TArgs.($ArgKey)

        if ($ArgValue -eq $null) {continue}

        $ArgStr = ''
        if ($ArgValue -is [bool] -or $ArgValue -is [switch]) {
            if ($ArgValue -eq $true) {
                $ArgStr = $ArgEnter + $ArgKey
            }
        }
        elseif ($ArgValue -is [string]) {
            if (('[' + $ArgKey + ']').ToUpper() -eq $ArgValue.ToUpper()) {
                # It's template: ArgValue = '[ArgKey]' then adding only ArgValue as template.
                $ArgStr = $ArgValue
            }
            elseif ($IsMandatoryRoundSign -or ($ArgValue -match '\s')) {
                $ArgStr = $ArgEnter + $ArgKey + $ValueSep + (Add-RoundSign -Str $ArgValue -RoundSign $RoundValueSign)
            }
            else {
                $ArgStr = $ArgEnter + $ArgKey + $ValueSep + $ArgValue
            }
        }
        else {
            $ArgStr = $ArgEnter + $ArgKey + $ValueSep + $ArgValue.ToString()
        }
        $ArgsStr = Add-String -Str $ArgsStr -Add $ArgStr -Sep $ArgSep
    }
    $ArgsStr
}

# Return full filename 1cv8 ".../bin/1cv8.exe".
function Get-1CV8Exe($V8) {
    Add-1CPath -Path (Get-1Cv8Bin -V8 $V8) -AddPath '1cv8.exe'
}

function Get-1CV8Bin($V8) { 
    $V8 = 1CV8VerInfo -V8 $V8
    $V8DirVer = Add-1CPath -Path $V8.Dir -AddPath $V8.Ver
    Add-1CPath -Path $V8DirVer -AddPath 'bin'
}

function Get-1CV8VerInfo($V8) {

    if ($V8 -eq $null) {
        $V8Dir = ''
        $V8Ver = ''
        $V8Arch = ''
    }
    elseif ($V8 -is [string]) {
        $V8Dir = ''
        $V8Ver = $V8
        $V8Arch = ''
    }
    else {
        $V8Dir = $V8.Dir     
        $V8Ver = $V8.Ver
        $V8Arch = $V8.Arch
    }

    $V8Dir32 = 'C:\Program Files (x86)\1cv8'
    $V8Dir64 = 'C:\Program Files\1cv8'

    if ('x64' -in @($V8Dir, $V8Arch)) {
        $V8Dir = $V8Dir64
    }
    elseif ('x32' -in @($V8Dir, $V8Arch)) {
        $V8Dir = $V8Dir32
    }
    elseif ($V8Ver -eq 'x64') {
        $V8Ver = ''
        $V8Dir = $V8Dir64
    }
    elseif ($V8Ver -eq 'x32') {
        $V8Ver = ''
        $V8Dir = $V8Dir32
    }
    else {
        if (Test-Path -Path "$V8Dir64\$V8Ver") {
            $V8Dir = $V8Dir64
        }
        else {
            $V8Dir = $V8Dir32
        }    
    }

    if ($V8Ver -eq '' -or $V8Ver -eq $null) {
        $DirMask = Add-CmnPath -Path $V8Dir -AddPath "*.*.*.*"
        $LastVerDir = Get-ChildItem -Path $DirMask -Directory | Sort-Object -Property BaseName | Select-Object -Last 1
        $V8Ver = $LastVerDir.Name
        $V8Dir = $LastVerDir.Parent.FullName
    }

    @{Dir = $V8Dir; Ver = $V8Ver}
}

function Get-1CConnStringCommon($Conn) {
    
    $TArgs = [ordered]@{}

    if (-not [String]::IsNullOrEmpty($Conn.File)) {
        $TArgs.File = $Conn.File
    }
    else {
        $TArgs.Srvr = $Conn.Srvr
        $TArgs.Ref = $Conn.Ref
    }

    if (-not [String]::IsNullOrEmpty($Conn.Usr)) {
        $TArgs.Usr = $Conn.Usr
        $TArgs.Pwd = $Conn.Pwd
    }

    $ConnString = (Get-1CArgs -TArgs $TArgs -ArgEnter '' -ValueSep '=' -ArgSep ';' -RoundValueSign '""' -IsMandatoryRoundSign) + ';'
    $ConnString
}

function Get-1CConnString($Conn) {
    $Base = Get-1CConnStringBase -Conn $Conn
    $Auth = Get-1CConnStringAuth -Conn $Conn
    $CR = Get-1CCRConnString -Conn $Conn
    $ConnStr = ''
    if ($Conn.UC -ne $null -and $Conn.UC -ne '') {
        $ConnStr = Add-String -str $ConnStr -Add ('/UC ' + $Conn.UC) -Sep ' ';
    }
    $ConnStr = Add-String -str $ConnStr -Add $Base -Sep ' ';
    $ConnStr = Add-String -str $ConnStr -Add $Auth -Sep ' ';
    $ConnStr = Add-String -str $ConnStr -Add $CR -Sep ' ';

    if ($Conn.Visible -eq $true) {
        $ConnStr = Add-String -str $ConnStr -Add ' /Visible' -Sep ' ';
    }

    $ConnStr 
}

function Get-1CConnStringBase($Conn) {
    # Base path parameters $Prm @{File, Srvr, Ref}.
    $Base = '';
    if ($Conn.File -ne '' -and $Conn.File -ne $null) {
        $Base = '/F "[File]"';
        $Base = $Base.Replace("[File]", $Conn.File);
    }
    elseif ($Conn.Ref -ne '' -and $Conn.Ref -ne $null) {
        $Base = '/S "[Srvr]\[Ref]"';
        $Base = $Base.Replace("[Srvr]", $Conn.Srvr);
        $Base = $Base.Replace("[Ref]", $Conn.Ref);
    }
    $Base;
}

function Get-1CConnStringAuth($Conn) { 
    # Authorization parameters @{Usr, Pwd}.
    $Auth = ''
    if (($Conn.File -ne '' -and $Conn.File -ne $null) -or ($Conn.Ref -ne '' -and $Conn.Ref -ne $null)) {
        $Auth = '/N "[Usr]" /P "[Pwd]"'
        $Auth = $Auth.Replace("[Usr]", $Conn.Usr)
        $Auth = $Auth.Replace("[Pwd]", $Conn.Pwd)
    }
    $Auth
}

function Get-1CCRConnString($Conn) {
    [string]$ConnStr = ''
    if ($Conn.CRPath -ne '' -and $Conn.CRPath -ne $null) {
        $ConnStr = '/ConfigurationRepositoryF "[Path]" /ConfigurationRepositoryN "[Usr]" /ConfigurationRepositoryP "[Pwd]"';
        $ConnStr = $ConnStr.Replace("[Path]", $Conn.CRPath);
        $ConnStr = $ConnStr.Replace("[Usr]", $Conn.CRUsr);
        $ConnStr = $ConnStr.Replace("[Pwd]", $Conn.CRPwd);
    }
    $ConnStr; 
}

####
# Auxiliary functions
####

# Test dir, if not exist then add it.
function Test-AddDir($Path) {Test-CmnDir -Path $Path -CreateIfNotExist}

# Log text: 
function Add-LogText($LogDir, $LogName, $LogMark = '', $LogHead = '', $LogText) {
    
    if ($LogText -eq '') {
        return
    }
    Test-CmnDir -Path $LogDir -CreateIfNotExist

    $LogDate = Get-Date
    $LogFile = Add-CmnPath -Path $LogDir -AddPath ($LogDate.ToString('yyyyMMdd') + '_' + $LogName + '.log')

    $FullLogText = $LogDate.ToString('yyyy.MM.dd HH:mm:ss');
    $FullLogText = Add-String -Str $FullLogText -Add $LogMark -Sep ' ';
    $FullLogText = Add-String -Str $FullLogText -Add $LogHead -Sep '.';
    $FullLogText = Add-String -Str $FullLogText -Add $LogText -Sep ': ';

    $FullLogText | Out-File -FilePath $LogFile -Append;
    $FullLogText | Out-Host;
    $FullLogText
}

function Add-String([string]$Str, [string]$Add, [string]$Sep = '') {
    Add-CmnString -Str $Str -Add $Add -Sep $Sep
} 

function Add-RoundSign($Str, $RoundSign) {
    if ([String]::IsNullOrEmpty($Str)) {return $Str}
    if (-not $Str.StartsWith($RoundSign)) {$Str = $RoundSign + $Str}
    if (-not $Str.EndsWith($RoundSign)) {$Str = $Str + $RoundSign}
    $Str
}

function Remove-RoundSign([string]$Str, [string]$RoundSign) {
    if ([String]::IsNullOrEmpty($Str)) {return $Str}
    $Str.Trim($RoundSign)   
}

function Add-1CPath([string]$Path, $AddPath, $Sep = '\') {
    Add-CmnPath -Path $Path -AddPath $AddPath -Sep $Sep
}

function Get-ValueIsEmpty($Value, $AddEmptyValues) {
    $EmptyValues = ($null, '', 0)
    ($Value -in $EmptyValues -or $Value -in $AddEmptyValues)
}

function Get-ValueIfEmpty($Value, $IfEmptyValue, $AddEmptyValues) {
    if (Get-ValueIsEmpty -Value $Value -AddEmptyValues $AddEmptyValues) {
        return $IfEmptyValue
    }
    $Value
}

function Get-ValueIfNull($Value, $IfNullValue) {
    if ($Value -eq $null) {
        return $IfNullValue
    }
    $Value
}

function Get-1CPropertyValues {
    param (
        $Collection,
        $Property
    )
    
    begin {
        $ValuesArray = @()
        if ($Collection -ne $null) {
            $ValuesArray = ($Collection | Get-1cPropertyValues -Property $Property)
        }
    }

    process {
        if ($_ -is [System.Array]) {
            $NewValuesArray = ($_ | Get-1cPropertyValues -Property $Property)
            foreach ($PropertyValue in $NewValuesArray) {
                if ($PropertyValue -ne $null -and $PropertyValue -notin $ValuesArray) {
                    $ValuesArray += $PropertyValue
                }
            }
        }
        elseif ($_ -ne $null) {
            $PropertyValue = $_.$Property
            if ($PropertyValue -ne $null -and $PropertyValue -notin $ValuesArray) {
                $ValuesArray += $PropertyValue
            }
        }
    }
    end {
        $ValuesArray
    }
}

function Test-1CHashTable ($Object) {
    if ($Object -eq $null) {return $false}
    # Is HashTable or OrderedDictionary
    (($Object -is [hashtable]) -or ($Object -is [System.Object] -and $Object.GetType().name -eq 'OrderedDictionary'))
}
