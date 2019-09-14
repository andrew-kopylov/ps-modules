# Основные параметры.
$FileDir = "E:\dt\siti_erp_lastprod_20190412"

# Доп. параметры.
$CurDateStr = Get-Date -Format "yyyyMMdd_hhmmss"
$HashFileName = "hash_" + $CurDateStr + ".txt"
$HashFile = $FileDir + "\" + $HashFileName


function Out-Text ($File, $Text) {
    $Text | Out-File -FilePath $File -Append 
}


$filelist = Get-ChildItem -Path $filedir
foreach ($file in $filelist) {
    $hash = Get-FileHash -Path $file.FullName
    $LogString = $file.Name + " - " + $hash.Hash
    Out-Text -File $HashFile -Text $LogString
}