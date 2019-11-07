Import-Module 1c-module -Force

$WinUsr = [System.Security.Principal.WindowsPrincipal]([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $Winusr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath 'powershell' -ArgumentList ('-f "' + $PSCommandPath + '"') -Verb RunAs
    break
}

# Current Powershell command file
$PSCmdFile = Get-Item -Path $PSCommandPath

#Config
$ConfigDir = $PSCmdFile.DirectoryName + '\config'
$ConfigData = Get-Content -Path ($ConfigDir + '\config.json') | ConvertFrom-Json 

Register-1CComConnector -V8 $ConfigData.V8

$ComConnector = Get-1CComConnector -V8 $ConfigData.V8
if ($ComConnector -ne $null) {
    ('OK - ' + $ConfigData.V8) | Out-Host 
}
else {
    'ERROR' | Out-Host
}

Start-Sleep -Seconds 1
