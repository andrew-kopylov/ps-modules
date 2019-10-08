Import-Module ($PSScriptRoot + '\modules\1c-module.ps1') -Force

$Conn = Get-1CConn -V8 '8.3.14.1565' -File 'D:\work\bases\update_by_cr\base2-fromdev' -CRPath 'D:\work\bases\update_by_cr\cr-dev' -CRUsr 'fromdev'

$Log = Get-1CLog -Dir ($PSScriptRoot + '\logs')

Invoke-1CCRReport -Conn $Conn -ReportFile 'd:\test.crrep.mxl' -Log $Log

$ComConn = Get-1CComConnection -Conn $Conn

Convert-1CMXLtoTXT -ComConn $ComConn -MXLFile 'd:\test.crrep.mxl' -TXTFile 'd:\test.crrep.txt'

$Report = Parce-1CCRReport -TXTFile 'd:\test.crrep.txt'

foreach ($Ver in $Report.Versions) {
    $Ver.Version
    $Ver.Comment
}
