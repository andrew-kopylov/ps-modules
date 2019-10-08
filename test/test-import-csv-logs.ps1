$mondata = Import-Csv -Delimiter ',' -Path 'C:\PerfLogs\Admin\HourAvgMonitor\RDV-KAA_20190920-000001\RDV-KAA_HourAvgMonitor1909201206.csv' -Encoding Default

$mondata.GetType()

$data = @()

foreach ($monelement in $mondata) {

    $element = @{}

    $value = $monelement.'\\RDV-KAA\Физический диск(1 C:)\Обращений записи на диск/с'
    $element.diskiops = [double]$value

    $data += $element

}

$avgdata = $data | Measure-Object -Property 'diskiops' -Average
$avgdata
