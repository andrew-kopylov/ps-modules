Import-Module 1c-devops-module -Force

# Current Powershell command file
$PSCmdFile = Get-Item -Path $PSCommandPath
$ProcessName = $PSCmdFile.BaseName

#Config
$ConfigDir = $PSCmdFile.DirectoryName + '\config'
$Config = Get-Content -Path ($ConfigDir + '\config.json') | ConvertFrom-Json 
$ConfigUpdater = Get-Content -Path ($ConfigDir + '\updater.json') | ConvertFrom-Json

$ReleaseNo = '-'
$IssuePrefix = $Config.jiraIssuePrefix;

# Log
$Log = Get-1CLog -Dir ($PSCmdFile.DirectoryName + '\logs') -Name $PSCmdFile.BaseName
$DataDir = Add-CmnPath -Path $PSCmdFile.DirectoryName -AddPath $PSCmdFile.BaseName

Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'Start'

$Srvr = $Config.srvr

# Ref - base name
if (-not [String]::IsNullOrEmpty($ConfigUpdater.ref)) {
    $Ref = $ConfigUpdater.ref
} 
else {
    $Ref = read-host -Prompt ('База разработки на сервере ' + $Srvr + ' (your-ib-name)')
}

$Usr = $ConfigUpdater.usr
$Pwd = $ConfigUpdater.pwd
$CRPath = $Config.crpath

# CRUsr - repository user
if (-not [String]::IsNullOrEmpty($ConfigUpdater.crusr)) {
    $CRUsr = $ConfigUpdater.crusr
} 
else {
    $CRUsr = read-host -Prompt ('Имя пользователя хранилища (cr-usr-name)')
}

# CRUsr - repository pass
if ($ConfigUpdater.crpwd -ne $null) {
    $CRPwd = $ConfigUpdater.crpwd
} 
else {
    $SecureStr = read-host -Prompt ('Пароль пользователя ' + $CRUsr) -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureStr)
    $CRPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}

$Conn = Get-1CConn -V8 $Config.v8 -Srvr $Srvr -Ref $Ref -Usr $Usr -Pwd $Pwd -CRPath $CRPath -CRUsr $CRUsr -CRPwd $CRPwd

Invoke-1CDevSetRepositoryLabelByComment -Conn $Conn -DataDir $DataDir -ReleaseNo '-' -Log $Log
