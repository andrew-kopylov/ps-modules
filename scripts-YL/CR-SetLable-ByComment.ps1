Import-Module .\modules\1c-module.ps1

# Current Powershell command file
$PSCmdFile = Get-Item -Path $PSCommandPath

# Log
$Log = Get-1CLog -Dir ($PSCmdFile.DirectoryName + '\logs') -Name $PSCmdFile.BaseName

#$Ref = 'yl_ut_akopylov'
$Srvr = 'srv1c'
$Ref = read-host -Prompt ('База разработки на сервере ' + $Srvr + ' (yl_ut_akopylov)')

#$CRUsr = 'akopylov'
$CRUsr = read-host -Prompt ('Имя пользователя хранилища (akopylov)')

$SecureStr = read-host -Prompt ('Пароль пользователя ' + $CRUsr) -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureStr)
$Pass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$V8 = '8.3.14.1694'

$Conn = Get-1CConn -V8 $V8 -Srvr 'srv1c' -Ref $Ref -Usr 'cfg_updater' -Pwd 'HbK1#8Pq' -CRPath 'tcp://srv1c/yl_ut' -CRUsr $CRUsr -CRPwd $Pass

$RepFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Repository.txt'

$ReleaseNo = '-'

$IssuePrefix = 'YL'
$IssuePattern = $IssuePrefix + '-\d+'

$RepData = Parce-1CCRReportFromMXL -TXTFile $RepFile
$RepVer = $RepData.Versions

$IssuePrefix = 'YL'

$IssuePattern = '(?<no>' + $IssuePrefix + '-\d+)'

foreach ($Ver in $RepVer) {

    $Comment = $Ver.Comment

    if ([String]::IsNullOrEmpty($Comment)) {continue}

    $Issues = @()

    While ($Comment -match $IssuePattern) {
       $Issues += $Matches.no
       $ReplacePattern = '(\W|^)(' + $Matches.no + ')(\D|$)'
       $Comment = ($Comment -replace $ReplacePattern, '\.')
    }

    if ($Issues.Count -eq 0) {continue}

    $IssuesString = [String]::Join(',', $Issues)

    $Lable = $ReleaseNo + ' ' + $IssuesString

    Invoke-1CCRSetLable -Conn $Conn -v $Ver.Version -Lable $Lable -Log $Log

}
