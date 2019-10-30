Import-Module c:\scripts\modules\1c-module.ps1 -Force

# Current Powershell command file
$PSCmdFile = Get-Item -Path $PSCommandPath

#Config
$ConfigDir = $PSCmdFile.DirectoryName + '\config'
$ConfigData = Get-Content -Path ($ConfigDir + '\conf.json') | ConvertFrom-Json 

$IssuePrefix = $ConfigData.jiraIssuePrefix;

# Log
$Log = Get-1CLog -Dir ($PSCmdFile.DirectoryName + '\logs') -Name $PSCmdFile.BaseName

#$Ref = 'yl_ut_akopylov'
$Srvr = $ConfigData.Ref
$Ref = read-host -Prompt ('База разработки на сервере ' + $Srvr + ' (your-ib-name)')

#$CRUsr = 'akopylov'
$CRUsr = read-host -Prompt ('Имя пользователя хранилища (cr-usr-name)')

$SecureStr = read-host -Prompt ('Пароль пользователя ' + $CRUsr) -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureStr)
$Pass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$Conn = Get-1CConn -V8 $ConfigData.v8 -Srvr $Srvr -Ref $Ref -Usr $ConfigData.updaterUsr -Pwd $ConfigData.updaterPwd -CRPath $ConfigData.crpath -CRUsr $CRUsr -CRPwd $Pass

$RepFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Repository.txt'
$IssueListFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-IssueList.txt'
$OutFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Out.txt'

$Issues =  Get-Content -Path $IssueListFile

# Pring Issues
[String]::Join(',', $Issues)

$ReleaseNo = read-host -Prompt ('Номер релиза с задачами [R15]')
$ReleaseNoPattern = 'R\d+'
if ($ReleaseNo -notmatch $ReleaseNoPattern) {
    'Неправильный формат номера релиза.'
    break
}

# Clear file
(Get-Date).ToString() | Out-File -FilePath $OutFile 

$DoSetLabel = read-host -Prompt ('Устанавливать метки (y/n)')
$DoSetLabel = ($DoSetLabel -like 'y')
if ($DoSetLabel) {
    'Будет выполнена установка меток'
}
else {
    'Обработка без установки меток'

}

$DataFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Data.json'
$ProcessData = Get-Content -Path $DataFile | ConvertFrom-Json

$DoneBeforeCRVersion = $ProcessData.doneBeforeCRVersion
Invoke-1CCRReportTXT -Conn $Conn -ReportFile $RepFile -NBegin $DoneBeforeCRVersion -Log $Log

$RepData = Parce-1CCRReportFromMXL -TXTFile $RepFile
$RepVer = $RepData.Versions

$Objects = @()
$IssueObjects = @() # []@{Object; Issue}
$VersionObjects = @() # []@(Object; Version}

foreach ($IssueNo in $Issues) {

    $IssueNo = $IssueNo.Trim()

    if ([String]::IsNullOrEmpty($IssueNo)) {continue}

    $FindedVer = $RepVer | Where-Object -FilterScript {$_.Comment -match $IssueNo}
 
    $VerNo = @()

    foreach ($Ver in $FindedVer) {
        $Label = $ReleaseNo + ' ' + $IssueNo
        $CurVerNo = $Ver.Version.Trim()
        $VerNo += $CurVerNo
        foreach ($ObjectName in $Ver.Changed) {
            $Objects += $ObjectName
            $IssueObjects += @{Object = $ObjectName; Issue = $IssueNo}
            $VersionObjects += @{Object = $ObjectName; Version = $CurVerNo}
        }
        foreach ($ObjectName in $Ver.Added) {
            $Objects += $ObjectName
            $IssueObjects += @{Object = $ObjectName; Issue = $IssueNo}
            $VersionObjects += @{Object = $ObjectName; Version = $CurVerNo}
        }
        if ($DoSetLabel) {
            Invoke-1CCRSetLabel -Conn $Conn -v $CurVerNo -Label $Label -Log $Log
        }
    }

    $IssueNo | Out-File -FilePath $OutFile -Append
    if ($VerNo.Count -gt 0) {
        [String]::Join(', ', $VerNo) | Out-File -FilePath $OutFile -Append
    }
    else {
        'No commits' | Out-File -FilePath $OutFile -Append
    }

}

$Objects = $Objects | Select-Object -Unique | Sort-Object

# Ouput Objects & Issues changes objects.
foreach ($Object in $Objects) {
    
    # Output object name
    $Object | Out-File -FilePath $OutFile -Append

    # Object issues
    $FindedIssues = @()
    $IssueObjects |  Where-Object -FilterScript {$_.Object -eq $Object} | % {$FindedIssues += $_.Issue}
    $FindedIssues  = $FindedIssues | Select-Object -Unique | Sort-Object

    # Output object issues
    if ($FindedIssues.Count -gt 0) {
        [String]::Join(', ', $FindedIssues) | Out-File -FilePath $OutFile -Append
    }

    # Object versions
    $FindedVersions = @()
    $VersionObjects |  Where-Object -FilterScript {$_.Object -eq $Object} | % {$FindedVersions += $_.Version}
    $FindedVersions  = $FindedVersions | Select-Object -Unique | Sort-Object

    # Output object versions
    if ($FindedVersions.Count -gt 0) {
        [String]::Join(', ', $FindedVersions) | Out-File -FilePath $OutFile -Append
    }

}
