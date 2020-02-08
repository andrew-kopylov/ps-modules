
# log-module: version 1.1

# EXPORT

function New-Log($ScriptPath, $Dir, $Name, $OutHost) {
    
    $ScriptItem = Get-Item -Path $ScriptPath

    if ([string]::IsNullOrEmpty($Name)) {
        $Name = $ScriptItem.BaseName
    }

    if ([string]::IsNullOrEmpty($Dir)) {
       $Dir = Add-AuxLogPath -Path $ScriptItem.DirectoryName -AddPath logs
    }

    @{
        ScripstPath = $ScriptPath;
        Dir = $Dir;
        Name = $Name;
        OutHost = $OutHost;
     }
}

function Out-Log($Log, $Label, $Text, $OutHost, [switch]$InvokeThrow) {

    $LogDir = ''
    $LogName = ''

    if ($Log -ne $null) {
        $LogDir = $Log.Dir
        $LogName = $LogName.Name
    }

    if ([String]::IsNullOrEmpty($LogDir)) {
        $LogDir = Get-AuxLogDefaultDir
    }
    Test-AuxLogDir -Path $LogDir -CreateIfNotExist | Out-Null

    $LogName = $Log.Name;
    if ([String]::IsNullOrEmpty($LogName)) {
        $LogName = "ps-modules-default-log";
    }

    $LogFile = Add-AuxLogPath -Path $LogDir -AddPath ((Get-Date).ToString('yyyyMMdd') + '-' + $LogName + '.log')
    $OutLogText = Get-AuxLogText -Label $Label -Text $Text
    $OutLogText | Out-File -FilePath $LogFile -Append

    # Errors log
    if ($Lable -like '*error*') {
        $LogErrorFile = Add-AuxLogPath -Path $LogDir -AddPath ((Get-Date).ToString('yyyyMMdd') + '-' + $LogName + '_Errors.log')
        $OutLogText | Out-File -FilePath $LogErrorFile -Append    
    }

    if ($OutHost -or (($OutHost -ne $false) -and $Log.OutHost) -or (($OutHost -eq $null) -and ($Log.OutHost -eq $null))) {
        $OutLogText | Out-Host
    }

    if ($InvokeThrow) {
        throw $OutLogText
    }
}

# AUXILIARY

function Get-AuxLogText($Label, $Text) {
    $FullLogText = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss');
    $FullLogText = Add-AuxLogString -Str $FullLogText -Add $Label -Sep '.';
    $FullLogText = Add-AuxLogString -Str $FullLogText -Add $Text -Sep ': ';
    $FullLogText
}

function Get-AuxLogDefaultDir($ScriptPath) {
    $LogDir = ''

    if (-not [String]::IsNullOrEmpty($env:TEMP)) {$LogDir = $env:TEMP}
    else {$LogDir = $env:TMP}
    $LogDir = Add-AuxLogPath -Path $LogDir -AddPath 'ps-module-log'
    $LogDir
}

function Test-AuxLogDir($Path, [switch]$CreateIfNotExist) {
    if ($Path -eq $null) {Return}
    $TestRes = Test-Path -Path $Path
    if (-not $TestRes -and $CreateIfNotExist) {
        $Item = New-Item -Path $Path -ItemType Directory
        $TestRes = Test-Path -Path $Item.FullName
    }
    $TestRes
}

function Add-AuxLogPath($Path, $AddPath, $Sep = '\') {
    
    if ([String]::IsNullOrEmpty($AddPath)) {return $path}
    if ([String]::IsNullOrEmpty($Path)) {return $AddPath}

    if ($AddPath -is [System.Array]) {
        foreach ($AddPathItem in $AddPath) {
            $Path = Add-AuxLogPath -Path $Path -AddPath $AddPathItem -Sep $Sep
        }
    }
    else {
        if ($Path.EndsWith($Sep)) {
            $Path = $Path.Substring(0, $Path.Length - 1)
        }

        if ($AddPath.StartsWith($Sep)) {
            $AddPath = $AddPath.Substring(1, $Path.Length - 1)
        }
        $Path = $Path + $Sep + $AddPath    
    }

    $Path
}

function Add-AuxLogString($Str, $Add, $Sep = '') {
    
    $Result = ''

    if ($Add -is [System.Array]) {
        $Result = $Str
        foreach ($AddItem in $Add) {
            $Result = Add-AuxLogString -Str $Result -Add $AddItem -Sep $Sep
        }
    }
    else {
        if ([String]::IsNullOrEmpty($Str)) {
            $Result = $Add
        }
        elseif ([String]::IsNullOrEmpty($Add)) {
            $Result = $Str
        }
        else {
            $Result = $Str + $Sep + $Add
        }
    }

    $Result
}

Export-ModuleMember -Function '*-Log*'
