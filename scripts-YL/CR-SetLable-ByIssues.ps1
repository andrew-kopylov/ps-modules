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
$IssueListFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-IssueList.txt'
$Issues =  Get-Content -Path $IssueListFile

# Pring Issues
[String]::Join(',', $Issues)

$ReleaseNo = read-host -Prompt ('Номер релиза с задачами [R15]')
$ReleaseNoPattern = 'R\d+'
if ($ReleaseNo -notmatch $ReleaseNoPattern) {
    'Неправильный формат номера релиза.'
    break
}

$DoSetLable = read-host -Prompt ('Устанавливать метки (y/n)')
$DoSetLable = ($DoSetLable -like 'y')
if ($DoSetLable) {
    'Будет выполнена установка меток'
}
else {
    'Обработка без установки меток'

}

$IssuePrefix = 'YL'

$RepData = Parce-1CCRReportFromMXL -TXTFile $RepFile
$RepVer = $RepData.Versions

$Objects = @()

foreach ($IssueNo in $Issues) {

    $IssueNo = $IssueNo.Trim()

    if ([String]::IsNullOrEmpty($IssueNo)) {continue}

    $FindedVer = $RepVer | Where-Object -FilterScript {$_.Comment -match $IssueNo}
 
    $VerNo = @()

    foreach ($Ver in $FindedVer) {
        $Lable = $ReleaseNo + ' ' + $IssueNo
        $CurVerNo = $Ver.Version.Trim()
        $VerNo += $CurVerNo
        foreach ($ObjectName in $Ver.Changed) {
            $Objects += $ObjectName
        }
        foreach ($ObjectName in $Ver.Added) {
            $Objects += $ObjectName
        }
        if ($DoSetLable) {
            Invoke-1CCRSetLable -Conn $Conn -v $CurVerNo -Lable $Lable -Log $Log
        }
    }

    $IssueNo
    if ($VerNo.Count -gt 0) {
        [String]::Join(',', $VerNo)
    }
    else {
        'No commits'
    }

}

$Objects | Select-Object -Unique
