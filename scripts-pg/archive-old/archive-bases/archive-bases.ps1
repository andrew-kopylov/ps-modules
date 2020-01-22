Import-Module pg-archive-module -Force
Import-Module 7z-module -Force

$PSScriptItem = Get-Item -Path $PSCommandPath

$Log = New-Log -ScriptPath $PSCommandPath

$ConfigDir = $PSScriptItem.DirectoryName + '\config'
$Clusters = Get-Content -Path ($ConfigDir + '\clusters.json') | ConvertFrom-Json
$Config = Get-Content -Path ($ConfigDir + '\config.json') | ConvertFrom-Json

Backup-PgaBases -Config $Config -Clusters $Clusters -Log $Log
