Import-Module pg-module -Force

$Conn1 = Get-PgConn -Port 5433 -DbName 'postgres'
$Conn2 = Get-PgConn -Port 5434 -DbName 'postgres'
$Conn3 = Get-PgConn -Port 5435 -DbName 'postgres'

#$BackupPath = 'D:\pgdata\backups\test3'
#Invoke-PgBasebackup -Conn $Conn -BackupPath $BackupPath -Format tar -XLogMethod fetch

#Get-PgDatabases -Conn $Conn


Invoke-PgTerminateBackend -Conn $Conn2 -DbName 'test5434-base1'