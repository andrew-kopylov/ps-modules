Import-Module ftp-module -Force

$ScriptItem = $PSCommandPath | Get-Item 

# Read script config parameters
$ScriptConfig = Get-Content -Path ($ScriptItem.DirectoryName + '\config\' + $ScriptItem.BaseName + '.json') -Raw | ConvertFrom-Json
$FtpConfig = Get-Content -Path ($ScriptItem.DirectoryName + '\config\ftp.json') -Raw | ConvertFrom-Json

$LogsLocalDir = $ScriptConfig.logsArchiveDir
$LogsFtpDir = Add-FtpUrlPath -Url $FtpConfig.rootPath -SubUrl $ScriptConfig.path
$Conn = Get-FtpConn -Srv $FtpConfig.srv -Usr $FtpConfig.usr -Pwd $FtpConfig.pwd -RootPath $LogsFtpDir

$ScriptDataFile = $ScriptItem.DirectoryName + '\' + $ScriptItem.BaseName + '-Data.json'
if (Test-Path -Path $ScriptDataFile) {
    $ScriptData = Get-Content -Path $ScriptDataFile | ConvertFrom-Json
}
else {
    $ScriptData = @{lastLogName = ""}
}
$LastLogName = $ScriptData.lastLogName

$LogItems = Get-ChildItem -Path $LogsLocalDir -File | Where-Object -FilterScript {$_.BaseName -gt $LastLogName}
foreach ($Item in $LogItems) {
    $FtpItem = Send-FtpFile -Conn $Conn -LocalPath $Item.FullName
    if ($FtpItem -ne $null) {
        $LastLogName = $Item.BaseName
        # Record script data
        $ScriptData.lastLogName = $LastLogName
        Set-Content -Path $ScriptDataFile -Value ($ScriptData | ConvertTo-Json) 
    }
    else {
        break
    }
}

