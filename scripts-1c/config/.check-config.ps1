
$ConfgDir = [System.IO.Path]::GetDirectoryName($PSCommandPath)

$CheckFile = $ConfgDir + '\.check-config.txt'
'Check:' | Out-File -FilePath $CheckFile

$IsError = 0

 foreach ($ConfigFile in (Get-ChildItem -Path $ConfgDir -Filter '*.json')) {
    try {
        $ConfigData = Get-Content -Path $ConfigFile.FullName | ConvertFrom-Json
        $Res = 'ok'
    } 
    catch {
        $Res = 'ERROR: ' + $_
        $IsError = 1
    }
    ($ConfigFile.Name + ': ' + $Res) | Out-File -FilePath $CheckFile -Append

}

if ($IsError) {
	'Is errors in config files. See: ' + $CheckFile
    sleep -Seconds 5
}
else {
    'OK'
    sleep -Seconds 1
}

$IsError