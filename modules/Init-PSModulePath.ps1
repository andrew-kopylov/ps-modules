
$WinUsr = [System.Security.Principal.WindowsPrincipal]([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $Winusr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath 'powershell' -ArgumentList ('-f "' + $PSCommandPath + '"') -Verb RunAs
    return
}

[String]$PSModulePath = [System.Environment]::GetEnvironmentVariable("PSModulePath")
if (-not $PSModulePath.ToUpper().Contains($PSScriptRoot.ToUpper())) {
    $PSModulePath += (';' + $PSScriptRoot)
    [System.Environment]::SetEnvironmentVariable("PSModulePath", $PSModulePath, [System.EnvironmentVariableTarget]::Machine)
    'Done' | Out-Host
}
else {
    'PSMOdulePath already is settled' | Out-Host
}

Start-Sleep -Seconds 10