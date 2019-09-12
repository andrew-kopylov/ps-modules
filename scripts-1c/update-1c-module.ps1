# Update 1C-Module

$ModulePath = $PSScriptRoot + "\modules\1c-module.ps1"
Import-Module $ModulePath -Force

# Current Powershell command file
$PSCmdFile = Get-Item -Path $PSCommandPath

# Log
$Log = Get-1CLog -Dir ($PSCmdFile.DirectoryName + '\logs') -Name $PSCmdFile.BaseName

# Restart All 1C-services
Update-1CModule -Log $Log
