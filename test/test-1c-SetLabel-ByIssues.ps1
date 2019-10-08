Import-Module ..\modules\1c-module.ps1 -Force

$Release = '-'

$Issues = 
'
iss-1
iss-2
iss-3
iss-4
'

$Issues = $Issues.Trim().Split("`n")

$Conn = Get-1CConn -V8 '8.3.14.1565' -File 'D:\work\bases\update_by_cr\base2-fromdev'  -CRPath 'D:\work\bases\update_by_cr\cr-dev' -CRUsr 'fromdev'
$Log = Get-1CLog -Dir ($PSScriptRoot + '\logs')

$RepData = Parce-1CCRReportFromMXL -TXTFile 'D:\rep.txt'
$RepVer = $RepData.Versions

$RepVer

foreach ($Iss in $Issues) {

    $Iss = $Iss.Trim()

    if ([String]::IsNullOrEmpty($Iss)) {continue}

    $FindedVer = $RepVer | Where-Object -FilterScript {$_.Comment -match $Iss}
 
    foreach ($Ver in $FindedVer) {
        $Lable = $Release + ' ' + $Iss
        Invoke-1CCRSetLable -Conn $Conn -v $Ver.Version -Lable $Lable -Log $Log
    }

}
