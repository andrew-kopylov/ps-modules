
$Path = 'D:\git\ps-modules\test'
$MatchValue = '1c-module'
$NewValue = '1c'

$Items = Get-ChildItem -Path $Path | Where-Object -FilterScript {$_.BaseName -match $MatchValue}


foreach ($Item in $Items) {
    $NewBaseName = ($Item.basename -replace $MatchValue, $NewValue)
    $NewFullName = $Item.DirectoryName + '\' + $NewBaseName + $Item.Extension
    Move-Item -Path $Item.FullName -Destination $NewFullName
}