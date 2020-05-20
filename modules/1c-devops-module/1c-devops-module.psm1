
Import-Module 1c-module
Import-Module 1c-com-module
Import-Module slack-module

function Invoke-1CDevSetRepositoryLabelByComment {
    
    param (
        $Conn,
        $IssuePrefix,
        $DataDir,
        $NBegin,
        $NEnd,
        $ReleaseNo,
        $Log
    )

    Test-CmnDir -Path $DataDir -CreateIfNotExist | Out-Null

    $ProcessName = "SetLabelByComment"

    # Update config from CR
    Out-Log -Log $Log -Label $ProcessName -Text "Update cfg from repository"
    $UpdateCfgResult = Invoke-1CCRUpdateCfg -Conn $Conn -Log $Log

    if ($UpdateCfgResult.ProcessedObjects -gt 0) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'Update IB database'
        Out-Log -Log $Log -Label $ProcessName -Text "Update IB database"
        $UpdateIBDbResult = Invoke-1CUpdateDBCfg -Conn $Conn -Dynamic -Log $Log
    }

    $RepFile = Add-CmnPath -Path $DataDir -AddPath SetRepositoryLabelByCommentRepository.txt

    if ($NBegin) {
        $SetProccessData = $false
    }
    else {

        $SetProccessData = $true
  
        $DataFile = Add-CmnPath -Path $DataDir -AddPath SetRepositoryLabelByCommentData.json
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
    Invoke-1CCRReportTXT -Conn $Conn -ReportFile $RepFile -NBegin $NBegin -NEnd $NEnd -Log $Log

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

        $CommentIssues = ConvertFrom-1CDevComment -Comment $Ver.Comment -IssuePrefix $IssuePrefix
        if (-not $CommentIssues.Issues) {
            continue
        }

        $Label = $ReleaseNo + ' ' + $CommentIssues.Presentation
        Invoke-1CCRSetLabel -Conn $Conn -v $Ver.Version -Label $Label -Log $Log | Out-Null

        $LastCRVersion = [int]$Ver.Version

        # Record script data
        if ($SetProccessData) {
            $ProcessData.lastCRVersion = $LastCRVersion
            Set-Content -Path $DataFile -Value ($ProcessData | ConvertTo-Json) 
        }

    }

}

function Invoke-1CDevUpdateIBFromRepository {



}

function ConvertFrom-1CDevComment([string]$Comment, $IssuePrefix) {

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

    $Report = @{
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

function Convert-1CMXLtoTXT($ComConn, $MXLFile, $TXTFile) {
    # $ComConn - reterned by Get-1CComConnection
    # SD - sheet document.
    $SDFileTypeTXT = (Get-ComObjectProperty -ComObject $ComConn -PropertyName 'ТипФайлаТабличногоДокумента')[3]
    $SD = Invoke-ComObjectMethod -ComObject $ComConn -MethodName 'NewObject' -Parameters 'ТабличныйДокумент'
    Invoke-ComObjectMethod -ComObject $SD -MethodName 'Прочитать' -Parameters $MXLFile
    Invoke-ComObjectMethod -ComObject $SD -MethodName 'Записать' -Parameters ($TXTFile, $SDFileTypeTXT)
}
