
$BackupDir = "D:\to_archive"
$KeepDaysDevBases = 1
$KeepDaysTechBases = 10

$TechBases = @()
$TechBases += 'erp-crm-model'
$TechBases += 'erp-crm-test'
$TechBases += 'erp-crm-preprod'

$BakDirs = Get-ChildItem -Path $backupdir -Directory

foreach ($Dir in $BakDirs) {

    if ($Dir.BaseName -in $TechBases) {
        $KeepDays = $KeepDaysTechBases
    }
    else {
        $KeepDays = $KeepDaysDevBases
    }
    $DeleteDate = (Get-Date).AddDays(-$KeepDays-1)

    $AllBakFiles = Get-ChildItem -Path $Dir.FullName -Filter *.bak
    $FilesToDelete = $AllBakFiles | Where-Object -FilterScript {$_.LastWriteTime -lt $DeleteDate}

    $AllBakFilesCount = ([object[]]$AllBakFiles).Count
    $FilesToDeleteCount = ([object[]]$FilesToDelete).Count
    if ($AllBakFilesCount -gt $FilesToDeleteCount) {
        $FilesToDelete | % {Remove-Item -Path $_.FullName}
    }
}

