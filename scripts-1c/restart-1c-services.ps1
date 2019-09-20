# Restart 1C-Services

$ModulePath = $PSScriptRoot + "\modules\1c-module.ps1"
Import-Module $ModulePath -Force

# Current Powershell command file
$PSCmdFile = Get-Item -Path $PSCommandPath

# Log
$Log = Get-1CLog -Dir ($PSCmdFile.DirectoryName + '\logs') -Name $PSCmdFile.BaseName

# Restart All 1C-services
Restart-1CService -Log $Log
