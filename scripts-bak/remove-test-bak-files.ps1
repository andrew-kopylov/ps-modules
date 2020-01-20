Import-Module backup-module -Force
Import-Module ftp-module -Force
Import-Module log-module -Force

$Srv = 'localhost'
$RootPath = '/test'
$Usr = 'usr'
$Pwd = 'pwd'

$FtpConn = Get-FtpConn -Srv $Srv -Usr $Usr -Pwd $Pwd -RootPath $RootPath

$BakPolicy = Get-BakPolicy -DatePattern 'yyyyMMdd' -Prefix 'testbak-' -Postfix '.backup' -Daily 20 -Weekly 5 -Monthly 2 -Annual 2

$Log = New-Log -ScriptPath $PSCommandPath

Remove-BakFiles -BakPolicy $BakPolicy -Path baktest3 -FtpConn $FtpConn -Log $Log

Start-Sleep -Seconds 10
