Import-Module pg-module -Force

$ScriptItem = Get-Item -Path $PSCommandPath

# Get config settings
$ScriptConfigFile = Add-PgPath -Path $ScriptItem.DirectoryName -AddPath config, ($ScriptItem.BaseName + '.json')
$ScriptConfig = Get-Content -Path $ScriptConfigFile | ConvertFrom-Json

if ($ScriptConfig.compress) {
    Import-Module 7z-module -Force
}

if (-not [String]::IsNullOrEmpty($ScriptConfig.log)) {
    $LogDir = $ScriptConfig.log
}
else {
    $LogDir = Add-PgPath -Path $ScriptItem.DirectoryName -AddPath logs
}

$Log = Get-PgLog -Dir $LogDir -Name 'archive-base'

$BackupName = 'basebackup-' + (Get-Date).ToString('yyyyMMdd-HHmmss')
$PgData = $ScriptConfig.archive + '\' + $BackupName

Out-PgLog -Log $Log -Mark 'Start' -Text $PgData

# Create backup
$Result = Invoke-PgBasebackup -PgData $PgData -Format tar -XLogMethod fetch 

if (-not [String]::IsNullOrEmpty($Result.Error)) {
    Out-PgLog -Log $Log -Mark 'Error' -Text $Return -InvokeThrow
}

if (-not (Test-Path -Path $PgData)) {
    Out-PgLog -Log $Log -Mark 'Error' -Text 'Doesn''t exist backup' -InvokeThrow
}

# Compress backup
if ($ScriptConfig.compress) {
    $CompressedPgData = $PgData + '.7z'
    Out-PgLog -Log $Log -Mark 'Compress' -Text $CompressedPgData
    $Result = Compress-7zArchive -Path $PgData -DestinationPath $CompressedPgData -CompressionTreads 1
    if (($Result.ExitCode -eq 0) -and (Test-Path -Path $CompressedPgData)) {
        Remove-Item -Path $PgData -Recurse -Force
    }
    else {
        Out-PgLog -Log $Log -Mark 'Error' -Text ('Compress error, exit code ' + $Result.ExitCode) -InvokeThrow
    }
}

Out-PgLog -Log $Log -Mark 'End' -Text 'OK'
