
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
        $Messaging,
        $Log
    )

    $ProcessName = "UploadRepToGit"

    Out-Log -Log $Log -Label $ProcessName -Text "Start"

    Test-CmnDir -Path $DataDir -CreateIfNotExist | Out-Null

    # Unbind from CR all the time.
    Invoke-1CCRUnbindCfg -Conn $Conn -force | Out-Null

    $DataFile = Add-CmnPath -Path $DataDir -AddPath $ProcessName"Data.json"
    if (Test-Path -Path $DataFile) {
        $ProcessData = Get-Content -Path $DataFile | ConvertFrom-Json
    }
    else {
        if ($NBegin) {
            $ProcessData = @{lastUploadedVersion = $NBegin - 1}
        }
        else {
            $ProcessData = @{lastUploadedVersion = 0}
        }
    }

    $LastUploadedVersion = [int]$ProcessData.lastUploadedVersion
    if (-not $LastUploadedVersion -and $NBegin) {
        $LastUploadedVersion = [int]$NBegin - 1
    }

    Out-Log -Log $Log -Label $ProcessName -Text "Get repository data, last uploaded version $LastUploadedVersion"
    $RepData = Get-1CDevReportData -Conn $Conn1C -NBegin ($LastUploadedVersion + 1) -Log $Log

    # Needed 2 new versions as minimum for comparison issues between nearby versions.
    $VersionsCount =  $RepData.Versions.Count
    if ($VersionsCount -lt 2) {
        Out-Log -Log $Log -Label $ProcessName -Text "No any changes in repository: must be 2 as minimum"
        return
    }

    $Version = $RepData.Versions[$VersionIndex]
    $Issues = Get-1CDevIssueFromComment -IssuePrefix $IssuePrefix -Comment $Version.Comment

    for ($VersionIndex = 0; $VersionIndex -lt ($VersionsCount - 1); ++$VersionIndex) {
        
        $VersionNo = $Version.Version
        $Author = $Version.User

        if (-not $Issues.Issues) {
            Send-1CDevMessage -Messaging $Messaging -Header $ProcessName -Text "Не указан номер задачи в комментарии хранилища: версия $Version, автор $Author"
            return
        }
        
        $NextVersion = $RepData.Versions[$VersionIndex + 1]
        $NextIssues = Get-1CDevIssueFromComment -IssuePrefix $IssuePrefix -Comment $NextVersion.Comment

        $NextVersionNo = $NextVersion.Version
        $NextAuthor = $Version.User
       
        if (-not $Issues.Issues) {
            Send-1CDevMessage -Messaging $Messaging -Header $ProcessName -Text "Не указан номер задачи в комментарии хранилища: версия $NextVersion, автор $NextAuthor"
            return
        }

        if ($Issues.Presentation -eq $NextIssues.Presentation) {
            continue
        }
        
        # Update unbinded configuration from repository.
        Invoke-1CCRUpdateCfg -Conn $Conn1C -v $VersionNo -force -Log $Log        

        # git add <all objects>
        Invoke-GitAdd -Conn $GitConn -PathSpec "*"

        # git commit
        Invoke-GitCommit -Conn $GitConn -Message $Version.Comment -Author $Author -Mail "$Author@$EMailDomain"

        $Version = $NextVersion
        $Issues = $NextIssues

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

    # TODO: добавить код модуля обновления конфигурации базы из хранилища

}

function Get-1CDevIssueFromComment([string]$Comment, $IssuePrefix) {

    $IssuePattern = Get-1CDevIssuePattern -IssuePrefix $IssuePrefix

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

    @{
        Issues = $IssueNo;
        Numbers = $IssueNumbers;
        Presentation = $IssueString;
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
        CRPath = 'Отчет по версиям хранилища';
        RepDate = 'Дата отчета';
        RepTime = 'Время отчета';
        Version = 'Версия';
        User = 'Пользователь';
        CreateDate = 'Дата создания';
        CreateTime = 'Время создания';
        Comment = 'Комментарий';
        Added = 'Добавлены';
        Changed = 'Изменены';
        Deleted = 'Удалены';
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
            elseif ($ParamName -eq $RepParams.Version) {
                
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
            elseif ($ParamName -eq $RepParams.User) {
                $Version.User = $ParamValue.Trim();
            }
            elseif ($ParamName -eq $RepParams.CreateDate) {
                $Version.Date = $ParamValue.Trim();
            }
            elseif ($ParamName -eq $RepParams.CreateTime) {
                $Version.Time = $ParamValue.Trim();
                if (-not $IsConvertedFromMXL) {
                    # Init comment reading after CreateTime string
                    $Comment = '' 
                }
            }
            elseif ($ParamName -eq $RepParams.Comment) {
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
            elseif ($ParamName -eq $RepParams.Added) {
                [String[]]$Added = @($ParamValue)
            }
            elseif ($ParamName -eq $RepParams.Changed) {
                [String[]]$Changed = @($ParamValue)
            }
            elseif ($ParamName -eq $RepParams.Deleted) {
                [String[]]$Deleted = @($ParamValue)
            }
            elseif ($ParamName -eq $RepParams.CRPath) {
                $Report.CRPath = $ParamValue.Trim();
            }
            elseif ($ParamName -eq $RepParams.RepDate) {
                $Report.RepDate = $ParamValue.Trim();
            }
            elseif ($ParamName -eq $RepParams.RepTime) {
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
        $Host,
        $Project,
        $SlackHook,
        $SlackAlertHook,
        $SlackCriticalHook
    )
    @{
        Host = $Host;
        Project = $Project;
        SlackHook = $SlackHook;
        SlackAlert = $SlackAlertHook;
        SlackCriticalHook = $SlackCriticalHook;
    }
}

function Send-1CDevMessage {
    param (
        $Messaging,
        $Header,
        $Text,
        [ValidateSet('Info', 'Alert', 'Critical')]
        $Level
    )

    if ($Messaging -eq $null) {
        return
    }

    $Header = Add-CmnString -Add $Messaging.Projext, $Messaging.Host, $Header -Sep ' - '

    if ($Level -eq 'Alert') {

        # Alert hook
        if ($Messaging.SlackAlertHook) {
            Send-SlackWebHook -HookUrl $Messaging.SlackAlertHook -Text $Text -Header $Header
        }
        elseif ($Messaging.SlackHook) {
            Send-SlackWebHook -HookUrl $Messaging.SlackHook -Text $Text -Header $Header
        }

    }
    elseif ($Level -eq 'Critical') {

        # Critical hook
        if ($Messaging.SlackCriticalHook) {
            Send-SlackWebHook -HookUrl $Messaging.SlackCriticalHook -Text $Text -Header $Header
        }
        elseif ($Messaging.SlackAlertHook) {
            Send-SlackWebHook -HookUrl $Messaging.SlackAlertHook -Text $Text -Header $Header
        }
        elseif ($Messaging.SlackHook) {
            Send-SlackWebHook -HookUrl $Messaging.SlackHook -Text $Text -Header $Header
        }

    }
    else {

        # Info hook
        if ($Messaging.SlackHook) {
            Send-SlackWebHook -HookUrl $Messaging.SlackHook -Text $Text -Header $Header
        }

    }

}
