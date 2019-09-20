
$VolumeArray = Get-WmiObject -Class win32_volume | Where-Object -FilterScript {$_.DriveType -eq 3}


$Body = 'Server report'

$DriveState = $VolumeArray | Select-Object -Property DriveLetter, Capacity, Freespace

$Text = $Body | Out-String
$Text = $DriveState | Out-String

$Text


