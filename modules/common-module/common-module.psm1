# version 1.0

# RUN COMMANDS

function Invoke-CmnCmd {
    param (
        $FilePath,
        $Arguments,
        $WorkingDirectory,
        $Timeout
    )

    $ProcInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcInfo.FileName = $FilePath
    $ProcInfo.Arguments = $Arguments
    $ProcInfo.RedirectStandardError = $true
    $ProcInfo.RedirectStandardOutput = $true
    $ProcInfo.UseShellExecute = $false
    $ProcInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $ProcInfo.CreateNoWindow = $true

    if (-not [string]::IsNullOrEmpty($WorkingDirectory)) {
        $ProcInfo.WorkingDirectory = $WorkingDirectory
    }

    $Proc = New-Object System.Diagnostics.Process
    $Proc.StartInfo = $ProcInfo

    $Begin = Get-Date

    $Proc.Start() | Out-Null

    $TimeoutExceeded = $false
    if ($Timeout) {
        $BorderDate = $Begin.AddSeconds($Timeout)
        While (-not $Process.HasExited) {
            if ((Get-Date) -gt $BorderDate) {
                $Process.Kill()
                $TimeoutExceeded = $true
                break
            }
            Start-Sleep -Seconds 1
        }
    }
    else {
        $Proc.WaitForExit() | Out-Null
    }

    $End = Get-Date

    $Result = @{OK = 0; ExitCode = 0; Error = ''; Out = ''; Process = $Proc;}
    $Result.TimeTaken = New-TimeSpan -Start $Begin -End $End

    if ($TimeoutExceeded) {
        $Result.ExitCode = 1
        $Result.Error = 'Timeout exceeded'
    }
    elseif ($Proc.ExitCode) {
        $Result.ExitCode = $Proc.ExitCode
        $Result.Error = $Proc.StandardError.ReadToEnd()
    } 
    else {
        $Result.OK = 1
    }
    $Result.Out = $Proc.StandardOutput.ReadToEnd()

    $Result
}

# WORK WITH FILES&DIR PATHS

function Test-CmnDir($Path, [switch]$CreateIfNotExist) {
    if ($Path -eq $null) {Return}
    $TestRes = Test-Path -Path $Path
    if (-not $TestRes -and $CreateIfNotExist) {
        $Item = New-Item -Path $Path -ItemType Directory
        $TestRes = Test-Path -Path $Item.FullName
    }
    $TestRes
}

function Get-CmnPathParent($Path) {
    $Info = [System.IO.DirectoryInfo]::new($Path)
    $Info.Parent.FullName
}

function Get-CmnPathBaseName($Path) {
    $Info = [System.IO.DirectoryInfo]::new($Path)
    $Info.BaseName
}

function Add-CmnPath($Path, $AddPath, $Sep = '\') {
    
    if ([String]::IsNullOrEmpty($AddPath)) {return $path}
    if ([String]::IsNullOrEmpty($Path)) {return $AddPath}

    if ($AddPath -is [System.Array]) {
        foreach ($AddPathItem in $AddPath) {
            $Path = Add-CmnPath -Path $Path -AddPath $AddPathItem -Sep $Sep
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

function Add-CmnString($Str, $Add, $Sep = '') {
  
    $Result = ''

    if ($Add -is [System.Array]) {
        $Result = $Str
        foreach ($AddItem in $Add) {
            $Result = Add-CmnString -Str $Result -Add $AddItem -Sep $Sep
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

# WORK WITH ARGUMENTS

function Get-CmnArgsDOS($ArgList, $ArgStr) {
    Get-CmnArgs -ArgList $ArgList -ArgSep ' ' -ArgEnter '/' -ValueSep ' ' -ArgStr $ArgStr
}

function Get-CmnArgsPosix($ArgList, $ArgStr) {
    Get-CmnArgs -ArgList $ArgList -ArgSep ' ' -ArgEnter '-' -ValueSep ' ' -ArgStr $ArgStr
}

function Get-CmnArgsGNU($ArgList, $ArgStr) {
    Get-AuxArgs -ArgList $ArgList -ArgSep ' ' -ArgEnter '--' -ValueSep '=' -ArgStr $ArgStr
}

function Add-CmnArgValue($ArgStr, $ArgValue) {
    Add-CmnString -Str $ArgStr -Add (Add-CmnArgValueQuotes -Value $ArgValue -Quote '"') -Sep ' '
}

function Add-CmnArgValueQuotes([string]$Value, $Quote = '"') {
    if ((-not ($Value.StartsWith($Quote) -and $Value.EndsWith($Quote))) -and ($Value -match '[\s;.,-]')) {
        $Value = $Quote + $Value + $Quote
    }
    $Value
}


####
# AUXILIARY FUNC
####

function Get-AuxArgs {
    param(
        $ArgList,
        [Parameter(Mandatory = $true)]
        $ArgSep,
        [Parameter(Mandatory = $true)]
        $ArgEnter,
        [Parameter(Mandatory = $true)]
        $ValueSep,
        $ArgStr = ''
    )
    foreach ($ArgKey in $ArgList.Keys) {
        $ArgStr = Add-AuxArg -ArgStr $ArgStr -Name $ArgKey -Value ($ArgList.$ArgKey) -ArgSep $ArgSep -ArgEnter $ArgEnter -ValueSep $ValueSep
    }
    $ArgStr
}

function Add-AuxArg {
    param (
        $ArgStr,
        $Name,
        $Value,
        $DefaultValue,
        [Parameter(Mandatory = $true)]
        $ArgSep,
        $ArgEnter,
        $ValueSep
    )
    
    if ($Value -eq $null) {$Value = $DefaultValue}
    if ($Value -eq $null) {return $ArgStr}
    if ($Value -eq '') {return $ArgStr}

    $Name = $Name.Replace('_', '-')

    $CurArg = ''
    if (($Value -is [bool]) -or ($Value -is [switch]) -or ($Value -eq $true) -or ($Value -eq $false)) {
        if ($Value) {
            $CurArg = $ArgEnter + $Name
        }
    }
    elseif ($Value -is [System.Array]) {
        foreach ($ArrayValueItem in $Value) {
            $CurArg = Add-AuxArg -ArgStr $CurArg -Name $Name -Value $ArrayValueItem -DefaultValue $DefaultValue -ArgSep $ArgSep -ArgEnter $ArgEnter -ValueSep $ValueSep
        }
    }
    else {
        $CurArg = $ArgEnter + $Name + $ValueSep + (Add-CmnArgValueQuotes -Value $Value -Quote '"')
    }

    Add-CmnString -Str $ArgStr -Add $CurArg -Sep $ArgSep
} 

Export-ModuleMember -Function '*-Cmn*'
