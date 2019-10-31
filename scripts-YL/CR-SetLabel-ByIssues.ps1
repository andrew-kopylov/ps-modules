Import-Module c:\scripts\modules\1c-module.ps1 -Force

# Current Powershell command file
$PSCmdFile = Get-Item -Path $PSCommandPath
$ProcessName = $PSCmdFile.BaseName

# Issue files
$IssueListFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-IssueList.txt'
$IssueListDoneFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-IssueListDone.txt'

# Config
$ConfigDir = $PSCmdFile.DirectoryName + '\config'
$Config = Get-Content -Path ($ConfigDir + '\conf.json') | ConvertFrom-Json 
$ConfigUpdater = Get-Content -Path ($ConfigDir + '\updater.json') | ConvertFrom-Json

# Repository files
$RepFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Repository.txt'
$InFileRepositoryJSON = '' # $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Repository.json'
$OutFileRepositoryJSON = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Repository-out.json'

# Configuration dump file
$OutFileDumpCfg = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-DumpCfg-out.cf'

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

$Issues = @()
Get-Content -Path $IssueListFile | % {$Issues += $_.ToUpper().Trim()}

$DoneIssues = @()
Get-Content -Path $IssueListDoneFile | % {$DoneIssues += $_.ToUpper().Trim()}

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

Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'out' -LogText $OutFile

# Move last out-files to archive
$OutFileAchiveDir = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + 'Archive'
$OutFilesToAchiveList = Get-ChildItem -Path $PSCmdFile.DirectoryName -Filter ($OutFileBaseName + '*')
if (-not (Test-Path -Path $OutFileAchiveDir)) {New-Item -Path $OutFileAchiveDir -ItemType Directory -Force}
foreach ($OutFileToArchive in $OutFilesToAchiveList) {
    Move-Item -Path $OutFileToArchive.FullName -Destination ($OutFileAchiveDir + '\' + $OutFileToArchive.Name) -Force
}

# Copy IssueList file to Out.
Copy-Item -Path $IssueListFile -Destination $OutFileIssueList

# Init out-file
(Get-Date).ToString() | Out-File -FilePath $OutFile

$DoSetLabel = read-host -Prompt ('Устанавливать метки (y/n)')
$DoSetLabel = ($DoSetLabel -like 'y')
if ($DoSetLabel) {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'info' -LogText 'Установка меток'
}
else {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'info' -LogText 'Обработка без установки меток'
}

$DoUploadCfg = read-host -Prompt ('Выгрузить конфигурацию хранилища (y/n)')
$DoUploadCfg = ($DoUploadCfg -like 'y')
if ($DoUploadCfg) {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'info' -LogText 'Будет выполнена выгрузка конфигурации'
}
else {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'info' -LogText 'Обработка без выгрузки текущей конфигурации'
}

$DataFile = $PSCmdFile.DirectoryName + '\' + $PSCmdFile.BaseName + '-Data.json'
$ProcessData = Get-Content -Path $DataFile | ConvertFrom-Json

if (Test-Path -Path $OutFileRepositoryJSON) {
    $DoUploadCRReport = read-host -Prompt ('Выгрузить отчет по версиям хранилища (y/n)')
    $DoUploadCRReport = ($DoUploadCRReport -like 'y')
}
else {
    $DoUploadCRReport = $true
}

if ($DoUploadCRReport) {

    $DoneBeforeCRVersion = $ProcessData.doneBeforeCRVersion
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'GetCRReport' -LogText ('Получение отчета хранилища начиная с версии: ' + $DoneBeforeCRVersion)
    Invoke-1CCRReportTXT -Conn $Conn -ReportFile $RepFile -NBegin $DoneBeforeCRVersion -Log $Log

    $RepData = Parce-1CCRReportFromMXL -TXTFile $RepFile

    if ($RepData -eq $null) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'ParceCRReport' -LogText ('Error: data is null')
        break
    }

    $RepVer = $RepData.Versions
    if ($RepVer.Count -eq 0) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'ParceCRReport' -LogText ('No any versions')
        break
    }

    $RepData | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutFileRepositoryJSON
}
else {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'GetCRReport' -LogText ('Загрузка отчета хранилища из файла: ' + $OutFileRepositoryJSON)
    $RepData = Get-Content -Path $OutFileRepositoryJSON | ConvertFrom-Json
}

$IssueObjects = @() # []@{[Integer][$Version, String]Object; [String]Issue; [Int]IssueNumb; [Bool]Done; [Bool]ToRelease}
$IssuePattern = '(?<issueno>' + ([String]$IssuePrefix).ToUpper().Trim() + '-(?<issuenumb>\d+))'

foreach ($Ver in $RepVer) {

    $Comment = [String]$Ver.Comment

    if ([String]::IsNullOrEmpty($Comment)) {continue}

    $VerIssues = @()

    $Comment = $Comment.ToUpper()
    While ($Comment -match $IssuePattern) {
       $VerIssues += (New-Object PSCustomObject -Property @{No = $Matches.issueno; Numb = [Int]$Matches.issuenumb})
       $ReplacePattern = '(\W|^)(' + $Matches.issueno + ')(\D|$)'
       $Comment = ($Comment -replace $ReplacePattern, '\.')
    }

    if ($VerIssues.Count -eq 0) {continue}
    
    foreach ($Issue in $VerIssues) {

        $IssueIsDone = ($Issue.No -in $DoneIssues)
        $IssueToRelease = ($Issue.No -in $Issues)

        $Objects = @()
        if ($Ver.Added -ne $null) {$Objects += $Ver.Added}
        if ($Ver.Changed -ne $null) {$Objects += $Ver.Changed}
        foreach ($Object in $Objects) {
            $IssueObject = @{
                Version = [Int]$Ver.Version
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

Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Info' -LogText 'Заполнение описания релизя'

Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'info' -LogText ('Issue objects table count: ' + $IssueObjects.Count)

# Changed objects (not to release and not done)
$ObjectsNotDoneNotReleased = $IssueObjects | Where-Object -FilterScript {-not $_.Done -and -not $_.ToRelease} `
| Sort-Object -Property Object | Select-Object -Property Object -Unique | Get-1CPropertyValues -Property Object

# Auto updated objects without conflicts.
$ObjectsToAutoUpdate = $IssueObjects | Where-Object -FilterScript {($_.Issue -in $Issues) -and -not ($_.Object -in $ObjectsNotDoneNotReleased)} `
| Sort-Object -Property Object | Select-Object -Property Object -Unique | Get-1CPropertyValues -Property Object

# Objects with conflicts
$ObjectsConflicted = $IssueObjects | Where-Object -FilterScript {($_.Issue -in $Issues) -and ($_.Object -in $ObjectsNotDoneNotReleased)} `
| Sort-Object -Property Object | Select-Object -Property Object -Unique | Get-1CPropertyValues -Property Object

$ObjectsToChange = $IssueObjects | Where-Object -FilterScript {$_.Issue -in $Issues} `
| Sort-Object -Property Object | Select-Object -Property Object -Unique | Get-1CPropertyValues -Property Object

'' | Out-File -FilePath $OutFile -Append
'Release issues ' + $Issues.Count | Out-File -FilePath $OutFile -Append
'Changed objects: ' + $ObjectsToChange.Count | Out-File -FilePath $OutFile -Append
'Autoupdated objects: ' + $ObjectsToAutoUpdate.Count | Out-File -FilePath $OutFile -Append
'Conflicted objects: ' + $ObjectsConflicted.Count | Out-File -FilePath $OutFile -Append

$ObjectsToAutoUpdate | Out-File -FilePath $OutFileAutoObjects

$IssueObjectsToRelease = $IssueObjects | Where-Object -FilterScript {$_.ToRelease}

# Set labels for commits to released issues.
if ($DoSetLabel) {
    
    $IssueCommistsToRelease = $IssueObjectsToRelease | Select-Object -Property Version, IssueNumb -Unique
        
    $CommitsToRelease = $IssueObjectsToRelease | Select-Object -Property Version -Unique
    foreach ($Commit in $CommitsToRelease) {
        
        $CommitsIssues = $IssueCommistsToRelease | Where-Object -FilterScript {$_.Version -eq $Commit.Version} `
        | Sort-Object -Property IssueNumb | Select-Object -Property IssueNumb | Get-1CPropertyValues -Property IssueNumb
        
        $Label = $ReleaseNo + ' ' + $IssuePrefix + '-' + [String]::Join(',', $CommitsIssues)
        Invoke-1CCRSetLabel -Conn $Conn -v $Commit.Version -Label $Label -Log $Log
    }
}

'' | Out-File -FilePath $OutFile -Append
'Release issues list' | Out-File -FilePath $OutFile -Append

# Output issues to release with commits versions
foreach ($IssueNo in $Issues) {
    
    $IssueNo = ([String]$IssueNo).Trim().ToUpper()

    ('Issue: ' + $IssueNo) | Out-File -FilePath $OutFile -Append
    
    $IssueCommits = $IssueObjectsToRelease | Where-Object -FilterScript {$_.Issue -eq $IssueNo}
    if ($IssueCommits.count -gt 0) {

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

'' | Out-File -FilePath $OutFile -Append

# Output objects without conflicts (to autoupdate)
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

if ($DoUploadCfg) {
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Info' -LogText 'Выгрузка конфигурации...'
    Invoke-1CCRUpdateCfg -Conn $Conn -Log $Log
    Invoke-1CDumpCfg -Conn $Conn -CfgFile $OutFileDumpCfg -Log $Log
}

Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'End'
