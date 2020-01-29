
$WinUsr = [System.Security.Principal.WindowsPrincipal]([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $Winusr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath 'powershell' -ArgumentList ('-f "' + $PSCommandPath + '"') -Verb RunAs
    break
}

# Init clusters from config files.
& "$PSScriptRoot\ctl.ps1" init-clusters

Start-Sleep -Seconds 5