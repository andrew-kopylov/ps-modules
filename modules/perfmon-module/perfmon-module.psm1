
####
# COUNTERS
####

function Test-PmCounter {

    param (
        $Counters,
        $Counter,
        [PmCounterTypes]$CounterType,
        [PmCounterGroups]$CounterGroup,
        $Object,

        [scriptblock]$Script
    )

    $NameKey = ''
    $GroupKey = ''

    if ($Counter -ne $null) {
        $NameKey = $Counter.NameKey;
        $GroupKey = $Counter.GroupKey;
    } 
    else {
        $NameKey = $CounterType.ToString()
        if ($CounterGroup -ne $null) {
            $GroupKey = $CounterGroup.ToString()
        }
    }

    $WhereScriptFilers = @('$_.NameKey -eq $NameKey')
    if (-not [String]::IsNullOrEmpty($GroupKey)) {
        $WhereScriptFilers += '$_.GroupKey -eq $GroupKey'
    }
    if (-not [String]::IsNullOrEmpty($Object)) {
        $WhereScriptFilers += '$_.Object -eq $Object'
    }
    $WhereScriptFilers = [string]::Join(' -and ', $WhereScriptFilers)
    $WhereScript = [scriptblock]::Create($WhereScriptFilers)    

    $Result = @{}
    
    $TestedCounters = $Counters.Where($WhereScript)
    if ($TestedCounters.Count -eq 0) {
        $Result.OK = $false
        $Result.Msg = 'No counter: ' + (Format-PmCounter -Name $NameKey -Group $GroupKey -Object $Object)

    }

    $TresholdExceededCounters = $TestedCounters.Where($Script)
    
    $Result = @{}
    $Result.Counters = $TestedCounters
    $Result.TresholdExceededCounters = $TresholdExceededCounters
    $Result.OK = ($TresholdExceededCounters.Count -eq 0)

    $Msg = @()
    if (-not -$Result.OK) {
        
        $MsgTmpl = 'Counter "&Counter" - "&Threshold": avg &Avg, min &Min, max &Max at &BeginTime-&EndTime.'

        $ScriptText = $Script.ToString().Replace('$_.', '')
        foreach ($ExcdCounter in $TresholdExceededCounters) {
            
            $ExcdInfo = @{}
            $ExcdInfo.Counter = Format-PmCounter -InputObject $ExcdCounter
            $ExcdInfo.Threshold = $ScriptText
            $ExcdInfo.BeginTime = $ExcdCounter.Begin.ToString('HH:mm:ss')
            $ExcdInfo.EndTime = $ExcdCounter.End.ToString('HH:mm:ss')
            $ExcdInfo.Avg = Format-AuxPmNumber -Number $ExcdCounter.Avg
            $ExcdInfo.Min = Format-AuxPmNumber -Number $ExcdCounter.Min
            $ExcdInfo.Max = Format-AuxPmNumber -Number $ExcdCounter.Max

            $CounterMsg = $MsgTmpl
            foreach ($InfoKey in $ExcdInfo.Keys) {$CounterMsg = $CounterMsg.Replace('&' + $InfoKey, $ExcdInfo.$InfoKey)}

            $Msg += $CounterMsg

        }
    }
    $Result.Msg = [String]::Join("`n", $Msg)

    $Result
}

function Find-PmCounter($Name, $Group) {
    
    $CountersTable = Get-PmCountersTable
    if (-not [String]::IsNullOrEmpty($Group)) {
        $FindedCounter = $CountersTable.Where({($_.Name -eq $Name) -and ($_.Group -eq $Group)})
    }
    else {
        $FindedCounter = $CountersTable.Where({($_.Name -eq $Name)})
    }

    if ($FindedCounter.Count -eq 0) {
        return $null
    }

    $NameKey = $FindedCounter[0].NameKey
    $GroupKey = $FindedCounter[0].GroupKey

    (Get-PmCountersHashtable).($GroupKey).($NameKey)
}

function Format-PmCounter($Name, $Group, $Object, $InputObject) {
    
    if ($InputObject -ne $null) {
        $Name = $InputObject.Name
        $Group = $InputObject.Group
        $Object = $InputObject.Object
    }

    $ObjectDescr = ''
    if (-not [String]::IsNullOrEmpty($Object)) {
        $ObjectDescr = '(' + $Object + ')'
    } 
    $Group + $ObjectDescr + '\' + $Name
}

####
# COUNTERS FROM CSV-FILES
####

<#
 .Synopsis
  Get from csv-files counters list and its values list, average, minimum and maximum value.

 .Description
  Return hashtable with kyes:
  - Counters - list of counters in csv-files: Name, Group, Object FullName, Key (in the values table).
  - Values - list of values by datetime - KNNN (from counter.Key)
  

 .Parameter Files
  Array of csv-files full names.

 .Parameter Begin
  Filter by begin date 

 .Parameter End
  Filter by end date

 .Parameter ReturnValues
  Specify necessity to return values list of counters

 .Parameter OnlyCountersList
  Specify necessity to calculate min, max, avg values - read only headers csv-fiels.

 .Example
   # Show average counters value form csv-file.
   (Get-PmCountersFromCsv -Files c:\counters.csv).Counters | Format-Table -Property Name, Object, Avg | Out-Host

#>
function Get-PmCountersFromCsv {
    param (
        $Files,
        $Begin,
        $End,
        [switch]$ReturnValues,
        [switch]$OnlyCountersList
    )

    $FileNames = @()
    foreach ($FileItem in $Files) {
        if ($FileItem -is [String]) {
            $FileNames += $FileItem
        } 
        else {
            $FileNames += $FileItem.FullName
        }
    }

    $CounterList = @()
    $CounterValues = @()
    $CounterBegin = $null
    $CounterEnd = $null

    # Counters each file
    $FilesCounterList = @()

    # Get counters list and relations between general counters and counters each file.
    foreach ($File in $FileNames) {

        $CurCounterList = $File | Get-PmCountersListFromCsvHead
        $CurCounterListCount = $CurCounterList.CounterCount

        for ($Index = 0; $Index -lt $CurCounterListCount; $Index++) {

            $CurCounter = $CurCounterList.CounterList[$Index]
            $Counter = $CounterList.Where({$_.FullName -eq $CurCounter.FullName})
            if ($Counter.Count -gt 0) {
                $Counter = $Counter[0]
            }
            else {
                $CounterDescr = Find-PmCounter -Name $CurCounter.Name -Group $CurCounter.Group
                $CounterKey = if ($CurCounter.Name -eq 'datetime') {'datetime'}
                else {'K' + $CounterList.Count.ToString().PadLeft(3, '0')}
                $Counter =@{
                    Index = $CounterList.Count;
                    FullName = $CurCounter.FullName;
                    Name = $CurCounter.Name;
                    Host = $CurCounter.Host;
                    Group = $CurCounter.Group;
                    Object = $CurCounter.Object;
                    NameKey = $CounterDescr.NameKey;
                    GroupKey = $CounterDescr.GroupKey;
                    Key = $CounterKey;
                    Begin = $null;
                    End = $null;
                    Min = 0;
                    Max = 0;
                    Avg = 0;
                }
                $Counter = New-Object PSCustomObject -Property $counter
                $CounterList += $Counter
            }

            $FileCounter =@{
                File = $File;
                Index = $CurCounter.Index;
                CounterIndex = $Counter.Index;
            }

            $FilesCounterList += New-Object PSCustomObject -Property $FileCounter
        }

    }

    $FilesCounterList = $FilesCounterList | Select-Object -Property File, Index, CounterIndex -Unique

    if (-not $OnlyCountersList) {

        # Init values hashtable structure.
        $Values = @{datetime = $null}
        $CounterList | % {$Values.($_.Key) = 0}

        # Read values from CSV files.
        foreach ($File in $FileNames) {

            $FileCounters = $FilesCounterList.Where({$_.File -eq $File})
            $FileCountersCount = $FileCounters.Count

            $Content = Get-Content -Path $File

            $FirstLine = $true
            foreach ($ValuesLine in $Content) {

                if ($FirstLine) {
                    $FirstLine = $false
                    continue
                }

                $ValuesArray = $ValuesLine.Split(',')

                # datetime and checkperiod
                $datetime = Get-AuxPmLogDateTime -Value (Remove-AuxPmQuotes -Value $ValuesArray[0])
                if (($Begin -ne $null) -and ($datetime -lt $Begin)) {continue}
                if (($End -ne $null) -and ($datetime -gt $End)) {break}
                $Values.datetime = $datetime

                # read counters
                foreach ($FileCounter in $FileCounters) {
                    $Counter = $CounterList.Where({$_.Index -eq $FileCounter.CounterIndex})[0]
                    $CounterValue = Remove-AuxPmQuotes -Value $ValuesArray[$FileCounter.Index]
                    $Values.($Counter.Key) = [double]($CounterValue.Trim())
                }

                $CounterValues += (New-Object PSCustomObject -Property $Values)
            }
        }

        #  Calculate Avg, Min, Max values.
        $Keys = @()
        $CounterList | Where-Object -Property Name -NE -Value datetime | % {$Keys += $_.Key}
        $Measures = $CounterValues | Measure-Object -Property $Keys -Average -Maximum -Minimum

        $MeasuresDatetime = $CounterValues | Measure-Object -Property 'datetime' -Minimum -Maximum
        $CounterBegin = $MeasuresDatetime.Minimum
        $CounterEnd = $MeasuresDatetime.Maximum

        foreach ($Counter in $CounterList) {
            $MeasureValues = $Measures | Where-Object -Property Property -EQ -Value $Counter.Key | Select-Object -First 1
            $Counter.Max = $MeasureValues.Maximum
            $Counter.Min = $MeasureValues.Minimum
            $Counter.Avg = $MeasureValues.Average
            $Counter.Begin = $CounterBegin
            $Counter.End = $CounterEnd
        }

    } # -not $OnlyCountersList

    $Return = @{}
    $Return.Counters = $CounterList
    $Return.Begin = $CounterBegin
    $Return.End = $CounterEnd
    
    if ($ReturnValues -and -not $OnlyCountersList) {
        $Return.Values = $ReturnValues
        $ReturnValues = $null
    }

    $Return
}

function Get-PmCountersListFromCsvHead {
    param(
        [string]$File
    )

    begin {
        [object[]]$CounterListFromCsv = @()
    }

    process {
        
        if (-not [String]::IsNullOrEmpty($_)) {
            $File = $_
        }

        if (-not [String]::IsNullOrEmpty($File)) {

            $HeadLine = Get-Content -Path $File -TotalCount 1
            $Heads = $HeadLine.Split(',')
            $HeadsCount = $Heads.Count

            for ($Index = 1; $Index -lt $HeadsCount; $Index++) {
                $CounterFullName = Remove-AuxPmQuotes -Value $Heads[$Index]
                $Counter = @{Index = $Index; FullName = $CounterFullName; Name = ''; Host = ''; Group = ''; Object = ''}
                Get-PmCounterPropertyFromFullName -CounterFullName $CounterFullName -Counter $Counter
                $CounterListFromCsv += (New-Object PSCustomObject -Property $Counter)
            }

        } # in not empty $File
    } # end process

    end {
        @{CounterList = $CounterListFromCsv; CounterCount = $CounterListFromCsv.Count}
    }
}

function Get-PmCounterPropertyFromFullName($CounterFullName, $Counter) {
    
    if ($Counter -eq $null) {
        $Counter = @{}
    }

    $CounterParts = $CounterFullName.Split('\')

    $PartsCount = $CounterParts.Count
    $Counter.Name = $CounterParts[$PartsCount - 1]

    if ($PartsCount -ge 3) {
        $Counter.Group = $CounterParts[$PartsCount - 2]
        $Counter.Host = $CounterParts[$PartsCount - 3]
    }
    elseif ($PartsCount -ge 2) {
        $Counter.Group = $CounterParts[$PartsCount - 2]
    }

    if ($Counter.Group -match '^(.+)\((.+)\)$') {
        $Counter.Group = $Matches.1
        $Counter.Object = $Matches.2
    }

    $Counter
}

####
# COUNTERS LIST
####

function Get-PmCountersHashtable {

    if ($Script:CountersHashtable -ne $null) {
        return $Script:CountersHashtable
    }
    
    $CountersTable = Get-PmCountersTable

    $Counters = @{}
    
    $GroupsKeys = $CountersTable | Select-Object -Property GroupKey -Unique | Sort-Object -Property GroupKey
    foreach ($GroupItem in $GroupsKeys) {
        
        $GroupCounters = $CountersTable.Where({$_.GroupKey -eq $GroupItem.GroupKey})

        $GroupCountersNotDisp = $GroupCounters.Where({-not $_.IsDisplay})
        $GroupCountersIsDisp = $GroupCounters.Where({$_.IsDisplay})

        $Group = @{}
        foreach ($CounterItem in $GroupCountersNotDisp) {
            $DispCounterItem = $GroupCountersIsDisp.Where({$_.NameKey -eq $CounterItem.NameKey})    
            $Group.($CounterItem.NameKey) = @{
                NameKey = $CounterItem.NameKey;
                GroupKey = $GroupItem.GroupKey;
                Name = $CounterItem.Name;
                Group = $CounterItem.Group;
                DisplayName = $DispCounterItem[0].Name;
                DisplayGroup = $DispCounterItem[0].Group; 
            }
        }
        $Counters.($GroupItem.GroupKey) = New-Object PSCustomObject -Property $Group        
    }

    $Script:CountersHashtable = $Counters
    $Script:CountersHashtable
}

function Get-PmCountersTable {
    if ($Script:PmCountersTable -ne $null) {return $Script:PmCountersTable}
    $Script:PmCountersTable = (Get-Content -Path (Get-AuxPmCountersFile)) | ConvertFrom-Json 
    $Script:PmCountersTable
}

function Update-PmCountersTable($FilePath, $CounterGroupName) {

    $CurCountersTalbe = Get-PmCountersTable

    $CountersTable = Get-PmLogmanCountersFromCounterGroup -FilePath $FilePath -CounterGroupName $CounterGroupName

    $IsChanged = $false

    $WhereScript = {
        $_.Name -eq $Counter.Name `
        -and $_.NameKey -eq $Counter.NameKey `
        -and $_.Group -eq $Counter.Group `
        -and $_.GroupKey -eq $Counter.GroupKey
    }

    foreach ($Counter in $CountersTable) {
        $FinedCounters = $CurCountersTalbe.Where($WhereScript)
        if ($FinedCounters.Count -eq 0) {
            $IsChanged = $true
            $CurCountersTalbe += $Counter
        }
    }

    if ($IsChanged) {
        $CurCountersTalbe | ConvertTo-Json | Out-File -FilePath (Get-AuxPmCountersFile)
        $Script:PmCountersTable = $null
    }
}

function Get-PmCounterNameKey([String]$Name) {
    
    if ($Name.Contains('%')) {$Name = $Name.Replace('%', 'Pct ')}
    if ($Name.Contains('/')) {$Name = $Name.Replace('/', 'Per ')}

    $KeyParts = @()

    $NameParts = [regex]::Replace($Name, '\W+', ' ').Split(' ')
    foreach ($NamePart in $NameParts) {
        $KeyParts += ($NamePart.Substring(0, 1).ToUpper() + $NamePart.Substring(1))
    }

    [String]::Join('', $KeyParts)
}

function Add-AuxPmEnumCounterTypes {
    $EnumValues = @()
    Get-PmCountersTable | Select-Object -Property NameKey -Unique | Sort-Object -Property NameKey | % {$EnumValues += $_.NameKey}
    Add-AuxPmEnumType -EnumName 'PmCounterTypes' -ValueNames $EnumValues
}

function Add-AuxPmEnumCounterGroups {
    $EnumValues = @()
    Get-PmCountersTable | Select-Object -Property GroupKey -Unique | Sort-Object -Property GroupKey | % {$EnumValues += $_.GroupKey}
    Add-AuxPmEnumType -EnumName 'PmCounterGroups' -ValueNames $EnumValues
}

function Get-AuxPmCountersFile {
    $PSScriptRoot + '\counters.json'
}

####
# LOGMAN
####

function Get-PmLogmanCountersFromCounterGroup($FilePath, $CounterGroupName) {

    $DeleteFile = $false

    if (-not [String]::IsNullOrEmpty($CounterGroupName)) {
        if ([String]::IsNullOrEmpty($FilePath)) {
            $FilePath = [System.IO.Path]::GetTempFileName() + '-ExportCounters-' + $CounterGroupName + '.xml'
            $DeleteFile = $true
        }
        $Result = Export-PmLogmanCounterGroup -Name $CounterGroupName -XMLFile $FilePath
        if (-not $Result.OK) {
            return $null
        }
    }

    $XmlDoc = New-Object System.Xml.XmlDocument
    $XmlDoc.Load($FilePath)

    $DataCollector = $XmlDoc.DataCollectorSet.PerformanceCounterDataCollector
    $Counters = $DataCollector.Counter
    $ConttersDisplay = $DataCollector.CounterDisplayName
    $CountersCount = $Counters.Count

    $CountersTable = @()


    for ($Index = 1; $Index -lt $CountersCount; $Index++) {

        $CounterFullName = $Counters[$Index]
        $CounterDispFullName = $ConttersDisplay[$Index]

        if ([String]::IsNullOrEmpty($CounterFullName) -or [String]::IsNullOrEmpty($CounterDispFullName)) {
            continue
        }

        $Counter = Get-PmCounterPropertyFromFullName -CounterFullName $CounterFullName
        $CounterDisp = Get-PmCounterPropertyFromFullName -CounterFullName $CounterDispFullName

        $CounterType = @{
            Group = $Counter.Group;
            Name = $Counter.Name;
            GroupKey = Get-PmCounterNameKey -Name $Counter.Group;
            NameKey = Get-PmCounterNameKey -Name $Counter.Name;
            IsDisplay = $false;
        }
        $CountersTable += New-Object PSCustomObject -Property $CounterType

        $CounterDispType = @{
            Group = $CounterDisp.Group;
            Name = $CounterDisp.Name;
            GroupKey = $CounterType.GroupKey;
            NameKey = $CounterType.NameKey;
            IsDisplay = $true;
        }
        $CountersTable += New-Object PSCustomObject -Property $CounterDispType

    }

    if ($DeleteFile) {
        Remove-Item -Path $FilePath
    }

    $CountersTable | Select-Object -Property Group, Name, GroupKey, NameKey, IsDisplay -Unique
}

function New-PmLogmanCounterGroup{
    param (
        $Name,
        $Counters,
        [ValidateSet('bin', 'bincirc', 'csv', 'tsv', 'sql')]
        $Format,
        $SelectionInterval,
        $SelectionCount
    )

    $CountersString = ''
    foreach ($CounterPath in $Counters) {
        if (-not [String]::IsNullOrWhiteSpace($CounterPath)) {
            $CountersString = $CountersString + ' "' + $CounterPath + '"'
        }
    }

    if ($SelectionInterval -is [TimeSpan]) {
        $SelectionInterval = ([TimeSpan]$SelectionInterval).ToString('c')
    }

    $Parameters = @{
        name = '"' + $Name + '"';
        c = $CountersString;
        f = $Format;
        si = $SelectionInterval;
        y = $true;
    }

    if ($SelectionCount -ne $null) {
        $Parameters.sc = $SelectionCount
    }

    Invoke-PmLogmanCommand -Verb create -Adverb counter -Parameters $Parameters

}

function Export-PmLogmanCounterGroup ($Name, $XMLFile) {

    $Parameters = @{
        name = $Name;
        xml = $XMLFile;
    }

    $Parameters = Get-AuxPmParametersString -Parameters $Parameters -RoundValueSign '"'
    Invoke-PmLogmanCommand -Verb export -Parameters $Parameters
}

function Import-PmLogmanCounterGroup ($Name, $XMLFile) {

    $Parameters = @{
        name = $Name;
        xml = $XMLFile;
    }

    $Parameters = Get-AuxPmParametersString -Parameters $Parameters -RoundValueSign '"'
    Invoke-PmLogmanCommand -Verb import -Parameters $Parameters
}

function Invoke-PmLogmanCommand {
    param (
        [ValidateSet('create', 'query', 'start', 'stop', 'delete', 'update', 'import', 'export')]
        $Verb,
        [ValidateSet('counter', 'trace', 'alert', 'cfg', 'providers')]
        $Adverb,
        $Parameters,
        $WorkDir,
        [switch]$CreateErrorCmdFile
    )
    $ArgsStr = $Verb + (Get-AuxPmLogmanParameters -Parameters $Adverb) + (Get-AuxPmLogmanParameters -Parameters $Parameters)
    Invoke-AuxCommand -Command 'logman' -ArgumentList $ArgsStr -WorkDir $WorkDir -CreateErrorCmdFile:$CreateErrorCmdFile
}

####
# RELOG
####

function Find-PmRelogErrorBinFiles($Path) {
    $ErrorBinFiles = @()
    $LogFiles = Get-ChildItem -Path $Path -Recurse -Filter '*.blg' 
    foreach ($LogFile in $LogFiles) {
        $TempFile = [System.IO.Path]::GetTempFileName() + '.blg'
        $Result = Invoke-PmRelogBinFiles -InputFiles $LogFile.FullName -OutPath $TempFile -RecordsInterval 4096
        if (Test-Path -Path $TempFile) {
            Remove-Item -Path $TempFile
        }
        if ($Result.ExitCode -ne 0) {
            $ErrorBinFiles += $LogFile.FullName
        }
    }
    $ErrorBinFiles
}

function Invoke-PmRelogBinFiles {
    
    param (
        $InputFiles,
        $RecordsInterval,
        $OutPath,
        $WorkDir,
        [switch]$CreateErrorCmdFile
    )

    $MaxFiles = 32

    if ($InputFiles -is [System.Array] -and $InputFiles.Count -gt $MaxFiles) {

        $NewInputFiles = @()
        $Buffers = @()
        $CurrBuffer = @()
        $TempFiles = @()

        foreach ($LogFile in $InputFiles) {
            if ($CurrBuffer.Count -lt $MaxFiles) {
                $CurrBuffer += $LogFile
            }
            else {
                $Buffers += @{buff = $CurrBuffer}
                $CurrBuffer = @() # clear buffer
            }        
        }
        if ($CurrBuffer.Count -gt 0) {
            $Buffers += @{buff = $CurrBuffer}
            $CurrBuffer = @() # clear current buffer
        }

        foreach ($BufferItem in $Buffers) {
            $OutDir = [System.IO.Path]::GetDirectoryName($OutPath)
            $OutName = [System.IO.Path]::GetFileNameWithoutExtension($OutPath)
            $NewTempFile = [System.IO.Path]::Combine($OutDir, $OutName + '-' + (Get-Date).ToString('HHmmss-fff') + '-tmp.blg')                                
            $CurrReturn = Invoke-PmRelogBinFiles -InputFiles $BufferItem.buff -RecordsInterval $RecordsInterval -OutPath $NewTempFile -WorkDir $WorkDir -CreateErrorCmdFile:$CreateErrorCmdFile
            if ($CurrReturn.ExitCode -eq 0) {
                $TempFiles += $NewTempFile
            }
        }

        $Return = Invoke-PmRelogBinFiles -InputFiles $TempFiles -OutPath $OutPath -WorkDir $WorkDir  -CreateErrorCmdFile:$CreateErrorCmdFile

        foreach ($TempFile in $TempFiles) {
            Remove-Item -Path $TempFile
        }

    }
    else {
        $Return = Invoke-PmRelogCommand -InputFiles $InputFiles -RecordsInterval $RecordsInterval -OutPath $OutPath -WorkDir $WorkDir -OutFormat BIN  -CreateErrorCmdFile:$CreateErrorCmdFile
    }

    $Return
}

function Invoke-PmRelogCommand {
    param (
        $InputFiles,
        [switch]$AddToExistFile,
        $InputCounters,
        $InputCountersFile,
        [ValidateSet('CSV', 'TSV', 'BIN', 'SQL')]
        $OutFormat,
        $RecordsInterval,
        $OutPath,
        $Begin,
        $End,
        $ConfigFile,
        [switch]$CountersListInInput,
        $WorkDir,
        [switch]$CreateErrorCmdFile
    )

    # https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/relog

    # RecordsInterval - Specifies sample intervals in "N" records.
    # Includes every nth data point in the relog file. Default is every data point

    $ArgsStr = Get-AuxPmParameterValueString -ParamVal $InputFiles -RoundValueSign '"'

    $Begin = Get-AuxPmParameterValueString -ParamVal $Begin -NullIfNull
    $End = Get-AuxPmParameterValueString -ParamVal $End -NullIfNull

    $TArgs = [ordered]@{
        a = $AddToExistFile;
        c = $InputCounters;
        cf = $InputCountersFile;
        f = $OutFormat;
        t = $RecordsInterval;
        o = $OutPath;
        b = $Begin;
        e = $End;
        config = $ConfigFile;
        q = $CountersListInInput;
        y = $true
    }

    $ArgsStr = $ArgsStr + ' ' + (Get-AuxPmRelogParameters -Parameters $TArgs)
    
    Invoke-AuxCommand -Command 'relog' -ArgumentList $ArgsStr -OutPath $OutPath -WorkDir $WorkDir -CreateErrorCmdFile:$CreateErrorCmdFile
}


####
# TASKS
####

function New-PmTaskMonitorAlert {
    param (
        [String]$SendMsgScript = 'c:\scripts\send-slackmsg'
    )

    $ActionAgrs = '-f "' + $SendMsgScript + '" $(Arg0)'
    $Action = New-ScheduledTaskAction -Execute 'PowerShell' -Argument $ActionAgrs

 
    $Settings = New-ScheduledTaskSettingsSet
    $Principal = New-ScheduledTaskPrincipal -UserId 'LOCALSERVICE'

    $Task = New-ScheduledTask -Action $Action -Description 'Sends alert message by send-message-script.' -Principal $Principal -Settings $Settings
  
    Register-ScheduledTask 'MonitorAlert' -InputObject $Task -TaskPath '\PmAlerts'
}

function New-PmTaskIamAliveAlert {
    param (
        [String]$SendMsgScript = 'c:\scripts\send-slackmsg',
        [DateTime]$At = [DateTime]::new(2000, 1, 1, 8, 0, 0)
    )

    $ActionAgrs = '-f "' + $SendMsgScript + '" "I''am alive!"'
    $Action = New-ScheduledTaskAction -Execute 'PowerShell' -Argument $ActionAgrs

    $Trigger = New-ScheduledTaskTrigger -At $At -Daily
 
    $Settings = New-ScheduledTaskSettingsSet
    $Principal = New-ScheduledTaskPrincipal -UserId 'LOCALSERVICE'

    $Task = New-ScheduledTask -Action $Action -Description 'Sends alert message by send-message-script.' -Principal $Principal -Settings $Settings -Trigger $Trigger
  
    Register-ScheduledTask 'IamAliveAlert' -InputObject $Task -TaskPath 'PmAlerts'
}

####
# AUXILIARY
####

function Get-AuxPmLogmanParameters($Parameters, $RoundValueSign = '') {
    Get-AuxPmParametersString -Parameters $Parameters -RoundValueSign $RoundValueSign -UseSwitchOffParameters $true
}

function Get-AuxPmRelogParameters($Parameters, $RoundValueSign = '') {
    Get-AuxPmParametersString -Parameters $Parameters -RoundValueSign $RoundValueSign -UseSwitchOffParameters $false
}

function Get-AuxPmParametersString($Parameters, $RoundValueSign = '', $UseSwitchOffParameters = $true) {
    $ParamStr = ''
    if (Test-AuxPmHashTable -Object $Parameters) {
        foreach ($ParamKey in $Parameters.Keys) {
            $ParamVal = $Parameters[$ParamKey]
            if ($ParamVal -eq $null ) {}
            elseif ($ParamVal -is [boolean] -or $ParamVal -is [switch]) { 
                if ($ParamVal) {$ParamStr = $ParamStr + ' -' + $ParamKey}
            }
            elseif ($ParamVal -is [boolean] -and $ParamVal -eq $false) {
                $ParamStr = $ParamStr + ' --' + $ParamKey # switch-off parameter
            }
            else {
                $ParamStr = $ParamStr + ' -' + $ParamKey + ' ' + (Get-AuxPmParameterValueString -ParamVal $ParamVal -RoundValueSign $RoundValueSign)
            }  
        }
    }
    else {
        $ParamStr = ' ' + [string]$Parameters
    }
    $ParamStr
}

function Get-AuxPmParameterValueString($ParamVal, $RoundValueSign = '', [switch]$NullIfNull) {
    $ParamValString = ''
    if ($ParamVal -eq $null) {
        if ($NullIfNull) {
            $ParamValString = $null
        }
    }
    elseif ($ParamVal -is [System.Array]) {
        foreach ($ArrItem in $ParamVal) {
            $ParamValString = $ParamValString + ' ' + $RoundValueSign + $ArrItem + $RoundValueSign
        }
    }
    elseif ($ParamVal -is [datetime]) {
        $ParamValString = $ParamVal.ToString()
    }
    else {
        $ParamValString = $RoundValueSign + $ParamVal + $RoundValueSign
    }  
    $ParamValString
}

function Remove-AuxPmQuotes([String]$Value) {
    if ($Value.StartsWith('"') -and $Value.EndsWith('"')) {
        $Value = $Value.Substring(1, $Value.Length - 2)
    }
    $Value
}

function Get-AuxPmLogDateTime($Value) {
    $Pattern = '^(\d{2})\/(\d{2})\/(\d{4}) (\d{2})\:(\d{2})\:(\d{2})\.(\d{3})$'
    if ($Value -match $Pattern) {
        $Date = Get-Date -Year $Matches.3 -Month $Matches.1 -Day $Matches.2 -Hour $matches.4 -Minute $matches.5 -Second $matches.6 -Millisecond $matches.7
    }
    else {
        $Date = $null
    }
    $Date
}

function Test-AuxPmHashTable ($Object) {
    if ($Object -eq $null) {return $false}
    # Is HashTable or OrderedDictionary
    (($Object -is [hashtable]) -or ($Object -is [System.Object] -and $Object.GetType().name -eq 'OrderedDictionary'))
}

function Invoke-AuxCommand($Command, $ArgumentList, $Process, $OutPath, $WorkDir, [switch]$CreateErrorCmdFile) {

    if ([String]::IsNullOrEmpty($WorkDir)) {
        $Process = Start-Process -FilePath $Command -ArgumentList $ArgumentList -Wait -WindowStyle Hidden -Verbose -PassThru
    }
    else {
        $Process = Start-Process -FilePath $Command -ArgumentList $ArgumentList -Wait -WindowStyle Hidden -Verbose -PassThru -WorkingDirectory $WorkDir 
    }

    if ([String]::IsNullOrEmpty($OutPath)) {
        if (-not [String]::IsNullOrEmpty($WorkDir)) {
            $OutPath = $WorkDir + '\' + $Command
        } 
        else {
            $OutPath = $env:TEMP + '\' + $Command
        }
     
    }

    $Result = @{}
    $Result.Process = $Process
    $Result.Cmd = $Command + ' ' + $ArgumentList
    $Result.OK = ($Process.ExitCode -eq 0)
    $Result.ExitCode = $Process.ExitCode
    $Result.Msg = ''

    if ($Process.ExitCode -ne 0 -and $CreateErrorCmdFile) {
        $ErrorCmdFile = $OutPath + '_Error.cmd'
        $Result.Cmd | Out-File -FilePath $ErrorCmdFile -Encoding ascii
        'pause' | Out-File -FilePath $ErrorCmdFile -Encoding ascii -Append
        $Result.Msg = 'Error. See command file ' + $ErrorCmdFile
        $Result.Msg | Out-Host
    }

    $Result
}

function Add-AuxPmEnumType ($EnumName, $ValueNames) {

    $EnumNames = $ValueNames.Where({-not [String]::IsNullOrEmpty($_)}) 
    if ($EnumNames.Count -eq 0) {
        return $false
    }
    
    $EnumNames = ($EnumNames | Select-Object -Unique | Sort-Object)

    $DefScript = @()
    $DefScript += 'public enum ' + $EnumName + '{'
    $DefScript += [String]::Join(",`n", $EnumNames)
    $DefScript += '}'

    Add-Type -TypeDefinition ([String]::Join("`n", $DefScript))

    $True
}

function Format-AuxPmNumber($Number) {
    
    if ($Number -eq 0 -or $Number -eq $null) {
        return '0'
    }

    $K = [math]::Pow(10, [math]::Round([math]::Log10($Number)) - 1) 
    if ($K -le 10) {
        $RoundedNumber = [math]::Round($Number / $K, 1) * $K
    }
    else {
        $RoundedNumber = [math]::Round($Number, 0)
    }

    $RoundedNumber.ToString().Replace(',', '.')
}

####
# INIT MODULE
####

Add-AuxPmEnumCounterTypes
Add-AuxPmEnumCounterGroups
