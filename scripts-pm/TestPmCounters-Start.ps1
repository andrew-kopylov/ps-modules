$StartScriptPath = $PSScriptRoot + '\TestPmCounters-Exec.ps1'
$ArgumentList = '-f "' + $StartScriptPath + '"'
$Process = Start-Process -FilePath 'powershell' -ArgumentList $ArgumentList
$Process.ExitCode


