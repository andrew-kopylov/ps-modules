﻿Import-Module D:\git\ps-modules\modules\ftp-module.ps1 -Force

$ftpurl = 'ftp://localhost/test'
$ftpdir = '/subdir'
$ftpusr = 'ftpusr'
$ftppwd = 'tpwd1234'



$ftpurl1 = Add-FtpUrlPath -Url $ftpurl -SubUrl $ftpdir
$ftpurl1
$ftpurlfile = Add-FtpUrlPath -Url $ftpurl1 -SubUrl 'test.txt'

Remove-FtpItem -Url $ftpurlfile -Usr $ftpusr -Pwd $ftppwd
#Download-FtpFile -Url $ftpurlfile -Usr $ftpusr -Pwd $ftppwd -LocalPath 'd:\rem-fromftp1.txt'
#Upload-FtpFile -Url $ftpurlfile -Usr $ftpusr -Pwd $ftppwd -LocalPath 'd:\rem.txt'

#Remove-FtpItem -Url $ftpurl1 -Usr $ftpusr -Pwd $ftppwd


#$Result = New-FtpDirectory -Url $ftpurl1 -Usr $ftpusr -Pwd $ftppwd

break

$Items = Get-FtpChildItems -Url $ftpurl1 -Usr $ftpusr -Pwd $ftppwd
$Items


