Import-Module 1c-module -Force

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

# Update config from CR
Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'Update cfg from repository'
$UpdateCfgResult = Invoke-1CCRUpdateCfg -Conn $Conn -Log $Log

if ($UpdateCfgResult.ProcessedObjects -gt 0) {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'Update IB database'
    $UpdateIBDbResult = Invoke-1CUpdateDBCfg -Conn $Conn -Dynamic -Log $Log
}

$RepFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Repository.txt'
$DataFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Data.json'

$ProcessData = Get-Content -Path $DataFile | ConvertFrom-Json
$LastCRVersion = $ProcessData.lastCRVersion

Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'UploadCRReport' -LogText ('Last commit version is ' + $LastCRVersion)

# Upload MXL CR Report.
Invoke-1CCRReportTXT -Conn $Conn -ReportFile $RepFile -NBegin ($LastCRVersion + 1) -Log $Log

$IssuePattern = $IssuePrefix + '-\d+'

$RepData = ConvertFrom-1CCRReport -TXTFile $RepFile -FileType ConvertedFromMXL
if ($RepData -eq $null) {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'ParceCRReport' -LogText ('Error: data is null')
    break
}

$RepVer = $RepData.Versions
if ($RepVer.Count -eq 0) {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'ParceCRReport' -LogText ('No new versions')
    break
}

$IssuePattern = '(?<issueno>' + ([String]$IssuePrefix).ToUpper() + '-(?<issuenumb>\d+))'

foreach ($Ver in $RepVer) {

    $Comment = [String]$Ver.Comment

    if ([String]::IsNullOrEmpty($Comment)) {continue}

    $VerIssues = @()
    $VerIssuesNumb = @()

    $Comment = $Comment.ToUpper()
    While ($Comment -match $IssuePattern) {
       $VerIssues += $Matches.issueno
       $VerIssuesNumb += $Matches.issuenumb
       $ReplacePattern = '(\W|^)(' + $Matches.issueno + ')(\D|$)'
       $Comment = ($Comment -replace $ReplacePattern, '\.')
    }

    if ($VerIssues.Count -eq 0) {continue}

    $IssuesString = $IssuePrefix + '-' + [String]::Join(',', $VerIssuesNumb)

    $Label = $ReleaseNo + ' ' + $IssuesString

    Invoke-1CCRSetLabel -Conn $Conn -v $Ver.Version -Label $Label -Log $Log

    $LastCRVersion = [int]$Ver.Version

}

$ProcessData.lastCRVersion = $LastCRVersion

# Record script data
Set-Content -Path $DataFile -Value ($ProcessData | ConvertTo-Json) 
