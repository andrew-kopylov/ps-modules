Import-Module D:\git\ps-modules\modules\1c-module.ps1 -Force


$Conn = Get-1CConn -V8 '8.3.14.1565' -Srvr 'rdv-kaa:4541' -Ref 'on-postgre' -Usr 'web' -Pwd '123456'
Get-1CBaseConnString -Conn $Conn

Invoke-1CWebInst -Conn $Conn -Command publish -Ws iis -WsDir 'on-postgre-web' -Dir 'C:\inetpub\wwwroot\on-postgre-web'