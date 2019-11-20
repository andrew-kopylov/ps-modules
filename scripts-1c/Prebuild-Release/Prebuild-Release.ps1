Import-Module 1c-module -Force

# Current Powershell command file
$PSCmdFile = Get-Item -Path $PSCommandPath
$ProcessName = $PSCmdFile.BaseName

$ScriptsRoot = $PSCmdFile.Directory.Parent.FullName
$ScriptBaseName = $PSCmdFile.BaseName

# Issue files
$IssueListFile =  Add-1CPath -Path $PSCmdFile.DirectoryName -AddPath ($ScriptBaseName + '-IssueList.txt')
$IssueListDoneFile = Add-1CPath -Path $PSCmdFile.DirectoryName -AddPath ($ScriptBaseName + '-IssueList-Done.txt')
$IssueListExceptFile = Add-1CPath -Path $PSCmdFile.DirectoryName -AddPath ($ScriptBaseName + '-IssueList-Except.txt')
$AddObjectsToLockFile = Add-1CPath -Path $PSCmdFile.DirectoryName -AddPath ($ScriptBaseName + '-ObjectsToLock.txt')

# Config
$ConfigDir = Add-1CPath -Path $ScriptsRoot -AddPath config
$Config = Get-Content -Path ($ConfigDir + '\config.json') | ConvertFrom-Json 
$ConfigUpdater = Get-Content -Path ($ConfigDir + '\updater.json') | ConvertFrom-Json
$ConfigPreprod = Get-Content -Path ($ConfigDir + '\preprod.json') | ConvertFrom-Json

# Repository files
$RepFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Repository.txt'
$InFileRepositoryJSON = '' # $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Repository.json'
$OutFileRepositoryJSON = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Repository-out.json'

# Configuration dump file
$OutFileDumpCfg = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-DumpCRCfg-out.cf'

$IssuePrefix = $Config.jiraIssuePrefix;

# Log
$Log = Get-1CLog -Dir ($PSCmdFile.DirectoryName + '\logs') -Name $PSCmdFile.BaseName

Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'Start'

$Srvr = $Config.srvr
# Ref - base name
if (-not [String]::IsNullOrEmpty($ConfigUpdater.ref)) {
    $Ref = $ConfigUpdater.ref
} 
else {
    $Ref = read-host -Prompt ('База разработки на сервере ' + $Srvr)
}

$Usr = $ConfigUpdater.usr
$Pwd = $ConfigUpdater.pwd
$CRPath = $Config.crpath

# CRUsr - repository user
if (-not [String]::IsNullOrEmpty($ConfigUpdater.crusr)) {
    $CRUsr = $ConfigUpdater.crusr
} 
else {
    $CRUsr = read-host -Prompt ('Имя пользователя хранилища')
}

# CRUsr - repository pass
if ($ConfigUpdater.crpwd -ne $null) {
    $CRPwd = $ConfigUpdater.crpwd
} 
else {
    $SecureStr = read-host -Prompt ('Пароль пользователя ' + $CRUsr) -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureStr)
    $CRPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}

$Conn = Get-1CConn -V8 $Config.v8 -Srvr $Srvr -Ref $Ref -Usr $Usr -Pwd $Pwd -CRPath $CRPath -CRUsr $CRUsr -CRPwd $CRPwd
$ConnPreprod =  Get-1CConn -V8 $Config.v8 -Srvr $Srvr -Ref $ConfigPreprod.Ref -Usr $ConfigPreprod.Usr -Pwd $ConfigPreprod.Pwd -CRPath $ConfigPreprod.crpath -CRUsr $ConfigPreprod.crusr -CRPwd $ConfigPreprod.crpwd

$Issues = @()
Get-Content -Path $IssueListFile | % {$Issues += $_.ToUpper().Trim()}

$DoneIssues = @()
Get-Content -Path $IssueListDoneFile | % {$DoneIssues += $_.ToUpper().Trim()}

$ExceptIssues = @()
Get-Content -Path $IssueListExceptFile | % {$ExceptIssues += $_.ToUpper().Trim()}


# Print Issues
Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Issues' -LogText ([String]::Join(',', $Issues))

$ReleaseNo = read-host -Prompt ('Номер релиза с задачами [R15]')
$ReleaseNoPattern = 'R\d+'
if ($ReleaseNo -notmatch $ReleaseNoPattern) {
    'Неправильный формат номера релиза.'
    break
}

# Out-files '-out-'
# -Info - description release issues with relations objects and commits
# -Autoupdate - list autoupdated objects
# -IssueList - release issue list

$OutFileBaseName = $PSCmdFile.BaseName + '-out-'
$OutFileSuffix = 'Release-' + $ReleaseNo + '-' + (Get-Date).ToString('yyMMddHHmm')

$OutFile =  $PSCmdFile.DirectoryName + '\' + $OutFileBaseName + $OutFileSuffix + '-Info.txt'
$OutFileIssueList = $PSCmdFile.DirectoryName + '\' + $OutFileBaseName + $OutFileSuffix + '-IssueList.txt'
$OutFileAutoObjects = $PSCmdFile.DirectoryName + '\' + $OutFileBaseName + $OutFileSuffix + '-Autoupdate.txt'
$OutFileChangedObjects = $PSCmdFile.DirectoryName + '\' + $OutFileBaseName + $OutFileSuffix + '-Changes.txt'

Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'out' -LogText $OutFile

# Move last out-files to archive
$OutFileAchiveDir = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Archive'
$OutFilesToAchiveList = Get-ChildItem -Path $PSCmdFile.DirectoryName -Filter ($OutFileBaseName + '*')
if (-not (Test-Path -Path $OutFileAchiveDir)) {New-Item -Path $OutFileAchiveDir -ItemType Directory -Force}
foreach ($OutFileToArchive in $OutFilesToAchiveList) {
    Move-Item -Path $OutFileToArchive.FullName -Destination ($OutFileAchiveDir + '\' + $OutFileToArchive.Name) -Force
}

# Copy IssueList file to Out.
Copy-Item -Path $IssueListFile -Destination $OutFileIssueList

# Init out-file
(Get-Date).ToString() | Out-File -FilePath $OutFile

# Question Set Labels
$DoSetLabel = read-host -Prompt ('Устанавливать метки? (y/n)')
$DoSetLabel = ($DoSetLabel -like 'y')
if ($DoSetLabel) {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'info' -LogText 'Установка меток'
}
else {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'info' -LogText 'Обработка без установки меток'
}

# Question Upload configuration
$DoUploadCfg = read-host -Prompt ('Выгрузить конфигурацию хранилища? (y/n)')
$DoUploadCfg = ($DoUploadCfg -like 'y')
if ($DoUploadCfg) {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'info' -LogText 'Будет выполнена выгрузка конфигурации'
}
else {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'info' -LogText 'Обработка без выгрузки текущей конфигурации'
}

# Question Lock objects in prod configuration
$DoLockPreprodObjects = read-host -Prompt ('Захватить измененные объекты в продуктовом хранилище? (y/n)')
$DoLockPreprodObjects = ($DoLockPreprodObjects -like 'y')
if ($DoLockPreprodObjects) {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'info' -LogText 'Будет выполнен захват измененных объектов в продуктовом хранилище'
}
else {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'info' -LogText 'Обработка без захвата изменных объектов в продуктовом хранилище'
}

$DataFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Data.json'
$ProcessData = Get-Content -Path $DataFile | ConvertFrom-Json
if ($ProcessData -eq $null) {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Error' -LogText ('Ошибка чтения файла данных скрипта: ' + $DataFile)
    return
}

if (Test-Path -Path $OutFileRepositoryJSON) {
    $DoUploadCRReport = read-host -Prompt ('Выгрузить отчет по версиям хранилища (y/n)')
    $DoUploadCRReport = ($DoUploadCRReport -like 'y')
}
else {
    $DoUploadCRReport = $true
}

if ($DoUploadCRReport) {

    $DoneBeforeCRVersion = $ProcessData.doneBeforeCRVersion
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'GetCRReport.Info' -LogText ('Получение отчета хранилища начиная с версии: ' + $DoneBeforeCRVersion)
    Invoke-1CCRReportTXT -Conn $Conn -ReportFile $RepFile -NBegin $DoneBeforeCRVersion -Log $Log | Out-Null

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'GetCRReport.Info' -LogText ('Парсинг отчета хранилища...')
    $RepData = ConvertFrom-1CCRReport -TXTFileFromMXL $RepFile
    $RepData | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutFileRepositoryJSON
}
else {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'GetCRReport' -LogText ('Загрузка отчета хранилища из файла: ' + $OutFileRepositoryJSON)
    $RepData = Get-Content -Path $OutFileRepositoryJSON | ConvertFrom-Json
}

if ($RepData -eq $null) {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'CRReport.Error' -LogText 'Repository report data is null'
    break
}

$RepVer = $RepData.Versions
if ($RepVer.Count -eq 0) {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'CRReport.Error' -LogText 'No any versions in repository report'
    break
}

Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Info' -LogText 'Формирование таблицы соответствия задач, объектов и версий хранилища...'

$IssueObjects = @() # []{Version; User; Object; Issue; IssueNumb; Done; ToRelease}
$IssuePattern = '(?<issueno>' + ([String]$IssuePrefix).ToUpper().Trim() + '-(?<issuenumb>\d+))'

$FirstCommitToRelease = 0
$LastCommitToRelease = 0

foreach ($Ver in $RepVer) {

    $Comment = [String]$Ver.Comment

    if ([String]::IsNullOrEmpty($Comment)) {continue}

    $VerIssues = @()

    $Comment = $Comment.ToUpper()
    While ($Comment -match $IssuePattern) {
       $VerIssues += (New-Object PSCustomObject -Property @{No = $Matches.issueno.Trim().ToUpper(); Numb = [Int]$Matches.issuenumb})
       $ReplacePattern = '(\W|^)(' + $Matches.issueno + ')(\D|$)'
       $Comment = ($Comment -replace $ReplacePattern, '\.')
    }

    if ($VerIssues.Count -eq 0) {continue}
    
    foreach ($Issue in $VerIssues) {

        $IssueToRelease = ($Issue.No -in $Issues)
        $IssueIsDone = (($Issue.No -in $DoneIssues) -or ($Issue.No -in $ExceptIssues)) -and (-not $IssueToRelease)

        $VersionNumber = [int]$Ver.Version

        # First & Last versions to Release
        if ($IssueToRelease) {
            if ($VersionNumber -gt $LastCommitToRelease) {$LastCommitToRelease = $VersionNumber}
            if (($FirstCommitToRelease -eq 0) -or ($VersionNumber -lt $FirstCommitToRelease)) {$FirstCommitToRelease = $VersionNumber}
        }

        $Objects = @()
        if ($Ver.Added -ne $null) {$Objects += $Ver.Added}
        if ($Ver.Changed -ne $null) {$Objects += $Ver.Changed}
        foreach ($Object in $Objects) {
            $IssueObject = @{
                Version = $VersionNumber;
                User = $Ver.User;
                Issue = $Issue.No;
                IssueNumb = $Issue.Numb;
                Object = $Object;
                Done = $IssueIsDone;
                ToRelease = $IssueToRelease;

            }
            $IssueObjects += New-Object PSCustomObject -Property $IssueObject
        }

    }
}

Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Info' -LogText 'Заполнение описания релиза'
Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Info' -LogText ('Issue objects table count: ' + $IssueObjects.Count)

# Changed objects (not to release and not done)
$ObjectsNotDoneNotReleased = $IssueObjects | Where-Object -FilterScript {-not $_.Done -and -not $_.ToRelease -and ($_.Version -le $LastCommitToRelease)} `
| Sort-Object -Property Object | Select-Object -Property Object -Unique | Get-1CPropertyValues -Property Object

# Auto updated objects without conflicts.
$ObjectsToAutoUpdate = $IssueObjects | Where-Object -FilterScript {($_.Issue -in $Issues) -and -not ($_.Object -in $ObjectsNotDoneNotReleased) -and ($_.Version -le $LastCommitToRelease)} `
| Sort-Object -Property Object | Select-Object -Property Object -Unique | Get-1CPropertyValues -Property Object

# Objects with conflicts
$ObjectsConflicted = $IssueObjects | Where-Object -FilterScript {($_.Issue -in $Issues) -and ($_.Object -in $ObjectsNotDoneNotReleased) -and ($_.Version -le $LastCommitToRelease)} `
| Sort-Object -Property Object | Select-Object -Property Object -Unique | Get-1CPropertyValues -Property Object

$ObjectsToChange = $IssueObjects | Where-Object -FilterScript {$_.Issue -in $Issues} `
| Sort-Object -Property Object | Select-Object -Property Object -Unique | Get-1CPropertyValues -Property Object

'' | Out-File -FilePath $OutFile -Append
'Release issues ' + $Issues.Count | Out-File -FilePath $OutFile -Append
'Changed objects: ' + $ObjectsToChange.Count | Out-File -FilePath $OutFile -Append
'Autoupdated objects: ' + $ObjectsToAutoUpdate.Count | Out-File -FilePath $OutFile -Append
'Conflicted objects: ' + $ObjectsConflicted.Count | Out-File -FilePath $OutFile -Append
'First commit to release: ' + $FirstCommitToRelease | Out-File -FilePath $OutFile -Append
'Last commit to release: ' + $LastCommitToRelease | Out-File -FilePath $OutFile -Append

$ObjectsToChange | Out-File -FilePath $OutFileChangedObjects
$ObjectsToAutoUpdate | Out-File -FilePath $OutFileAutoObjects

$IssueObjectsToRelease = $IssueObjects | Where-Object -FilterScript {$_.ToRelease}

# Set labels for commits to released issues.
if ($DoSetLabel) {

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Info' -LogText 'Установка меток хранилища'
    
    $IssueCommistsToRelease = $IssueObjectsToRelease | Select-Object -Property Version, IssueNumb -Unique
        
    $CommitsToRelease = $IssueObjectsToRelease | Select-Object -Property Version -Unique
    foreach ($Commit in $CommitsToRelease) {
        
        $CommitsIssues = $IssueCommistsToRelease | Where-Object -FilterScript {$_.Version -eq $Commit.Version} `
        | Sort-Object -Property IssueNumb | Select-Object -Property IssueNumb | Get-1CPropertyValues -Property IssueNumb
        
        $Label = $ReleaseNo + ' ' + $IssuePrefix + '-' + [String]::Join(',', $CommitsIssues)
        Invoke-1CCRSetLabel -Conn $Conn -v $Commit.Version -Label $Label -Log $Log | Out-Null
    }
}

'' | Out-File -FilePath $OutFile -Append
'Release issues list' | Out-File -FilePath $OutFile -Append

# Output issues to release with commits versions
foreach ($IssueNo in $Issues) {
    
    $IssueNo = ([String]$IssueNo).Trim().ToUpper()

    ('Issue: ' + $IssueNo) | Out-File -FilePath $OutFile -Append
    
    $IssueCommits = [Object[]]($IssueObjectsToRelease | Where-Object -FilterScript  {$_.Issue -eq $IssueNo})
    if ($IssueCommits.count -gt 0) {

        $IssueUsers = $IssueCommits | Sort-Object -Property User | Select-Object -Property User -Unique | Get-1CPropertyValues -Property User
        ('    Contributor: ' + [String]::Join(',', $IssueUsers)) | Out-File -FilePath $OutFile -Append

        $IssueCRVersions= $IssueCommits | Sort-Object -Property Version | Select-Object -Property Version -Unique | Get-1CPropertyValues -Property Version
        ('    Commits: ' + [String]::Join(',', $IssueCRVersions)) | Out-File -FilePath $OutFile -Append
        
        '    Objects:' | Out-File -FilePath $OutFile -Append
        $IssueCommits | Sort-Object -Property Object | Select-Object -Property Object -Unique | Get-1CPropertyValues -Property Object `
        | % {('    - ' + $_) | Out-File -FilePath $OutFile -Append}

    }
    else {
        '    No commits' | Out-File -FilePath $OutFile -Append
    } 

}

Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Info' -LogText 'Выгрузка информации о релизе'
'' | Out-File -FilePath $OutFile -Append

# Output objects without conflicts (to autoupdate)
$ObjectsToAutoUpdate = [Object[]]$ObjectsToAutoUpdate
if ($ObjectsToAutoUpdate.count -gt 0) {
    'Objects to autoupdate: ' | Out-File -FilePath $OutFile -Append
    foreach ($Object in $ObjectsToAutoUpdate) {
        
        ('- ' + $Object) | Out-File -FilePath $OutFile -Append

        $IssueObjectsToReleaseByObject = $IssueObjectsToRelease | Where-Object -FilterScript {$_.Object -eq $Object} `
        | Select-Object -Property Issue, IssueNumb, Version

        $ObjectIssues = $IssueObjectsToReleaseByObject `
        | Sort-Object -Property IssueNumb | Select-Object -Property Issue -Unique  | Get-1CPropertyValues -Property Issue
        ('    Issues: ' + [String]::Join(', ', $ObjectIssues)) | Out-File -FilePath $OutFile -Append
        
        $ObjectCommits = $IssueObjectsToReleaseByObject `
        | Sort-Object -Property Version | Select-Object -Property Version -Unique | Get-1CPropertyValues -Property Version
        ('    Commits: ' + [String]::Join(', ', $ObjectCommits)) | Out-File -FilePath $OutFile -Append
    }
}
else {
    'NO objects to autoupdate' | Out-File -FilePath $OutFile -Append
}

'' | Out-File -FilePath $OutFile -Append

# Output objects WITH conflicts
$ObjectsConflicted = [Object[]]$ObjectsConflicted
if ($ObjectsConflicted.count -gt 0) {
    'Objects with conflicts: ' | Out-File -FilePath $OutFile -Append
    foreach ($Object in $ObjectsConflicted) {
        
        ('- ' + $Object) | Out-File -FilePath $OutFile -Append

        $IssueObjectsToReleaseByObject = $IssueObjectsToRelease | Where-Object -FilterScript {$_.Object -eq $Object} `
        | Select-Object -Property Issue, IssueNumb, Version
        
        $IssueObjectsConflictedByObject = $IssueObjects | Where-Object -FilterScript {$_.Object -eq $Object -and -not $_.Done -and -not $_.ToRelease} `
        | Select-Object -Property Issue, IssueNumb, Version


        $ObjectIssues = $IssueObjectsToReleaseByObject `
        | Sort-Object -Property IssueNumb | Select-Object -Property Issue -Unique  | Get-1CPropertyValues -Property Issue
        ('    Issues: ' + [String]::Join(', ', $ObjectIssues)) | Out-File -FilePath $OutFile -Append
        
        $ObjectCommits = $IssueObjectsToReleaseByObject `
        | Sort-Object -Property Version | Select-Object -Property Version -Unique | Get-1CPropertyValues -Property Version
        ('    Commits: ' + [String]::Join(', ', $ObjectCommits)) | Out-File -FilePath $OutFile -Append

        $ObjectIssues = $IssueObjectsConflictedByObject `
        | Sort-Object -Property IssueNumb | Select-Object -Property Issue -Unique  | Get-1CPropertyValues -Property Issue
        ('    Conflicted issues: ' + [String]::Join(', ', $ObjectIssues)) | Out-File -FilePath $OutFile -Append
        
        $ObjectCommits = $IssueObjectsConflictedByObject `
        | Sort-Object -Property Version | Select-Object -Property Version -Unique | Get-1CPropertyValues -Property Version
        ('    Conflicted commits: ' + [String]::Join(', ', $ObjectCommits)) | Out-File -FilePath $OutFile -Append

    }
}
else {
    'NO objects with conflicts' | Out-File -FilePath $OutFile -Append
}

if ($DoLockPreprodObjects) {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Info' -LogText 'Захват объектов в продуктовом хранилище...'
    $ObjectsToLock = @()
    Get-Content -Path $AddObjectsToLockFile | % {$ObjectsToLock += $_}
    $ObjectsToChange | % {$ObjectsToLock += $_}
    Invoke-1CCRLock -Conn $ConnPreprod -Objects $ObjectsToLock -includeChildObjectsAll -Log $Log
}

if ($DoUploadCfg) {
    $OutFileDumpCfg = $OutFileDumpCfg.Replace('-DumpCRCfg', '-DumpCRCfg' + '-' + $LastCommitToRelease.ToString())
    If (-not (Test-Path -Path $OutFileDumpCfg)) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Info' -LogText ('Выгрузка конфигурации хранилища версии ' + $LastCommitToRelease + '...')
        Invoke-1CCRDumpCfg -Conn $Conn -CfgFile $OutFileDumpCfg -v $LastCommitToRelease -Log $Log
    }
    else {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Info' -LogText ('Конфигурация хранилища уже выгружена: ' + $OutFileDumpCfg)
    }
}

Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'End'

Start-Sleep -Seconds 10