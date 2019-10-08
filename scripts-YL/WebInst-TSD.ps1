Import-Module c:\scripts\modules\1c-module.ps1 -Force

$WebPath = 'yl-ut-test-tsd-825156f484e44160a6f4c582bfd67cf9'
$Conn = Get-1CConn -V8 '8.3.14.1694' -Srvr 'srv1c' -Ref 'yl_ut_test' -Usr 'apiYaTsd' -Pwd 'UKBCi~o3WKb3'

Invoke-1CWebInst -Conn $Conn -Command publish -Ws iis -WsDir $WebPath -Dir 'C:\inetpub\wwwroot\yl-ut-test-tsd'