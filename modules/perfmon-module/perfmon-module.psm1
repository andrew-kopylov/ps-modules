
function Get-PmLogCountersFromCsv($Files, $BeginDate, $EndDate) {

    $CounterList = @()
    $CounterValues = @()

    $FilesCounterList = @()

    foreach ($File in $Files) {

        $CurrentCounterList = Get-PmLogCountersListFromCsvHead -HeadLine (Get-Content -Path $File -TotalCount 1)

        foreach ($CurrentCounter in $CurrentCounterList) {
            
            $Counter = $CounterList.Where({$_.FullName -eq $CurrentCounter.FullName})
            if ($Counter.Count -gt 0) {
                $Counter = $Counter[0]
            }
            else {
                $Counter =@{
                    Index = $CounterList.Count;
                    FullName = $CurrentCounter.FullName;
                    Name = $CurrentCounter.Name;
                    Host = $CurrentCounter.Host;
                    Group = $CurrentCounter.Group;
                    Object = $CurrentCounter.Object;
                    Key = 'K' + $CounterList.Count.ToString().PadLeft(3, '0');
                    Min = 0;
                    Max = 0;
                    Avg = 0;
                }
                $Counter = New-Object PSCustomObject -Property $counter
                $CounterList += $Counter
            }

            $FileCounter =@{
                File = $File;
                Index = $CurrentCounter.Index;
                CounterIndex = $Counter.Index;
            }

            $FilesCounterList += New-Object PSCustomObject -Property $FileCounter

        }

    }

    # Init values hashtable structure.
    $Values = @{}
    $CounterList | % {$Values.($_.Key) = 0}

    foreach ($File in $Files) {

        $FileCounters = $FilesCounterList.Where({$_.File -eq $File})

        $Content = Get-Content -Path $File

        $FirstLine = $true
        foreach ($ValuesLine in $Content) {

            if ($FirstLine) {
                $FirstLine = $false
                continue
            }

            $ValuesObject = New-Object PSCustomObject -Property $Values

            $ValuesArray = $ValuesLine.Split(',')
            foreach ($FileCounter in $FileCounters) {
                $Counter = $CounterList.Where({$_.Index -eq $FileCounter.CounterIndex})[0]
                $CounterValue = Remove-PmQuotes -Value $ValuesArray[$FileCounter.Index]
                if ($Counter.Name -eq 'datetime') {
                    $CounterValue = Get-PmLogDateTime -Value $CounterValue 
                }
                else {
                    $CounterValue = [double]($CounterValue.Trim())
                }           
                $ValuesObject.($Counter.Key) = $CounterValue
            }

            $CounterValues += $ValuesObject
        
        } 

    }

    $DateTimeKey = $CounterList.Where({$_.Name -eq 'datetime'})[0].Key
    $Keys = @()
    $CounterList | Where-Object -Property Name -NE -Value datetime | % {$Keys += $_.Key}
    $Measures = $CounterValues | Measure-Object -Property $Keys -Average -Maximum -Minimum
    $Measures += ($CounterValues | Measure-Object -Property $DateTimeKey -Maximum -Minimum)
    foreach ($Counter in $CounterList) {
        $MeasureValues = $Measures | Where-Object -Property Property -EQ -Value $Counter.Key | Select-Object -First 1
        $Counter.Max = $MeasureValues.Maximum
        $Counter.Min = $MeasureValues.Minimum
        $Counter.Avg = $MeasureValues.Average
    }

    @{Counters = $CounterList; Values = $CounterValues}
}

function Get-PmLogCountersListFromCsvHead([String]$HeadLine) {

    $Heads = $HeadLine.Split(',')
    $FirstCounter = $true

    $CounterList = @()

    $Index = -1

    foreach ($CounterFullName in $Heads) {

        $CounterFullName = Remove-PmQuotes -Value $CounterFullName
        $Index += 1
        
        $Counter = @{Index = $Index; FullName = $CounterFullName; Name = ''; Host = ''; Group = ''; Object = '';}

        if ($FirstCounter) {
            $FirstCounter = $false
            $Counter.Name = 'datetime'
            $CounterList += New-Object PSCustomObject -Property $Counter
            continue
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

        $CounterList += New-Object PSCustomObject -Property $Counter        
    }

    $CounterList
}

function Remove-PmQuotes([String]$Value) {
    if ($Value.StartsWith('"') -and $Value.EndsWith('"')) {
        $Value = $Value.Substring(1, $Value.Length - 2)
    }
    $Value
}

function Get-PmLogDateTime($Value) {
    $Pattern = '^(\d{2})\/(\d{2})\/(\d{4}) (\d{2})\:(\d{2})\:(\d{2})\.(\d{3})$'
    if ($Value -match $Pattern) {
        $Date = Get-Date -Year $Matches.3 -Month $Matches.2 -Day $Matches.1 -Hour $matches.4 -Minute $matches.5 -Second $matches.6 -Millisecond $matches.7
    }
    else {
        $Date = $null
    }
    $Date
}

function New-PmLogCounter{
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

function Export-PmLogGroup ($Name, $XMLFile) {

    $Parameters = @{
        name = $Name;
        xml = $XMLFile;
    }

    $Parameters = Get-PmParametersString -Parameters $Parameters -RoundValueSign '"'

    Invoke-PmLogmanCommand -Verb export -Parameters $Parameters

}

function Import-PmLogGroup ($Name, $XMLFile) {

    $Parameters = @{
        name = $Name;
        xml = $XMLFile;
    }

    $Parameters = Get-PmParametersString -Parameters $Parameters -RoundValueSign '"'

    Invoke-PmLogmanCommand -Verb import -Parameters $Parameters
}

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

    $ArgsStr = Get-PmParameterValueString -ParamVal $InputFiles -RoundValueSign '"'

    $Begin = Get-PmParameterValueString -ParamVal $Begin -NullIfNull
    $End = Get-PmParameterValueString -ParamVal $End -NullIfNull

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

    $ArgsStr = $ArgsStr + ' ' + (Get-PmRelogParameters -Parameters $TArgs)
    
    if ([String]::IsNullOrEmpty($WorkDir)) {
        $Process = Start-Process -FilePath 'relog' -ArgumentList $ArgsStr -Wait -WindowStyle Hidden -Verbose -PassThru
    }
    else {
        $Process = Start-Process -FilePath 'relog' -ArgumentList $ArgsStr -Wait -WindowStyle Hidden -Verbose -PassThru -WorkingDirectory $WorkDir
    }

    if ($Process.ExitCode -ne 0 -and $CreateErrorCmdFile) {
        $ErrorCmdFile = $OutPath + '_Error.cmd'
        ('relog ' + $ArgsStr) | Out-File -FilePath $ErrorCmdFile -Encoding ascii
        ('pause') | Out-File -FilePath $ErrorCmdFile -Encoding ascii -Append
        'Error create output file: ' + $OutPath + ' see command file ' + $ErrorCmdFile | Out-Host
    }

    $Process
}

function Invoke-PmLogmanCommand {
    param (
        [ValidateSet('create', 'query', 'start', 'stop', 'delete', 'update', 'import', 'export')]
        $Verb,
        [ValidateSet('counter', 'trace', 'alert', 'cfg', 'providers')]
        $Adverb,
        $Parameters        
    )
    $ArgsStr = $Verb + (Get-PmParametersString -Parameters $Adverb) + (Get-PmParametersString -Parameters $Parameters)
    $Ret = Start-Process -FilePath 'logman' -ArgumentList $ArgsStr -Wait -NoNewWindow -Verbose
}

function New-PmMonitorAlertTask {
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

function New-PmIamAliveAlertTask {
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

function Get-PmLogmanParameters($Parameters, $RoundValueSign = '') {
    Get-PmParametersString -Parameters $Parameters -RoundValueSign $RoundValueSign -UseSwitchOffParameters $true
}

function Get-PmRelogParameters($Parameters, $RoundValueSign = '') {
    Get-PmParametersString -Parameters $Parameters -RoundValueSign $RoundValueSign -UseSwitchOffParameters $false
}

function Get-PmParametersString($Parameters, $RoundValueSign = '', $UseSwitchOffParameters = $true) {
    $ParamStr = ''
    if (Test-PmHashTable -Object $Parameters) {
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
                $ParamStr = $ParamStr + ' -' + $ParamKey + ' ' + (Get-PmParameterValueString -ParamVal $ParamVal -RoundValueSign $RoundValueSign)
            }  
        }
    }
    else {
        $ParamStr = ' ' + [string]$Parameters
    }
    $ParamStr
}

function Get-PmParameterValueString($ParamVal, $RoundValueSign = '', [switch]$NullIfNull) {
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

function Test-PmHashTable ($Object) {
    if ($Object -eq $null) {return $false}
    # Is HashTable or OrderedDictionary
    (($Object -is [hashtable]) -or ($Object -is [System.Object] -and $Object.GetType().name -eq 'OrderedDictionary'))
}
