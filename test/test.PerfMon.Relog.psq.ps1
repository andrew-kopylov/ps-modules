Import-Module 'D:\git\ps-modules\modules\perfmon-module.ps1' -Force

$srv = 'srvsql'
$day = 3
$month = 10

$Items = Get-ChildItem -Path ('d:\yl-20190930\' + $srv) -Filter '*.blg' -Recurse -File | Select-Object -Property FullName

$InputFiles = @()
foreach ($itm in $Items) {
    $InputFiles += $itm.FullName
}

$strday = $day.ToString()
if ($strday.Length -eq 1) {$strday = '0' + $strday}

$strmonth = $month.ToString()
if ($strmonth.Length -eq 1) {$strmonth = '0' + $strmonth}

$CntrsFile = 'D:\yl-20190930\' + $srv + '-counters.txt'
$OutputFile = 'D:\yl-20190930\' + $srv + '-' + $strday + '.' + $strmonth + '.2019-10h-14h.blg'
$Begin = [datetime]::new(2019, $month, $day, 10, 0, 0)
$End = [datetime]::new(2019, $month, $day, 15, 59, 59)


#Invoke-PmRelogCommand -InputFiles $InputFiles[0] -CountersListInInput -OutPath $CntrsFile

#Invoke-PmRelogCommand -InputFiles $InputFiles -InputCountersFile $CntrsFile -OutFormat BIN -OutPath $OutputFile -Begin $Begin -End $End -RecordsInterval 15
Invoke-PmRelogCommand -InputFiles $InputFiles -OutFormat BIN -OutPath $OutputFile -Begin $Begin -End $End 