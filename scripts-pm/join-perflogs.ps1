Import-Module perfmon-module -Force

$BinFiles = Get-ChildItem -Path $PSScriptRoot -Filter '*.blg' -Recurse -Name
Invoke-PmRelogBinFiles -InputFiles $BinFiles -OutPath 'full.blg' -WorkDir $PSScriptRoot -RecordsInterval 15