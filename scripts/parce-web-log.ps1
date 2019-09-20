$logfile = 'C:\inetpub\logs\LogFiles\W3SVC1\u_ex190911.log'

# Pattern
$Pattern = @()
$Pattern += '(?<date>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})'
$Pattern += '\s+'
$Pattern += '(?<ip>\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3})'
$Pattern += '\s+'
$Pattern += '(?<method>\w+)'
$Pattern += '\s+'
$Pattern += '(?<url>[\/|\w]+)'
$Pattern += '\s+-\s+'
$Pattern += '(?<port>\d+)'
$Pattern += '\s+-\s+'
$Pattern += '(?<r_ip>\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3})'
$Pattern += '\s+'
$Pattern += '(?<client>.*?)'
$Pattern += '\s+-\s+'
$Pattern += '(?<result>\d+)'
$Pattern += '(?:\s+\d+){3}$'

$Pattern = [string]::Concat($Pattern)
$Pattern

foreach ($line in [System.IO.File]::ReadLines($logfile)) {
    if ($line -match $Pattern) {
        if ($Matches.result -eq '406') {
            $line
        }
    }
}



