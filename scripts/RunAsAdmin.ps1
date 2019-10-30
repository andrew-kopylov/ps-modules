
$WinUsr = [System.Security.Principal.WindowsPrincipal]([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $Winusr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    ((Get-Date).ToString() + ' Run as admin') | Out-File -FilePath 'd:\test-runas-out.txt' -Append
    Start-Process -FilePath 'powershell' -ArgumentList ('-f "' + $PSCommandPath + '"') -Verb RunAs
    break
}

((Get-Date).ToString() + ' Done as admin') | Out-File -FilePath 'd:\test-runas-out.txt' -Append

