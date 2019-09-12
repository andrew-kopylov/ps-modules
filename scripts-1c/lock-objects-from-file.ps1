# Update production configuration from production configuration repository.
$ModulePath = $PSScriptRoot + "\modules\1c-module.ps1"
Import-Module $ModulePath -Force

# Current Powershell command file
$PSCmdFile = Get-Item -Path $PSCommandPath

# Platform version
$V8 = Get-1CV8 -Ver '8.3.14.1630' # product

# Log
$Log = Get-1CLog -Dir ($PSCmdFile.DirectoryName + '\logs') -Name $PSCmdFile.BaseName

# Update prod config connection parameters.
$Conn = Get-1CConn -V8 $V8 -Srvr 'srv' -Ref 'base' -Usr 'user' -Pwd 'password' -CRPath 'tcp://srv/crname' -CRUsr 'crusr'

$CRLockObjectsFile = $PSCmdFile.DirectoryName + '\lock-objects.txt'
[string[]]$Objects = @()

# Read objects for locking.
$FileSystemObject = New-Object -ComObject Scripting.FileSystemObject
$FileStream = $FileSystemObject.OpenTextFile($CRLockObjectsFile, 1, $false, -2)
while (-not $FileStream.AtEndOfStream)  {$Objects += $FileStream.ReadLine()}

# Update from configuration repository.
$Result = Invoke-1CCRLock -Conn $Conn -Objects $Objects -includeChildObjectsAll -Log $Log 
