﻿Import-Module 1c-module -Force

$WinUsr = [System.Security.Principal.WindowsPrincipal]([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $Winusr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath 'powershell' -ArgumentList ('-f "' + $PSCommandPath + '"') -Verb RunAs
    break
}

$ConfigFile = Add-1CPath -Path $PSScriptRoot -AddPath config, config.json
$Config = Get-Content -Path $ConfigFile | ConvertFrom-Json 

$Ref = Read-Host -Prompt 'Введите имя базы для публикации (ver ' + $Config.v8 + ', server ' + $Config.srvr ')'

$WebPath = $Ref.Replace('_', '-')
$Conn = Get-1CConn -V8 $Config.v8 -Srvr $Config.srvr -Ref $Ref

$CmdFile = Add-1CPath -Path $PSScriptRoot -AddPath webinst.cmd
$VrdFile = Add-1CPath -Path $PSScriptRoot -AddPath default.vrd
if (-not (Test-Path -Path $VrdFile)) {
    $VrdFile = $null
}

$Result = Invoke-1CWebInst -Conn $Conn -Command publish -Ws iis -WsPath $WebPath -Descriptor $VrdFile
$Result

$Cmd = '"' + $Result.WebInst + '" ' + $Result.ArgumentList

$Cmd | Out-File -FilePath $CmdFile -Encoding ascii
'pause' | Out-File -FilePath $CmdFile -Append -Encoding ascii

Start-Sleep -Seconds 5