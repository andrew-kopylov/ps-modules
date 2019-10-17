#archive_mode = on
#archive_command = 'powershell -f d:\\pgdata\\archive-wal.ps1 -p %p -a d:\\pgdata\\archive-wal -c zip'
#archive_timeout = 60

Import-Module D:\git\ps-modules\modules\pg-module.ps1 -Force

#$args += '-p'
#$args += 'pg_wal\00000001000000010000005D'
#$args += '-a'
#$args += 'D:\pgdata\archive-wal'
#$args += '-d'
#$args += 'd:\pgdata\10.9'
#$args += '-c'
#$args += 'zip'

$HArgs = Get-PgPSArgs -ArgsArray $args

#$HArgs = @{
#    p = 'pg_wal\00000001000000010000005D';
#    a = 'D:\pgdata\archive';
#    d = 'D:\pgdata\10.9'
#    c = 'zip'
#}

if ([String]::IsNullOrEmpty($HArgs.p)) {
    throw 'Expected wal-file relative path parameter "p": "PowerShell -f archive-wal.ps1 -p walfile -d archivedir"'
}

if ([String]::IsNullOrEmpty($HArgs.a)) {
    throw 'Expected archive directory path parameter "d": "PowerShell -f archive-wal.ps1 -p walfile -d archivedir"'
}

# Relative wal-file path from data dir
$WalFileRel = $HArgs.p

# Archive directory for wal-files
$ArchDir = $HArgs.a

# Init LOG
if (-not [String]::IsNullOrEmpty($HArgs.l)) {
    $LogDir = $HArgs.l
}
else {
    $LogDir = Add-PgPath -Path $ArchDir -AddPath 'log'
}
$Log = Get-PgLog -Dir $LogDir -Name 'archive-wal'

# Data dir
if ([String]::IsNullOrEmpty($HArgs.d)) {
    $DataDir = (Get-Location).ToString()
}
else {
    $DataDir = $HArgs.d
}

$CompressZIP = ($HArgs.c -eq 'zip')

# Source and destination WAL-file
$WalFileFullName = Add-PgPath -Path $DataDir -AddPath $WalFileRel
$DataDirBaseName = Get-PgPathBaseName -Path $DataDir
$WalFileDest = Add-PgPath -Path $ArchDir -AddPath $DataDirBaseName
$WalFileDest = Add-PgPath -Path $WalFileDest -AddPath $WalFileRel

$WalFileDestDir = Get-PgPathDirectory -Path $WalFileDest
$WalFileBaseName = Get-PgPathBaseName -Path $WalFileDest
$WalFileBaseNameNew = (Get-Date).ToString('yyyyMMdd-HHmmss.') + $WalFileBaseName + '.wal'

$WalFileDest = Add-PgPath -Path $WalFileDestDir -AddPath $WalFileBaseNameNew

# Destination WAL-directory
$TestResult = Test-PgDir -Path $WalFileDestDir -CreateIfNotExist
if (-not $TestResult) {
    $ErrText = 'WAL-archive directory doesn''t exist: ' + $WalFileDestDir + '; data directory ' + $DataDir
    Out-PgLog -Log $Log -LogMark 'Error' -LogText $ErrText -InvokeThrow
}

if (-not (Test-Path -Path $WalFileFullName)) {
    $ErrText = 'Archived WAL-file doesn''t exist: ' + $WalFileFullName
    Out-PgLog -Log $Log -LogMark 'Error' -LogText $ErrText -InvokeThrow
}

# Check WAL-file existance.
if (Test-Path -Path $WalFileDest) {
    $ErrText = 'Archived WAL-file copy already exists: ' + $WalFileDest
    Out-PgLog -Log $Log -LogMark 'Error' -LogText $ErrText -InvokeThrow
}

# Copy WAL-file
Out-PgLog -Log $Log -LogMark 'begin' -LogText ('wal-file ' + $WalFileFullName + ' to ' + $WalFileDest)
Copy-Item -Path $WalFileFullName -Destination $WalFileDest -Force

# Check wal copy.
if (Test-Path -Path $WalFileDest) {
    Out-PgLog -Log $Log -LogMark 'end' -LogText ('wal-file archived successfully ' + $WalFileFullName)
}
else {
    $ErrText = 'WAL-file doesn''t exists after coping: ' + $WalFileFullName + ' to ' + $WalFileDest
    Out-PgLog -Log $Log -LogMark 'Error' -LogText $ErrText -InvokeThrow
}

# Compress wal
if ($CompressZIP) {
    $CompressDest = $WalFileDest + '.zip'
    Compress-Archive -Path $WalFileDest -DestinationPath $CompressDest -CompressionLevel Optimal
    if (Test-Path -Path $CompressDest) {
        Remove-Item -Path $WalFileDest
        Out-PgLog -Log $Log -LogMark 'Compress' -LogText ('To ' + $CompressDest)
    } 
    else {
        Out-PgLog -Log $Log -LogMark 'Compress' -LogText ('Error ' + $WalFileDest)
    }
}
