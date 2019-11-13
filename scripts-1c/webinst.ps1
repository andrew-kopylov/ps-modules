Import-Module 1c-module -Force

$WinUsr = [System.Security.Principal.WindowsPrincipal]([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $Winusr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath 'powershell' -ArgumentList ('-f "' + $PSCommandPath + '"') -Verb RunAs
    break
}

$WebPath = 'baseweb'
$WsDir = 'basedir'

$CmdFile = Add-1CPath -Path $PSScriptRoot -AddPath webinst.cmd
$VrdFile = Add-1CPath -Path $PSScriptRoot -AddPath default.vrd
if (-not (Test-Path -Path $VrdFile)) {
    $VrdFile = $null
}

$Conn = Get-1CConn -V8 '8.3.14.1694' -Srvr 'servername' -Ref 'basename' -Usr 'api' -Pwd ''

$Result = Invoke-1CWebInst -Conn $Conn -Command publish -Ws iis -WsPath $WebPath -Dir $WsDir -Descriptor $VrdFile
$Result

$Cmd = '"' + $Result.WebInst + '" ' + $Result.ArgumentList

$Cmd | Out-File -FilePath $CmdFile -Encoding ascii
'pause' | Out-File -FilePath $CmdFile -Append -Encoding ascii


