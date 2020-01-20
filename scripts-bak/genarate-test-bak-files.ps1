# parameters

$TestBakDir = 'D:\baktest'

$StartDate = [datetime]::new(2017, 1, 1)
$EndDate = Get-Date

$BakDays = 1
$BakCountInDay = 1

# implementation

$CurDate = $StartDate
$EndDate = $EndDate + (New-TimeSpan -Days $BakDays)

while ($CurDate -le $EndDate) {
    $BakName = 'testbak-' + $CurDate.ToString('yyyyMMdd-ddd')
    for ($i = 1; $i -le $BakCountInDay; $i++) {
        $FullName = $TestBakDir + '\' + $BakName + '-' + $i + '.backup'
        'backup' | Out-File -FilePath $FullName
    }
    $CurDate = $CurDate + (New-TimeSpan -Days $BakDays)
}
