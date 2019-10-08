Import-Module ..\modules\1c-module.ps1 -Force

$ReleaseNo = '-'

$IssuePrefix = 'YL'
$IssuePattern = $IssuePrefix + '-\d+'

$Issues = $Issues.Trim().Split("`n")

$Conn = Get-1CConn -V8 '8.3.14.1565' -File 'D:\work\bases\update_by_cr\base2-fromdev'  -CRPath 'D:\work\bases\update_by_cr\cr-dev' -CRUsr 'fromdev'
$Log = Get-1CLog -Dir ($PSScriptRoot + '\logs')

$RepData = Parce-1CCRReportFromMXL -TXTFile 'D:\rep.txt'
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

    $IssuesString = [String]::Join($Issues, ',')

    $Lable = $ReleaseNo + ' ' + $IssuesString

    Invoke-1CCRSetLable -Conn $Conn -v $Ver.Version -Lable $Lable -Log $Log

}
