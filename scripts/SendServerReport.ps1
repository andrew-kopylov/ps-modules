
$ProblemDescr = $Args[0]
$WhoAmI = 'Yandex.Lavka Production 1C-server'


$Volume = Get-WmiObject -Class win32_volume | Where-Object -FilterScript {$_.DriveLetter -eq 'C:'} | Select-Object -First 1
[math]::Round($Volume.Capacity / 1GB, 1)
[math]::Round($Volume.FreeSpace / 1GB, 1)



$smtp = New-Object System.Net.Mail.SmtpClient('smtp.mail.ru')
$smtp.Credentials = New-Object System.Net.NetworkCredential('mr.test.testov.91@mail.ru', 'w)0LKh5ibKG%')
$smtp.EnableSsl = $true

$msg = New-Object System.Net.Mail.MailMessage
$msg.From = 'mr.test.testov.91@mail.ru'
$msg.To.Add('aakopylov@rdv-it.ru')
$msg.Subject = $WhoAmI + ': ' + $ProblemDescr
$msg.Body = 'b'

$smtp.send($msg)
