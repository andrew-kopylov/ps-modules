$Exceptions = '.git', 'config', 'modules', 'logs'
$Folders = Get-ChildItem -Path $PSScriptRoot -Directory | Where-Object -FilterScript {$_.BaseName -notin $Exceptions}
foreach ($Item in $Folders) {
    $ModulesPath = $Item.FullName + '\modules'
    if (Test-Path -Path $ModulesPath) {
        Remove-Item -Path $ModulesPath -Recurse -Force
    }
    New-Item -Path $ModulesPath -ItemType Junction -Value ($PSScriptRoot + '\modules')
}