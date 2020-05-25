
# Version 1.0

Import-Module 1c-module
Import-Module 1c-com-module
Import-Module slack-module
Import-Module git-module

function Invoke-1CDevUploadRepositoryToGit {
    param (
        $Conn1C,
        $ConnGit,
        $DataDir,
        $NBegin,
        $IssuePrefix,
        $EMailDomain,
        [switch]$PushRemote,
        $Messaging,
        $Log
    )

    $ProcessName = "UploadRepToGit"

    Out-Log -Log $Log -Label $ProcessName -Text "Start"

    Test-CmnDir -Path $DataDir -CreateIfNotExist | Out-Null

    # Unbind from CR all the time.
    $Result = Invoke-1CCRUnbindCfg -Conn $Conn1C -force -Log $Log
    if (-not $Result.OK) {
        $MsgText = "Ошибка отсоединения конфигурации от хранилища: " + $Result.Out
        Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.CRUnbindCfg.Error" -Text $MsgText -Level Alert
        return
    }
    
    $DataFile = Add-CmnPath -Path $DataDir -AddPath $ProcessName"Data.json"
    if (Test-Path -Path $DataFile) {
        $ProcessData = Get-Content -Path $DataFile | ConvertFrom-Json
    }
    else {
        $ProcessData = @{lastUploadedVersion = 0}
    }

    $LastUploadedVersion = [int]$ProcessData.lastUploadedVersion
    if ($LastUploadedVersion -ge $NBegin) {
        $NBegin = $LastUploadedVersion + 1
    }

    Out-Log -Log $Log -Label $ProcessName -Text "Get repository data, last uploaded version $LastUploadedVersion"
    $RepData = Get-1CDevReportData -Conn $Conn1C -NBegin $NBegin -Log $Log

    # Needed 2 new versions as minimum for comparison issues between nearby versions.
    $VersionsCount =  $RepData.Versions.Count
    if ($VersionsCount -lt 2) {
        Out-Log -Log $Log -Label $ProcessName -Text "No any changes in repository: must be 2 as minimum"
        return
    }

    $VersionsToCommit = @()
    $VersionsFirstString = @()

    for ($VersionIndex = 0; $VersionIndex -lt ($VersionsCount - 1); ++$VersionIndex) {
        
        $Version = $RepData.Versions[$VersionIndex]
        $Issues = Get-1CDevIssueFromComment -IssuePrefix $IssuePrefix -Comment $Version.Comment

        $VersionNo = $Version.Version
        $Author = $Version.User

        if (-not $Issues.Issues) {
            $MsgText = "Не указан номер задачи в комментарии хранилища: версия $VersionNo, автор $Author"
            Send-1CDevMessage -Messaging $Messaging -Header $ProcessName -Text $MsgText  -Level Alert
            return
        }
        
        $NextVersion = $RepData.Versions[$VersionIndex + 1]
        $NextIssues = Get-1CDevIssueFromComment -IssuePrefix $IssuePrefix -Comment $NextVersion.Comment

        $NextVersionNo = $NextVersion.Version
        $NextAuthor = $Version.User
       
        if (-not $Issues.Issues) {
            $MsgText = "Не указан номер задачи в комментарии хранилища версия $NextVersionNo, автор $NextAuthor"
            Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.Error" -Text $MsgText -Level Alert
            return
        }

        $VersionsToCommit += $Version
        $VersionsFirstString += $Issues.FirstString

        if (($Issues.Presentation -eq $NextIssues.Presentation) -and ($Version.User -eq $NextVersion.User)) {
            continue
        }
        
        # Update unbinded configuration from repository.
        $Result = Invoke-1CCRUpdateCfg -Conn $Conn1C -v $VersionNo -force -Log $Log
        if (-not $Result.OK) {
            $MsgText = "Ошибка обновления версии конфигурации " + $Result.Out
            Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.UpdateCfg.Error" -Text $MsgText -Level Alert
            return
        }

        $ConfigDir = Add-CmnPath -Path $ConnGit.Dir -AddPath config
        Test-CmnDir -Path $ConfigDir -CreateIfNotExist | Out-Null

        $Result = Invoke-1CDumpCfgToFiles -Conn $Conn1C -FilesDir $ConfigDir -Update -Force -Log $Log
        if (-not $Result.OK) {
            $MsgText = "Ошибка выгрузки файлов конфигурации " + $Result.Out
            Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.DumpCfgToFiles.Error" -Text $MsgText -Level Alert
            return
        }

        # git add <all objects>
        Out-Log -Log $Log -Label "$ProcessName.GitAdd.Start"
        $Result = Invoke-GitAdd -Conn $GitConn -PathSpec "*"
        if (-not $Result.OK) {
            $MsgText = "Ошибка добавления изменений Git " + $Result.Error
            Out-Log -Log $Log -Label "$ProcessName.GitAdd.Error" -Text $MsgText
            Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.GitAdd.Error" -Text $MsgText -Level Alert
            return
        }

        # Commit message
        if ($VersionsFirstString) {
            $FirstStrings = $VersionsFirstString | Select-Object -Unique
            $FirstStrings = [string]::Join(' ', $FirstStrings)
        }
        else {
            $FirstStrings = ''
        }
        [string]$CommitMessage = [string]::Join(' ', $Issues.Issues) + ' ' + $FirstStrings
        if ($CommitMessage.Length -gt 72) {
            $CommitMessage = $CommitMessage.Substring(0, 72) + '...'
        }
        foreach ($CommitVersion in $VersionsToCommit) {
            $CommitVersionNo = $CommitVersion.Version
            $CommitVersionUser = $CommitVersion.User
            $CommitVersionDateTime = $CommitVersion.Date + " " + $CommitVersion.Time
            $CommitMessage += "`n`n" + "Version: $CommitVersionNo Date: $CommitVersionDateTime User: $CommitVersionUser"
            $CommitMessage += "`n" + $CommitVersion.Comment
        }

        # git commit
        Out-Log -Log $Log -Label "$ProcessName.GitCommit.Start"
        $Result = Invoke-GitCommit -Conn $GitConn -Message $CommitMessage -Author $Author -Mail "$Author@$EMailDomain"
        if (-not $Result.OK) {
            $MsgText = "Ошибка выполнения коммита Git " + $Result.Error
            Out-Log -Log $Log -Label "$ProcessName.GitCommit.Error" -Text $MsgText
            Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.GitCommit.Error" -Text $MsgText -Level Alert
            return
        }

        # git push
        if ($PushRemote) {
            Out-Log -Log $Log -Label "$ProcessName.GitPush.Start"
            $Result = Invoke-GitPush -Conn $GitConn
            if (-not $Result.OK) {
                $MsgText = "Ошибка выполнения пуша Git " + $Result.Error
                Out-Log -Log $Log -Label "$ProcessName.GitPush.Error" -Text $MsgText
                Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.GitPush.Error" -Text $MsgText -Level Alert
                return
            }
        }
        else {
            Out-Log -Log $Log -Label "$ProcessName.GitPush.Escape"
        }

        # Write process data
        $ProcessData.LastUploadedVersion = $VersionNo
        Set-Content -Path $DataFile -Value ($ProcessData | ConvertTo-Json) 

        $VersionsFirstString = @()
        $VersionsToCommit = @()

    }

}

function Invoke-1CDevSetRepositoryLabelByComment {
    param (
        $Conn,
        $IssuePrefix,
        $DataDir,
        $NBegin,
        $NEnd,
        $ReleaseNo,
        $Messaging,
        $Log
    )

    $ProcessName = "SetRepLabelByComment"

    Test-CmnDir -Path $DataDir -CreateIfNotExist | Out-Null

    # Update config from CR
    Out-Log -Log $Log -Label $ProcessName -Text "Update cfg from repository"
    $UpdateCfgResult = Invoke-1CCRUpdateCfg -Conn $Conn -Log $Log

    if ($UpdateCfgResult.ProcessedObjects -gt 0) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'Update IB database'
        Out-Log -Log $Log -Label $ProcessName -Text "Update IB database"
        $UpdateIBDbResult = Invoke-1CUpdateDBCfg -Conn $Conn -Dynamic -Log $Log
    }

    $RepFile = Add-CmnPath -Path $DataDir -AddPath $ProcessName"Repository.txt"

    if ($NBegin) {
        $SetProccessData = $false
    }
    else {

        $SetProccessData = $true
  
        $DataFile = Add-CmnPath -Path $DataDir -AddPath $ProcessName"Data.json"
        if (Test-Path -Path $DataFile) {
            $ProcessData = Get-Content -Path $DataFile | ConvertFrom-Json
        }
        else {
            $ProcessData = @{lastCRVersion = 1}
        }

        $LastCRVersion = $ProcessData.lastCRVersion
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'UploadCRReport' -LogText "Last commit version is $LastCRVersion"

        $NBegin = $LastCRVersion + 1
    }


    # Upload MXL CR Report.
    Invoke-1CCRReportTXT -Conn $Conn -ReportFile $RepFile -NBegin $NBegin -NEnd $NEnd -Log $Log | Out-Null

    $IssuePattern = $IssuePrefix + '-\d+'

    $RepData = ConvertFrom-1CCRReport -TXTFile $RepFile -FileType ConvertedFromMXL
    if ($RepData -eq $null) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'ParceCRReport' -LogText ('Error: data is null')
        return
    }

    $RepVer = $RepData.Versions
    if ($RepVer.Count -eq 0) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'ParceCRReport' -LogText ('No new versions')
        return
    }

    foreach ($Ver in $RepVer) {

        $Version = $Ver.Version
        $Author = $Ver.User
        $Comment = $Ver.Comment

        $CommentIssues = Get-1CDevIssueFromComment -Comment $Comment -IssuePrefix $IssuePrefix
        if (-not $CommentIssues.Issues) {
            Send-1CDevMessage -Messaging $Messaging -Header $ProcessName -Text "Не указан номер задачи в комментарии хранилища: версия $Version, автор $Author"
            return
        }

        $Label = $ReleaseNo + ' ' + $CommentIssues.Presentation
        Invoke-1CCRSetLabel -Conn $Conn -v $Version -Label $Label -Log $Log | Out-Null

        $LastCRVersion = [int]$Ver.Version

        # Record script data
        if ($SetProccessData) {
            $ProcessData.lastCRVersion = $LastCRVersion
            Set-Content -Path $DataFile -Value ($ProcessData | ConvertTo-Json) 
        }

    }

}

function Invoke-1CDevUpdateIBFromRepository {

    param(
        $Conn,
        $ConnExt,
        $BlockDelayMinutes = 5,
        $BlockPeriodMinutes = 15,
        [switch]$DynamicUpdate,
        [switch]$TerminateDesigner,
        $DesignerOpenHours = 0,
        $AttemptsOnFailure = 3,
        $ExternalProcessor = '',
        $ExecuteTimeout = 0,
        $Messaging,
        $Log
    )

    $ProcessName = "UpdateIBFromRep"

    Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.Start" -Text "Начало обновления конфигурации информационной базы" -Log $Log

    $UpdateBeginDate = Get-Date

    # Conneсtion parameters
    $Conn = Get-1CConn -DisableStartupMessages $true -DisableStartupDialogs $true -Conn $Conn

    if ($ConnExt) {
        $ConnExt = Get-1CConn -CRPath $ConnExt.CRPath -Extension $ConnExt.Extension -Conn $Conn
    }

    # Terminate designer seances
    $IsTerminatedSessions = $false
    if ($TerminateDesigner) {
        $DesignerStartedBefore = (Get-date).AddHours(-$DisgnerOpenHours);

        try {
            $Result = Remove-1CIBSessions -Conn $Conn -TermMsg $ScriptMsg -AppID 'Designer' -StartedBefore $DesignerStartedBefore -Log $Log
            if ($Result.TerminatedSessions.Count -gt 0) {
                $IsTerminatedSessions = $true
            }
        }
        catch {
            $MsgText = "Ошибка закрытия сеанса конфигуратора: $_"
            Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.TreminateDisigner.Error" -Text $MsgText -Level Critical -Log $Log
            return
        }
    }
    if ($IsTerminatedSessions) {
        Start-Sleep -Seconds 30
    }

    # Update configuration from repository.
    try {
    
        $IsRequiredUpdate = $false
    
        # Update from config CR
        $Result = Invoke-1CCRUpdateCfg -Conn $Conn -Log $Log
        if ($Result.OK) {
            if ($Result.ProcessedObjects) {
                $IsRequiredUpdate = $True
                $MsgText = "Изменено объектов: " + $Result.ProcessedObjects.Count
                Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.UpdateCfg" -Text $MsgText 
            }
        }
        else {
            $MsgText = "Ошибка получения изменений конфигурации: " + $Result.out
            Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.UpdateCfg.Error" -Text $MsgText -Level Alert
            return
        }

        # Update extension from CR
        if ($ConnExt) {
            $ExtName = $ConnExt.Extension
            $ResultExt = Invoke-1CCRUpdateCfg -Conn $ConnExt -Log $Log
            if ($ResultExt.OK) {
                if ($ResultExt.ProcessedObjects) {
                    $IsRequiredUpdate = $True
                    $MsgText = "Изменено объектов расширения ($ExtName): " + $ResultExt.ProcessedObjects.Count
                    Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.UpdateExt" -Text $MsgText 
                }
            }
            else {
                $MsgText = "Ошибка получения изменений расширения ($ExtName): " + $ResultExt.out
                Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.UpdateExt.Error" -Text $MsgText -Level Alert
                return
            }
        }

        if (-not $IsRequiredUpdate -and (Test-1CCfChanged -Conn $Conn)) {
            $IsRequiredUpdate = $True
        }

    }
    catch {
        $MsgText = "Ошибка обновления конфигурации: $_"
        Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.UpdateCfg.Error" -Text $MsgText -Level Critical -Log $Log
        return
    }

    if (-not $IsRequiredUpdate) {
        $MsgText = "Не требуется обновление конфигурации информационной базы"
        Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.End" -Text $MsgText -Log $Log
        return    
    }

    # Dynamic configuration updating
    if ($UseDynamicUpdate) {
        
        $MsgText = "Запуск динамического обновления конфигурации базы данных..."
        Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.End" -Text $MsgText
        
        $Result = Invoke-1CUpdateDBCfg -Conn $Conn -Dynamic -Log $Log
        if ((-not $Result.OK) -or (Test-1CCfChanged -Conn $Conn)) {
            $MsgText = "Ошибка динамического обновления: " + $Result.Out
            Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.DynamicUpdate.Error" -Text $MsgText
        }
        else {
            $MsgText = "Динамическое обновление успешно завершено."
            Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.End" -Text $MsgText
            return
        }
    }

    $PermissionCode = 'CfgUpdate-' + (Get-Date).ToString('HHmmss')

    # Block IB for updating
    $BlockFrom = $UpdateBeginDate.AddMinutes($BlockDelayMinutes)
    $BlockTo = ($BlockFrom).AddMinutes($BlockPeriodMinutes)

    $MinUpdateMinutes = [int]($BlockPeriodMinutes / 5)
    $MaxUpdateMinutes = [int]($BlockPeriodMinutes / 3)

    $UpdatePeriodInfo = $BlockFrom.ToString('HH:mm') + " в течении $MinUpdateMinutes-$MaxUpdateMinutes минут."

    $BlockMsg = "Обновление базы в $UpdatePeriodInfo"
    Set-1CIBSessionsDenied -Conn $Conn -Denied -From $BlockFrom -To $BlockTo -Msg $BlockMsg -PermissionCode $PermissionCode | Out-Null

    $MsgText = "Установлена блокировка базы c $UpdatePeriodInfo"
    Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.SettledBlock" -Text $MsgText -Log $Log
    Out-Log -Log $Log -Label "$ProcessName.UpdateDelay" -Text "$BlockDelayMinutes min"

    while ((Get-Date) -lt $BlockFrom) {
        Start-Sleep -Seconds 5
    }

    # Update database configuration
    $MsgText = "Запуск обновления базы данных..."
    Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.UpdateDB" -Text $MsgText -Log $Log

    Start-Sleep -Seconds 10 # Waiting for new sessions

    $Conn.UC = $PermissionCode
    if ($ConnExt) {
        $ConnExt.UC = $PermissionCode
    }

    # Terminate sessions and update IB
    Remove-1CIBSessions -Conn $Conn -TermMsg $ScriptMsg -Log $Log
    Remove-1CIBConnections -Conn $Conn -Log $Log

    $Result = Invoke-1CUpdateDBCfg -Conn $Conn -Log $Log
    $ResultExt = @{OK = 1; out = ''}
    if ($ConnExt) {
        $ResultExt = Invoke-1CUpdateDBCfg -Conn $ConnExt -Log $Log
    }
    $IsFailure = (-not $Result.OK) -or (-not $ResultExt.OK) -or (Test-1CCFChanged -Conn $Conn);

    $AttemtsCounter = 1
    While ($IsFailure) {

        $MsgText = "Ошибка обновления базы данных: " + $Result.out + (Add-CmnString -Add $ResultExt.out -Sep ", ext ")
        Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.UpdateDB.Error" -Text $MsgText -Log $Log -Level crib
    
        $AttemtsCounter++        
        if ($AttemtsCounter -gt $AttemptsOnFailureCount) {
            return
        }

        $TimeSpan = New-TimeSpan -Start Get-Date -End $BlockTo
        $WaitSecondsToNextAttempt = [int]($TimeSpan.TotalSeconds / ($AttemptsOnFailureCount - $AttemtsCounter + 1))
        Start-Sleep -Seconds $WaitSecondsToNextAttempt

        # Next attempt updating IB database
        $MsgText = "Запуск обновления конфигурации базы данных... Попытка $AttemtsCounter из $AttemptsOnFailureCount"
        Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.UpdateDB" -Text $MsgText -Log $Log

        Remove-1CIBSessions -Conn $Conn -TermMsg $ScriptMsg -Log $Log
        Remove-1CIBConnections -Conn $Conn -Log $Log

        $Result = Invoke-1CUpdateDBCfg -Conn $Conn -Log $Log
        $ResultExt = @{OK = 1; out = ''}
        if ($ConnExt) {
            $ResultExt = Invoke-1CUpdateDBCfg -Conn $ConnExt -Log $Log
        }
        $IsFailure = (-not $Result.OK) -or (-not $ResultExt.OK) -or (Test-1CCFChanged -Conn $Conn);

    }

    if ((-not $IsFailure) -and $ExternalProcessor) {
        $MsgText = "Запуск внешней обработки после обновления: " + (Get-CmnPathBaseName -Path $ExternalProcessor)
        Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.ExternalProcessor.Run" -Text $MsgText -Log $Log
        $Result = Invoke-1CExecute -Conn $Conn -ExternalProcessor $ExternalProcessor -Timeout $ExecuteTimeout -Log $Log
        $IsFailure = (-not $Result.OK)
        if ($IsFailure) {
            $MsgText = "Ошибка выполнения обработки данных после обновления конфигурации: " + $Result.Out
            Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.ExternalProcessor.Error" -Text $MsgText -Log $Log -Level Critical
        }
    }

    # Unblock IB
    Set-1CIBSessionsDenied -Conn $Conn | Out-Null

    if ($IsFailure) {
        $MsgText = "ОШИБКА!!! Обновление НЕ выполнено по причине: " + $Result.out + " " + $Result.msg
        Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.Error" -Text $MsgText -Log $Log -Level Critical
    } 
    else {
        $MsgText = "Обновление успешно завершено"
        Send-1CDevMessage -Messaging $Messaging -Header "$ProcessName.End" -Text $MsgText -Log $Log
    }

}

function Get-1CDevIssueFromComment([string]$Comment, $IssuePrefix) {

    $IssuePattern = Get-1CDevIssuePattern -IssuePrefix $IssuePrefix

    $CommentSrc = $Comment

    $IssueNo = @()
    $IssueNumbers = @()

    while ($Comment -match $IssuePattern) {
        $IssueNo += $Matches.issueno
        $IssueNumbers += [int]$Matches.issuenumb
        $ReplacePattern = '(\W|^)(' + $Matches.issueno + ')(\D|$)'
        $Comment = ($Comment -replace $ReplacePattern, '\.')
    }

    $IssueNumbers = $IssueNumbers | Sort
    if ($IssueNumbers) {
        $IssueString = $IssuePrefix + '-' + [String]::Join(',', $IssueNumbers)
    }
    else {
        $IssueString = ''
    }

    $FirstStringComment = ""
    $MatchFirstString =  "$IssuePrefix-\d+\s(?<text>.*)"
    if ($CommentSrc -match $MatchFirstString) {
        $FirstStringComment = $Matches.text
    }

    @{
        Issues = $IssueNo;
        Numbers = $IssueNumbers;
        Presentation = $IssueString;
        FirstString = $FirstStringComment
    }
}

function Get-1CDevIssuePattern([string]$IssuePrefix) {
    '(?<issueno>' + ($IssuePrefix).ToUpper() + '-(?<issuenumb>\d+))'
}

function Get-1CDevReportData {
    param (
        $Conn,
        $NBegin,
        $NEnd,
        $Log
    )

    $RepFile = [System.IO.Path]::GetTempFileName()

    $Result = Invoke-1CCRReportTXT -Conn $Conn -ReportFile $RepFile -NBegin $NBegin -NEnd $NEnd -Log $Log
    
    if ($Result.OK) {
        $RepData = ConvertFrom-1CCRReport -TXTFile $RepFile
    }
    
    if (Test-Path -Path $RepFile) {
        Remove-Item -Path $RepFile
    }

    $RepData
}

function Invoke-1CCRReportTXT {
    param(
        $Conn,
        $ReportFile,
        $NBegin,
        $NEnd,
        [switch]$GroupByObject,
        [switch]$GroupByComment,
        $Log
    )

    $TempReportFileMXL = $ReportFile + '-tmp.mxl'

    $Result = Invoke-1CCRReport -Conn $Conn -ReportFile $TempReportFileMXL -NBegin $NBegin -NEnd $NEnd -GroupByObject:$GroupByObject -GroupByComment:$GroupByComment -Log $Log
    if ($Result.OK = 1 -and (Test-Path -Path $TempReportFileMXL)) {
        $ComConn = Get-1CComConnection -Conn $Conn
        Convert-1CMXLtoTXT -ComConn $ComConn -MXLFile $TempReportFileMXL -TXTFile $ReportFile
        if (-not (Test-Path -Path $ReportFile)) {
            $MsgText = 'Ошибка конвертации отчета хранилища из формата MXL в TXT.'
            Add-1CLog -Log $Log -ProcessName 'ConvertMXLtoTXT' -LogHead 'Error' -LogText $MsgText -Result $Result -OK 0
        }
    }
    if (Test-Path -Path $TempReportFileMXL) {
        Remove-Item -Path $TempReportFileMXL
    }
    $Result
}

function ConvertFrom-1CCRReport {
    param (
        $TXTFile,
        [ValidateSet('UploadedAsTXT', 'ConvertedFromMXL')]
        $FileType
    )

    if (-not [String]::IsNullOrEmpty($FileType)) {
        $IsConvertedFromMXL = ($FileType -eq 'ConvertedFromMXL')
    }
    else {
        $IsConvertedFromMXL = $null
    }

    $RepParams = @{
        CRPath = @('Отчет по версиям хранилища', 'Repository Versions Report');
        RepDate = @('Дата отчета', 'Report date');
        RepTime = @('Время отчета', 'Report time');
        Version = @('Версия', 'Version');
        User = @('Пользователь', 'User');
        CreateDate = @('Дата создания', 'Creation date');
        CreateTime = @('Время создания', 'Creation time');
        Comment = @('Комментарий', 'Comment');
        Added = @('Добавлены', 'Added');
        Changed = @('Изменены', 'Changed');
        Deleted = @('Удалены', 'Deleted');
    }

    $Report = New-Object PSCustomObject -Property @{
        CRPath = '';
        RepDate = '';
        RepTime = '';
        Versions = @();
    }

    $Version = $null;
    
    # Version, User, Date, Comment, Added (array), Changed (array)
    $ReportText = Get-Content -Path $TXTFile
    $ReportText += '' # For correct processed end

    $ParamPattern = '^(?<param>\w+.*?):\s*(?<value>.*)'

    #++ For ver Report converted TXT from MXL
    $BeginCommentPattern = '^"(?<text>(?:"")*(?:[^"]|$).*)'
    $EndCommentPattern = '(?<text>.*(?:[^"]|^)(?:"")*)"(?:$|\s)'
    #--

    #++ For ver Report loaded as TXT
    $AddedPattern = '^\sДобавлены\s\d+'
    $ChangedPattern = '^\sИзменены\s\d+'
    $DeletedPattern = '^\sУдалены\s\d+'
    #--

    $Comment = $null
    $Added = $null
    $Changed = $null
    $Deleted = $null

    foreach ($RepStr in $ReportText) {

        # Autodefine by comment file type.
        if (($IsConvertedFromMXL -eq $null) -and ($Comment -ne $null)) {
            if ($RepStr -match $ParamPattern) {
                $ParamName = $Matches.param
                $ParamValue = $Matches.value
                if ($ParamName = $RepParams.Comment) {
                    $IsConvertedFromMXL = $true
                    $Comment = $null

                }
            }
            if ($IsConvertedFromMXL -ne $true) {$IsConvertedFromMXL = $false}
        }

        # Parce text
        if ($Comment -ne $null) {

            # Comment
            
            if ($IsConvertedFromMXL) {
                if ($RepStr -match $EndCommentPattern) {
                    $Comment = $Comment + '
                    ' + $Matches.text.Trim()
                    $Version.Comment = $Comment.Replace('""', '"')
                    $Comment = $null # End comment
                }
                else {
                    $Comment = $Comment + '
                    ' + $RepStr.Trim()
                }
            } #-- Conveted from MXL
            else {
                if ([String]::IsNullOrWhiteSpace($RepStr)) {
                    $Version.Comment = $Comment.Trim()
                    $Comment = $null # End comment
                }
                elseif ($Comment -eq '') {
                    $Comment = $RepStr.Trim() # Begin comment
                }
                else {
                    $Comment = $Comment + '
                    ' + $RepStr.Trim()
                }
            } #-- Loaded as TXT
        }
        elseif ($Added -is [System.Array]) {

            # Added objects 
            
            if ([String]::IsNullOrWhiteSpace($RepStr)) {
                $Version.Added = $Added
                $Added = $null
            } 
            else {
                $Added += $RepStr.Trim()
            }

        }
        elseif ($Changed -is [System.Array]) {

            # Changed objects

            if ([String]::IsNullOrWhiteSpace($RepStr)) {
                $Version.Changed = $Changed
                $Changed = $null
            } 
            else {
                $Changed += $RepStr.Trim()
            }
        }
        elseif ($Deleted -is [System.Array]) {

            # Deleted objects

            if ([String]::IsNullOrWhiteSpace($RepStr)) {
                $Version.Deleted = $Deleted
                $Deleted = $null
            } 
            else {
                $Deleted += $RepStr.Trim()
            }
        }
        elseif ($RepStr -match $ParamPattern) {

            # Parameter - "Name: Value"

            $ParamName = $Matches.param
            $ParamValue = $Matches.value

            if ($ParamName -eq '') {
                continue;
            }
            elseif ($ParamName -in $RepParams.Version) {
                
                if ($Version -ne $null) {
                    $Report.Versions += $Version
                }

                $Version = Get-1CCRVersionTmpl

                $ParamValue = $ParamValue.Trim()

                $NumbSep = [string][char]160
                if ($ParamValue.Contains($NumbSep)) {$ParamValue = $ParamValue.Replace($NumbSep,'')}

                $NumbSep = [string][char]32
                if ($ParamValue.Contains($NumbSep)) {$ParamValue = $ParamValue.Replace($NumbSep,'')}

                $Version.Version = $ParamValue

            }
            elseif ($ParamName -in $RepParams.User) {
                $Version.User = $ParamValue.Trim();
            }
            elseif ($ParamName -in $RepParams.CreateDate) {
                $Version.Date = $ParamValue.Trim();
            }
            elseif ($ParamName -in $RepParams.CreateTime) {
                $Version.Time = $ParamValue.Trim();
                if (-not $IsConvertedFromMXL) {
                    # Init comment reading after CreateTime string
                    $Comment = '' 
                }
            }
            elseif ($ParamName -in $RepParams.Comment) {
                $Comment = [string]$ParamValue
                if ([String]::IsNullOrWhiteSpace($Comment)) {
                    $Comment = $null
                }
                else {
                    if ($Comment -match $BeginCommentPattern) {
                        $Comment = $Matches.text
                    }
                    else {
                        # Однострочный комментарий.
                        $Version.Comment = $Comment.Trim()
                        $Comment = $null
                    }
                    if ($Comment -ne $null -and $Comment -match $EndCommentPattern) {
                        $Version.Comment = $Matches.text.Replace('""', '"')
                        $Comment = $null
                    }
                }
            }
            elseif ($ParamName -in $RepParams.Added) {
                [String[]]$Added = @($ParamValue)
            }
            elseif ($ParamName -in $RepParams.Changed) {
                [String[]]$Changed = @($ParamValue)
            }
            elseif ($ParamName -in $RepParams.Deleted) {
                [String[]]$Deleted = @($ParamValue)
            }
            elseif ($ParamName -in $RepParams.CRPath) {
                $Report.CRPath = $ParamValue.Trim();
            }
            elseif ($ParamName -in $RepParams.RepDate) {
                $Report.RepDate = $ParamValue.Trim();
            }
            elseif ($ParamName -in $RepParams.RepTime) {
                $Report.RepTime = $ParamValue.Trim();
            }
        }
        elseif (-not $IsConvertedFromMXL) {
            if ($RepStr -match $AddedPattern) {
                [String[]]$Added = @()
            }
            elseif ($RepStr -match $ChangedPattern) {
                [String[]]$Changed = @()
            }
            elseif ($RepStr -match $DeletedPattern) {
                [String[]]$Deleted = @()
            }
        }
    }

    if ($Version -ne $null) {
        $Report.Versions += $Version
    }
    
    $Report
}

function Get-1CCRVersionTmpl {
    New-Object PSCustomObject -Property @{
        Version = 0;
        User = '';
        Date = $null;
        Time = $null;
        Comment = '';
        Added = $null;
        Changed = $ull;
        Deleted = $null;
    }
}

function Convert-1CMXLtoTXT($ComConn, $MXLFile, $TXTFile) {
    # $ComConn - reterned by Get-1CComConnection
    # SD - sheet document.
    $SDFileTypeTXT = (Get-ComObjectProperty -ComObject $ComConn -PropertyName 'ТипФайлаТабличногоДокумента')[3]
    $SD = Invoke-ComObjectMethod -ComObject $ComConn -MethodName 'NewObject' -Parameters 'ТабличныйДокумент'
    Invoke-ComObjectMethod -ComObject $SD -MethodName 'Прочитать' -Parameters $MXLFile
    Invoke-ComObjectMethod -ComObject $SD -MethodName 'Записать' -Parameters ($TXTFile, $SDFileTypeTXT)
}

function Get-1CDevMessaging {
    param (
        $Project,
        $Host,
        $Service,
        $Path,
        $SlackHook,
        $SlackAlertHook,
        $SlackCriticalHook
    )
    @{
        Project = $Project;
        Host = $Host;
        Service = $Service
        Path = $Path
        SlackHook = $SlackHook;
        SlackAlertHook = $SlackAlertHook;
        SlackCriticalHook = $SlackCriticalHook;
    }
}

function Send-1CDevMessage {
    param (
        $Messaging,
        $Header,
        $Text,
        [ValidateSet('Info', 'Alert', 'Critical')]
        $Level,
        $Log
    )

    if ($Log) {
        Out-Log -Log $Log -Label $Header -Text $Text
    }

    if ($Messaging -eq $null) {
        return
    }

    $ProjectHost = Add-CmnString -Add $Messaging.Project, $Messaging.Host, $Messaging.Service, $Messaging.Path -Sep ' - '

    if ($Messaging.SlackHook -or $Messaging.SlackAlertHook -or $Messaging.SlackCriticalHook) {
        $SlackHeader = Add-CmnString -Str $ProjectHost -Add (Get-SlackFormat -Text $Header -Italic) -Sep ": "
    }


    if ($Level -eq 'Alert') {

        # Alert hook
        if ($Messaging.SlackAlertHook) {
            Send-SlackWebHook -HookUrl $Messaging.SlackAlertHook -Text $Text -Header $SlackHeader -Emoji bangbang 
        }
        elseif ($Messaging.SlackHook) {
            Send-SlackWebHook -HookUrl $Messaging.SlackHook -Text $Text -Header $SlackHeader -Emoji bangbang
        }

    }
    elseif ($Level -eq 'Critical') {

        # Critical hook
        if ($Messaging.SlackCriticalHook) {
            Send-SlackWebHook -HookUrl $Messaging.SlackCriticalHook -Text $Text -Header $SlackHeader -Emoji boom
        }
        elseif ($Messaging.SlackAlertHook) {
            Send-SlackWebHook -HookUrl $Messaging.SlackAlertHook -Text $Text -Header $SlackHeader -Emoji boom
        }
        elseif ($Messaging.SlackHook) {
            Send-SlackWebHook -HookUrl $Messaging.SlackHook -Text $Text -Header $SlackHeader -Emoji boom
        }

    }
    else {

        # Info hook
        if ($Messaging.SlackHook) {
            Send-SlackWebHook -HookUrl $Messaging.SlackHook -Text $Text -Header $SlackHeader -Emoji information_source
        }

    }

}
