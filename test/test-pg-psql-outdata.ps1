
$OutDir = $env:TEMP 
$OutId = (Get-Date).ToString('yyMMddHHmmss-ffff')

$OutFile = $OutDir + '\psql-out-' + $OutId + '.txt'
$ErrFile = $OutDir + '\psql-err-' + $OutId + '.txt'

$Process = Start-Process -FilePath 'psql' -ArgumentList '-c "select oid, datname from pg_database"' -RedirectStandardOutput $OutFile -RedirectStandardError $ErrFile -NoNewWindow -Wait -PassThru
$Process.ExitCode

'out:'
Get-Content -Path $OutFile -Encoding UTF8

'err:'
Get-Content -Path $ErrFile -Encoding UTF8

