Import-Module ($PSScriptRoot + "\modules\1c-module.ps1") -Force

$Conn = Get-1CConn -V8 '8.3.14.1565' -File 'D:\work\bases\git-test-GitKraken' -CRPath 'D:\test-cr-create\cr-dir\' -CRUsr 'Администратор'
$Log = Get-1CLog -Dir ($PSScriptRoot + '\logs')

Invoke-1CCRCreate -Conn $Conn -Log $Log

Invoke-1CCRAddUser -Conn $Conn -User 'NewUser' -Rights LockObjects -Log $Log
Invoke-1CCRAddUser -Conn $Conn -User 'admin' -Rights Administration -Log $Log 