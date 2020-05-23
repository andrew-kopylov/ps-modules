
Import-Module 1c-common-module

####
# MANAGE 1C-MODULE
####

function Get-1CModuleVersion() {
    '2.0.0'
}

function Update-1CModule ($Log) {

    $Result = Get-1CProcessResult -OK 1
    $ProcessName = 'Update1CModule'

    # 1c-module URL 
    $Url = 'https://raw.githubusercontent.com/andrew-kopylov/ps-modules/master/modules/1c-module.ps1'

    # Current Powershell command file
    $PSCmdFile = Get-Item -Path $PSCommandPath

    # Out-File
    $OutFilePath = Add-1CPath -Path $PSCmdFile.DirectoryName -AddPath ($PSCmdFile.BaseName + '-update' + $PSCmdFile.Extension)

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Download' -LogText 'Start'

    [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'
    Invoke-WebRequest -Uri $Url -OutFile $OutFilePath

    $NewModule = Get-Item -Path $OutFilePath
    if (-not $NewModule.Exists) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Download' -LogText 'Error. File not exists.' -Result $Result -OK 0
        return $Result
    }

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Download' -LogText 'End'

    $CurrHash = Get-FileHash -Path ($PSCmdFile.FullName)
    $NewHash = Get-FileHash -Path ($NewModule.FullName)
    if ($NewHash.hash -eq $CurrHash.hash) {
        Remove-Item -Path $NewModule.FullName
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'End' -LogText 'Used last version.' -Result $Result -OK 0
        return $Result
    }

    if ($NewModule.Length -le $PSCmdFile.Length) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'End' -LogText 'New file size is less or equal.' -Result $Result -OK 0
        return $Result
    }

    # Copy current module.
    [string]$CopyFileTmpl = $PSCmdFile.BaseName + '-old-[datetime]' + $PSCmdFile.Extension
    $CopyFilePath = Add-1CPath -Path $PSCmdFile.DirectoryName -AddPath ($CopyFileTmpl.Replace('[datetime]', (Get-Date).ToString('yyyyMMdd-HHmmss')))
    Rename-Item -Path $PSCmdFile.FullName -NewName $CopyFilePath
 
    # Remove old copies of module...
    $MaxCopiesCount = 3;
    $CopyFileMask = Add-1CPath -Path $PSCmdFile.DirectoryName -AddPath ($CopyFileTmpl.Replace('[datetime]', '*'))
    $AllCopyFiles = Get-Item -Path $CopyFileMask
    if ($AllCopyFiles.Count -gt $MaxCopiesCount) {
        $AllCopyFiles | Select-Object -First ($AllCopyFiles.Count - $MaxCopiesCount) | Remove-Item -Force
    }
 
    # Copy new-module file.  
    Rename-Item -Path $NewModule.FullName -NewName $PSCmdFile.FullName

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'End' -LogText 'Updated.'

    $Result
}


####
# MANAGE 1C-SERVICE
####

function Start-1CService($Log) {

    $Result = Get-1CProcessResult -OK 1

    $ProcessName = '1CServiceStart'
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'Begin'

    $FindedServices = Get-1CService -Status Paused, Stopped 
    if ($FindedServices.count -eq 0) {
        $Msg = 'Not finded Stopped or Paused 1C services'
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'End' -LogText $Msg -Result $Result -OK 0
        Return $Result
    }

    $FindedServices | foreach {Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Status.Before' -LogText ($_.Name + ' - ' + $_.Status)}

    Get-1CService | Set-Service -StartupType Automatic -PassThru | Start-Service

    foreach ($Service in $FindedServices) {
        $ServiceState = Get-1CService -Name $Service.Name
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Status.After' -LogText ($Service.Name + ' - ' + $ServiceState.Status)
        If ($ServiceState.Status -ne 'Running') {
            $Msg = 'Serivce is not started'
            Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'End' -LogText $Msg -Result $Result -OK 0
        } 
    }
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'End'
    $Result
}

function Stop-1CService($Log) {

    $Result = Get-1CProcessResult -OK 1

    $ProcessName = '1CServiceStop'
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'Begin'

    $FindedServices = Get-1CService -Status Running
    if ($FindedServices.count -eq 0) {
        $Msg = 'Not finded Running 1C services'
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'End' -LogText $Msg -Result $Result -OK 0
        Return $Result
    }

    $FindedServices | foreach {Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Status.Before' -LogText ($_.Name + ' - ' + $_.Status)}

    Get-1CService | Set-Service -StartupType Disabled  -PassThru | Stop-Service

    foreach ($Service in $FindedServices) {
        $ServiceState = Get-1CService -Name $Service.Name
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Status.After' -LogText ($Service.Name + ' - ' + $ServiceState.Status)
        If ($ServiceState.Status -ne 'Stopped') {
            $Msg = 'Serivce is not stopped'
            Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'End' -LogText $Msg -Result $Result -OK 0
        } 
    }
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'End'
    $Result
}

function Restart-1CService($Log) {

    $Result = Get-1CProcessResult -OK 1

    $ProcessName = '1CServiceRestart'
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'Begin'

    $FindedServices = Get-1CService -Status Running
    if ($FindedServices.count -eq 0) {
        $Msg = 'Not finded Running 1C services'
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'End' -LogText $Msg -Result $Result -OK 0
        Return $Result
    }

    $FindedServices | foreach {Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Status.Before' -LogText ($_.Name + ' - ' + $_.Status)}

    Restart-Service -InputObject $FindedServices

    foreach ($Service in $FindedServices) {
        $ServiceState = Get-1CService -Name $Service.Name
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Status.After' -LogText ($Service.Name + ' - ' + $ServiceState.Status)
        If ($ServiceState.Status -ne 'Running') {
            $Msg = 'Serivce is not running after restart'
            Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'End' -LogText $Msg -Result $Result -OK 0
        } 
    }
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'End'
    $Result
}

# inner function
function Get-1CService ($Name, $Status) {
    $sr = Get-Service -Name 1C*
    if ($Name -ne $null) {
        $sr = $sr | where {$_.Name -in $Name}
    }
    if ($Status -ne $null) {
        $sr = $sr | where {$_.Status -in $Status}
    }
    $sr
}


####
# IB
####

function Invoke-1CDumpIB ($Conn, $DumpFile, $Log) {
    Invoke-1CProcess -Conn $Conn -ProcessCommand 'DumpIB' -ProcessArgs ('"' + $DumpFile + '"') -Log $Log
}

function Invoke-1CRestoreIB ($Conn, $DumpFile, $Log) {
    Invoke-1CProcess -Conn $Conn -ProcessCommand 'RestoreIB' -ProcessArgs ('"' + $DumpFile + '"') -Log $Log
}

function Invoke-1CIBRestoreIntegrity($Conn, $Log) {
    Invoke-1CProcess -Conn $Conn -ProcessCommand 'IBRestoreIntegrity' -Log $Log
}

####
# CHECKS
####

function Invoke-1CCheckConfig {
    param (
        $Conn,
        [switch]$ConfigLogIntegrity,
        [switch]$IncorrectReferences,
        [switch]$ThinClient,
        [switch]$WebClient,
        [switch]$Server,
        [switch]$ExternalConnection,
        [switch]$ExternalConnectionServer,
        [switch]$MobileAppClient,
        [switch]$MobileAppServer,
        [switch]$ThickClientManagedApplication,
        [switch]$ThickClientServerManagedApplication,
        [switch]$ThickClientOrdinaryApplication,
        [switch]$ThickClientServerOrdinaryApplication,
        [switch]$MobileClient,
        [switch]$MobileClientDigiSign,
        [switch]$DistributiveModules,
        [switch]$UnreferenceProcedures,
        [switch]$HandlersExistence,
        [switch]$EmptyHandlers,
        [switch]$ExtendedModulesCheck,
        [switch]$CheckUseSynchronousCalls,
        [switch]$CheckUseModality,
        [switch]$UnsupportedFunctional,
        [switch]$AllExtensions,
        $Log
    )
    $ProcessArgs = [ordered]@{
        ConfigLogIntegrity = $ConfigLogIntegrity;
        IncorrectReferences = $IncorrectReferences;
        ThinClient = $ThinClient;
        WebClient = $WebClient;
        Server = $Server;
        ExternalConnection = $ExternalConnection;
        ExternalConnectionServer = $ExternalConnectionServer;
        MobileAppClient = $MobileAppClient;
        MobileAppServer = $MobileAppServer;
        ThickClientManagedApplication = $ThickClientManagedApplication;
        ThickClientServerManagedApplication = $ThickClientServerManagedApplication;
        ThickClientOrdinaryApplication = $ThickClientOrdinaryApplication;
        ThickClientServerOrdinaryApplication = $ThickClientServerOrdinaryApplication;
        MobileClient = $MobileClient;
        MobileClientDigiSign = $MobileClientDigiSign;
        DistributiveModules = $DistributiveModules;
        UnreferenceProcedures = $UnreferenceProcedures;
        HandlersExistence = $HandlersExistence;
        EmptyHandlers = $EmptyHandlers;
        ExtendedModulesCheck = $ExtendedModulesCheck;
        CheckUseSynchronousCalls = $CheckUseSynchronousCalls;
        CheckUseModality = $CheckUseModality;
        UnsupportedFunctional = $UnsupportedFunctional;
        AllExtensions = $AllExtensions
    }
    Invoke-1CProcess -Conn $Conn -ProcessCommand 'CheckConfig' -ProcessArgs $ProcessArgs -Log $Log -NoCrConn
}

function Invoke-1CCheckModules {
    param (
        $Conn,
        [switch]$ThinClient,
        [switch]$WebClient,
        [switch]$Server,
        [switch]$ExternalConnection,
        [switch]$ThickClientOrdinaryApplication,
        [switch]$MobileAppClient,
        [switch]$MobileAppServer,
        [switch]$MobileClient,
        [switch]$ExtendedModulesCheck,
        [switch]$AllExtensions,
        $Log
    )
    $ProcessArgs = [ordered]@{
        ThinClient = $ThinClient;
        WebClient = $WebClient;
        Server = $Server;
        ExternalConnection = $ExternalConnection;
        ThickClientOrdinaryApplication = $ThickClientOrdinaryApplication;
        MobileAppClient = $MobileAppClient;
        MobileAppServer = $MobileAppServer;
        MobileClient = $MobileClient;
        ExtendedModulesCheck = $ExtendedModulesCheck;
        AllExtensions = $AllExtensions
    }
    Invoke-1CProcess -Conn $Conn -ProcessCommand 'CheckModules' -ProcessArgs $ProcessArgs -Log $Log -NoCrConn
}

####
# ENTERPRIZE
####

function Invoke-1CExecute($Conn, $ExternalProcessor, $Timeout, $Log) {

    $ProcessCommand = 'Execute'
    $ProcessArgs = Add-RoundSign -Str $ExternalProcessor -RoundSign '"'

    Add-1CLog -Log $Log -ProcessName $ProcessCommand -LogHead 'Start.Execute' -LogText $ExternalProcessor
    
    $Result = Invoke-1CProcess -Mode ENTERPRISE -Conn $Conn -ProcessCommand $ProcessCommand -ProcessArgs $ProcessArgs -Timeout $Timeout -Log $Log -NoCrConn
    
    if ($Result.OK -ne 1) {
        $Msg = 'Ошибка выполнения внешней обработки.';
        Add-1CLog -Log $Log -ProcessName $ProcessCommand -LogHead "End.Error" -LogText $Msg -Result $Result
    }

    $Result
}

####
# COMMON CONFIGURATION COMMANDS
####

function Invoke-1CUpdateDBCfg() {
    param (
        $Conn,
        [switch]$Dynamic,
        [switch]$BackgroundStart,
        [switch]$BackgroundDynamic,
        [switch]$BackgroundCancel,
        [ValidateSet('none', 'Visible')]
        $BackgroundFinish,
        [switch]$BackgroundSuspend,
        [switch]$BackgroundResume,
        [switch]$WarningsAsErrors,
        [ValidateSet('none', 'v1', 'v2')]
        $Server,
        $Log
    )

    $ProcessCommand = 'UpdateDBCfg'
    
    $TArgs = [ordered]@{
        __Dynamic = $Dynamic
        BackgroundStart = $BackgroundStart;
        __BackgroundDynamic = $BackgroundDynamic;
        BackgroundCancel = $BackgroundCancel;
        BackgroundFinish = $BackgroundFinish;
        BackgroundSuspend = $BackgroundSuspend;
        BackgroundResume = $BackgroundResume;
        WarningsAsErrors = $WarningsAsErrors;
        Server = $Server;
    }

    $ProcessArgs = Get-1CArgs -TArgs $TArgs -ArgsStr $ProcessArgs -ArgEnter '-' -ValueSep ' ' -ArgSep ' '
    $ProcessArgs = $ProcessArgs.Replace('__Dynamic', 'Dynamic+')
    $ProcessArgs = $ProcessArgs.Replace('__BackgroundDynamic', 'Dynamic+')
    $ProcessArgs = $ProcessARgs.Replace('-BackgroundFinish Visible', '-BackgroundFinish -Visible')
    $ProcessArgs = $ProcessARgs.Replace('-BackgroundFinish none', '-BackgroundFinish')
    $ProcessArgs = $ProcessARgs.Replace('-Server v', '-Server -v')
    $ProcessArgs = $ProcessARgs.Replace('-Server none', '-Server')

    $Result = Invoke-1CProcess -Conn $Conn -ProcessCommand $ProcessCommand -ProcessArgs $ProcessArgs -Log $Log -NoCrConn
    
    if ($Result.OK -ne 1) {
        $Msg = 'Ошибка обновление конфигурации базы данных.';
        Add-1CLog -Log $Log -ProcessName $ProcessCommand -LogHead "End.Error" -LogText $Msg -Result $Result
    };

    $Result;      
}

function Invoke-1CCompareCfg {
   [CmdletBinding(PositionalBinding=$true)]
    param (
        $Conn,
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('MainConfiguration', 'VendorConfiguration', 'ExtensionConfiguration', 'ExtensionDBConfiguration', 'ConfigurationRepository', 'ExtensionConfigurationRepository', 'File')]
        $FirstConfigurationType,
        [Parameter(Position = 1)]
        $FirstName,
        [Parameter(Position = 1)]
        $FirstFile,
        [Parameter(Position = 1)]
        $FirstVersion,
        [ValidateSet('MainConfiguration', 'VendorConfiguration', 'ExtensionConfiguration', 'ExtensionDBConfiguration', 'ConfigurationRepository', 'ExtensionConfigurationRepository', 'File')]
        [Parameter(Mandatory = $true, Position = 2)]
        $SecondConfigurationType,
        [Parameter(Position = 3)]
        $SecondName,
        [Parameter(Position = 3)]
        $SecondFile,
        [Parameter(Position = 3)]
        $SecondVersion,
        [ValidateSet('ByObjectNames', 'ByObjectIDs')]
        $MappingRule,
        $Objects,
        [switch]$includeChildObjectsAll,
        [ValidateSet('Brief', 'Full')]
        $ReportType,
        [switch]$IncludeChangedObjects,
        [switch]$IncludeDeletedObjects,
        [switch]$IncludeAddedObjects,
        [ValidateSet('txt', 'mxl')]
        $ReportFormat,
        $ReportFile,
        $Log
    )

    # /CompareCfg -FirstConfigurationType [-FirstName] [-FirstFile] [-FirstVersion] 
    #    -SecondConfigurationType [-SecondName] [-SecondFile] [-SecondVersion] [-MappingRule] 
    #    [-Objects] -ReportType [-IncludeChangedObjects] [-IncludeDeletedObjects] [-IncludeAddedObjects] -ReportFormat -ReportFile
    #    — построение отчета о сравнении конфигурации. Доступны опции:

    $ProcessName = "CompareCfg";
    $ProcessArgs = "/CompareCfg";

    $TArgs = [ordered]@{
        FirstConfigurationType = $FirstConfigurationType;
        FirstName = if ($FirstConfigurationType -in ('VendorConfiguration', 'ExtensionConfiguration', 'ExtensionDBConfiguration')) {$FirstName} else {$null};
        FirstFile = if ($FirstConfigurationType -in ('File')) {'"' + $FirstFile + '"'} else {$null};
        FirstVersion = if ($FirstConfigurationType -in ('ConfigurationRepository', 'ExtensionConfigurationRepository')) {$FirstVersion} else {$null};
        SecondConfigurationType = $SecondConfigurationType;
        SecondName = if ($SecondConfigurationType -in ('VendorConfiguration', 'ExtensionConfiguration', 'ExtensionDBConfiguration')) {$SecondName} else {$null};
        SecondFile = if ($SecondConfigurationType -in ('File')) {'"' + $SecondFile + '"'} else {$null};
        SecondVersion = if ($SecondConfigurationType -in ('ConfigurationRepository', 'ExtensionConfigurationRepository')) {$SecondVersion} else {$null};
        MappingRule = $MappingRule;
        Objects = '[objects]';
        ReportType = $ReportType;
        IncludeChangedObjects = $IncludeChangedObjects;
        IncludeDeletedObjects = $IncludeDeletedObjects;
        IncludeAddedObjects = $IncludeAddedObjects;
        ReportFormat = $ReportFormat;
        ReportFile = '"' + $ReportFile + '"';
    }

    $ProcessArgs = Get-1CArgs -TArgs $TArgs -ArgsStr $ProcessArgs -ArgEnter '-'
    
    $ResultObjectsArgument = Set-1CCRObjectsArgument -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Objects $Objects -includeChildObjectsAll:$includeChildObjectsAll -Log $Log
    if ($ResultObjectsArgument.OK -ne 1) {Return $ResultObjectsArgument}
    $ProcessArgs = $ResultObjectsArgument.ProcessArgs

    $FirstCfgDescr = Add-CmnString -Str $FirstConfigurationType -Add ($ArgsTable.FirstName + $ArgsTable.FirstFile + $ArgsTable.FirstVersion) -Sep ' '
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "Start.FirstCfg" -LogText $FirstCfgDescr
    
    $SecondCfgDescr = Add-CmnString -Str $SecondConfigurationType -Add ($ArgsTable.SecondName + $ArgsTable.SecondFile + $ArgsTable.SecondVersion) -Sep ' '
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "Start.SecondCfg" -LogText $SecondCfgDescr
    
    $Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log

    Remove-1CResultDump -DumpFile $ResultObjectsArgument.DumpFile

    if ($Result.OK -ne 1) {
        $Msg = 'Ошибка сравнения конфигураций.';
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "End.Error" -LogText $Msg -Result $Result
    };

    $Result;      
}

function Invoke-1CMergeCfg {
    param (
        $Conn,
        $CfgFile,
        $SettingsFile,
        [ValidateSet('Enable', 'Disable')]
        $Support,
        [ValidateSet('IncludeObjects', 'Clear')]
        $UnresolvedRefs,
        [switch]$Force
    )

    # /MergeCfg <имя cf-файла> -Settings <имя файла настроек> [-EnableSupport | -DisableSupport]
    # [-IncludeObjectsByUnresolvedRefs | -ClearUnresolvedRefs] [-force]
 
    $ProcessName = 'MergeCfg';
    $ProcessArgs = '/MergeCfg "[CfgFile]"';
    $ProcessArgs = $ProcessArgs.Replace('[CfgFile]', $CfgFile);

    $TArgs = [ordered]@{
        Settings = $SettingsFile;
        EnableSupport = ($Support -like 'Enable');
        DisableSupport = ($Support -like 'Disable');
        IncludeObjectsByUnresolvedRefs = ($UnresolvedRefs -like 'IncludeObjects');
        ClearUnresolvedRefs =  ($UnresolvedRefs -like 'Clear');
        force = $Force;
    }
    $ProcessArgs = Get-1CArgs -TArgs $TArgs -ArgsStr $ProcessArgs -ArgEnter '-' -ValueSep ' ' -ArgSep ' '

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "Start.CfgFile" -LogText $CfgFile

    $Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log -NoCrConn

    $Result;
}

function Invoke-1CDumpCfg($Conn, $CfgFile, $Log) {

    $ProcessName = 'DumpCfg';
    $ProcessArgs = '/DumpCfg "[CfgFile]"';
    $ProcessArgs = $ProcessArgs.Replace('[CfgFile]', $CfgFile);

    Test-CmnDir -Path ([System.IO.Path]::GetDirectoryName($CfgFile)) -CreateIfNotExist

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "Start.CfgFile" -LogText $CfgFile

    $Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log -NoCrConn
    if ($Result.OK -ne 1) {
        $Msg = "Ошибка выгузки файла конфигурации.";
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "End.Error" -LogText $Msg -Result $Result
    };

    $Result;      
}

function Invoke-1CDumpCfgToFiles {
    param (
        $Conn,
        $FilesDir,
        [switch]$AllExtensions,
        [ValidateSet('Hierarchical', 'Plain')]
        $Format,
        [switch]$Update,
        [switch]$Force,
        $GetChangesToFile,
        $DumpInfoFileForChanges,
        [switch]$DumpInfoOnly,
        $ListFile,
        $Log
    )

    #/DumpConfigToFiles <каталог выгрузки> [-Extension <имя расширения>] 
    #[-AllExtensions] [-format] [-update][-force][-getChanges <имя файла>]
    #[-configDumpInfoForChanges <имя файла>][-configDumpInfoOnly]
    #[-listFile <имя файла>]
    
    $ProcessName = 'DumpCfgToFiles';
    $ProcessArgs = '/DumpConfigToFiles "[FilesDir]"';
    $ProcessArgs = $ProcessArgs.Replace('[FilesDir]', $FilesDir);

    $DumpInfoFileName = 'ConfigDumpInfo.xml'
    $DumpInfoFile = Add-1CPath -Path $FilesDir -AddPath $DumpInfoFileName
    if ($Update) {
        if (-not (Test-Path -Path $DumpInfoFile)) {
            $Update = $false
        }
    }

    $TProcessArgs = @{
        AllExtensions = $AllExtensions;
        format = $Format;
        update = $Update;
        force = $Force;
        getChanges = $GetChangesToFile;
        configDumpInfoForChanges = $DumpInfoFileForChanges;
        configDumpInfoOnly = $DumpInfoOnly;
        listFile = $ListFile;
    }


    $ProcessArgs = Get-1CArgs -TArgs $TProcessArgs -ArgsStr $ProcessArgs -ArgEnter '-' -ValueSep ' ' -ArgSep ' ' -RoundValueSign '"'

    Test-CmnDir -Path $FilesDir -CreateIfNotExist
    
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "Start.Dir" -LogText $FilesDir

    $Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log -NoCrConn
    if ($Result.OK -ne 1) {
        $Msg = "Ошибка выгузки конфигурации в файлы.";
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "End.Error" -LogText $Msg -Result $Result
    };

    $Result;      
}

function Invoke-1CLoadCfg($Conn, $CfgFile, $Log) {

    $ProcessName = 'LoadCfg';
    $ProcessArgs = '/LoadCfg "[CfgFile]"';
    $ProcessArgs = $ProcessArgs.Replace('[CfgFile]', $CfgFile);

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "Start.CfgFile" -LogText $CfgFile

    $Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log
    if ($Result.OK -ne 1) {
        $Msg = "Ошибка загрузки файла конфигурации.";
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "End.Error" -LogText $Msg -Result $Result
    };

    $Result;      
}

function Invoke-1CLoadCfgFromFiles {
    param (
        $Conn,
        $FilesDir,
        [switch]$AllExtensions,
        $FromFiles,
        $ListFile,
        [ValidateSet('Hierarchical', 'Plain')]
        $Format,
        [switch]$UpdateDumpInfo,
        $Log
    )

    #/LoadConfigFromFiles <каталог загрузки> [-Extension <имя расширения>]
    #[-AllExtensions][-files "<файлы>"][-listFile <файл списка>][-format <режим>] [-updateConfigDumpInfo]

    $ProcessName = 'LoadCfgToFiles';
    $ProcessArgs = '/LoadConfigFromFiles "[FilesDir]"';
    $ProcessArgs = $ProcessArgs.Replace('[FilesDir]', $FilesDir);

    $TProcessArgs = @{
        AllExtensions = $AllExtensions;
        files = $FromFiles;
        listFile = $ListFile;
        format = $Format;
        updateConfigDumpInfo = $UpdateDumpInfo;
    }

    $ProcessArgs = Get-1CArgs -TArgs $TProcessArgs -ArgsStr $ProcessArgs -ArgEnter '-' -ValueSep ' ' -ArgSep ' ' -RoundValueSign '"'

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "Start.Dir" -LogText $FilesDir

    $Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log
    if (-not $Result.OK) {
        $Msg = "Ошибка загрузки конфигурации из файлов.";
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "End.Error" -LogText $Msg -Result $Result
    };

    $Result;      
}

####
# CONFIGURAITON REPOSITORY COMMANDS
####

## Public repository functions.

function Invoke-1CCRCreate {
    param (
        $Conn,
        [switch]$AllowConfigurationChanges, 
        [ValidateSet('ObjectNotEditable', 'ObjectIsEditableSupportEnabled', 'ObjectNotSupported')]
        $ChangesAllowedRule,
        [ValidateSet('ObjectNotEditable', 'ObjectIsEditableSupportEnabled', 'ObjectNotSupported')]
        $ChangesNotRecommendedRule,
        [switch]$NoBind,
        $Log
    )

    #/ConfigurationRepositoryCreate [-Extension <имя расширения>] [-AllowConfigurationChanges 
    #-ChangesAllowedRule <Правило поддержки> -ChangesNotRecommendedRule <Правило поддержки>] [-NoBind] 

    $ProcessArgs = @{
        AllowConfigurationChanges = $AllowConfigurationChanges;
        ChangesAllowedRule = $ChangesAllowedRule;
        ChangesNotRecommendedRule = $ChangesNotRecommendedRule;
        NoBind = $NoBind;
    }

    Invoke-1CProcess -Conn $Conn -ProcessCommand 'ConfigurationRepositoryCreate' -ProcessName 'CRCreate' -ProcessArgs $ProcessArgs -Log $Log
}

function Invoke-1CCRBindCfg {
    param(
        $Conn,
        [switch]$forceBindAlreadyBindedUser,
        [switch]$forceReplaceCfg
    )

    #/ConfigurationRepositoryBindCfg [-Extension <имя расширения>] [-forceBindAlreadyBindedUser][-forceReplaceCfg] 
    #— подключение неподключенной конфигурации к хранилищу конфигурации.

    $ProcessArgs = @{
        forceBindAlreadyBindedUser = $forceBindAlreadyBindedUser;
        forceReplaceCfg = $forceReplaceCfg;
    }

    Invoke-1CProcess -Conn $Conn -ProcessCommand 'ConfigurationRepositoryBindCfg' -ProcessName 'CRBindCfg' -ProcessArgs $ProcessArgs -Log $Log
}

function Invoke-1CCRUnbindCfg {
    param(
        $Conn,
        [switch]$force
    )

    #/ConfigurationRepositoryUnbindCfg [-Extension <имя расширения>] [-force]

    $ProcessArgs = @{
        force = $force;
    }

    Invoke-1CProcess -Conn $Conn -ProcessCommand 'ConfigurationRepositoryUnbindCfg' -ProcessName 'CRUnbindCfg' -ProcessArgs $ProcessArgs -Log $Log
}

function Invoke-1CCRUpdateCfg($Conn, $v, $Revised, [switch]$force, $Objects, [switch]$includeChildObjectsAll, $Log) {

    #/ConfigurationRepositoryUpdateCfg [-Extension <имя расширения>] [-v <номер версии хранилища>] [-revised] [-force] [-objects <имя файла со списком объектов>] 

    $ProcessName = 'CRUpdateCfg'
    $ObjectsCommand = 'ConfigurationRepositoryUpdateCfg'

    $AddCmd = Get-1CArgs -TArgs @{v = $v; revised = $Revised; force = $force} -ArgEnter '-'
    Invoke-1CCRObjectsCommand -Conn $Conn -ProcessName $ProcessName -ObjectsCommand $ObjectsCommand -Objects $Objects -includeChildObjectsAll:$includeChildObjectsAll -AddCmd $AddCmd -Log $Log
}

function Invoke-1CCRDumpCfg($Conn, $CfgFile, $v, $Log) {

    #/ConfigurationRepositoryDumpCfg [-Extension <имя расширения>] <имя cf файла> [-v <номер версии хранилища>] 

    $ProcessName = 'CRDumpCfg';
    $ProcessArgs = '/ConfigurationRepositoryDumpCfg "[CfgFile]"'
    $ProcessArgs = $ProcessArgs.Replace('[CfgFile]', $CfgFile)

    Test-CmnDir -Path ([System.IO.Path]::GetDirectoryName($CfgFile)) -CreateIfNotExist

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "Start.CfgFile" -LogText ('version ' + $v + ' - ' + $CfgFile)
    
    $ProcessArgs = Get-1CArgs -TArgs @{v = $v} -ArgEnter '-' -ArgsStr $ProcessArgs
    $Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log
    if ($Result.OK -ne 1) {
        $Msg = "Ошибка выгузки конфигурации хранилища в файл.";
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "End.Error" -LogText $Msg -Result $Result
    }

    $Result
}

function Invoke-1CCRCommit($Conn, $Objects, [switch]$includeChildObjectsAll, $comment, $keepLocked, $force, $Log) {
 
    # /ConfigurationRepositoryCommit [-objects <имя файла со списком объектов>] [-comment "<Текст комментария>"] [-keepLocked] [-force] [-Extension <имя расширения>]
    $ProcessName = 'CRCommit'
    $ObjectsCommand = 'ConfigurationRepositoryCommit'

    $TArgs = [ordered]@{comment = $comment; keepLocked = $keepLocked; force = $force;}    
   
    $AddCmd = Get-1CArgs -TArgs $TArgs -ArgEnter '-' -RoundValueSign '"'
    Invoke-1CCRObjectsCommand -Conn $Conn -ProcessName $ProcessName -ObjectsCommand $ObjectsCommand -Objects $Objects -includeChildObjectsAll:$includeChildObjectsAll -AddCmd $AddCmd -Log $Log
}

function Invoke-1CCRLock($Conn, $Objects, [switch]$includeChildObjectsAll, $Revised, $Log) {
 
    # /ConfigurationRepositoryLock [-Extension <имя расширения>] [-objects <имя файла со списком объектов>] [-revised]
 
    $ProcessName = 'CRLock'
    $ObjectsCommand = 'ConfigurationRepositoryLock'

    $AddCmd = Get-1CArgs -TArgs @{revised = $Revised} -ArgEnter '-'
    Invoke-1CCRObjectsCommand -Conn $Conn -ProcessName $ProcessName -ObjectsCommand $ObjectsCommand -Objects $Objects -includeChildObjectsAll:$includeChildObjectsAll -AddCmd $AddCmd -Log $Log
}

function Invoke-1CCRUnlock($Conn, $Objects, [switch]$includeChildObjectsAll, $force, $Log) {
 
    # /ConfigurationRepositoryUnlock [-Extension <имя расширения>] [-objects <имя файла со списком объектов>] [-force]

    $ProcessName = 'CRUnlock'
    $ObjectsCommand = 'ConfigurationRepositoryUnlock'

    $AddCmd = Get-1CArgs -TArgs @{force = $force} -ArgEnter '-'
    Invoke-1CCRObjectsCommand -Conn $Conn -ProcessName $ProcessName -ObjectsCommand $ObjectsCommand -Objects $Objects -includeChildObjectsAll:$includeChildObjectsAll -AddCmd $AddCmd -Log $Log
}

function Invoke-1CCRAddUser {
    param(
        $Conn,
        $User,
        $Pwd,
        [ValidateSet('ReadOnly', 'LockObjects', 'ManageConfigurationVersions', 'Administration')]
        [string]$Rights,
        [switch]$RestoreDeletedUser,
        $Log
    )

    $ProcessArgs = '/ConfigurationRepositoryAddUser';

    $TArgs = [ordered]@{
        User = ('"' + $User + '"');
        Pwd = ('"' + $Pwd + '"');
        Rights = $Rights;
        RestoreDeletedUser = $RestoreDeletedUser;
    }
    $ProcessArgs = Get-1CArgs -TArgs $TArgs -ArgsStr $ProcessArgs -ArgEnter '-'

    Invoke-1CProcess -Conn $Conn -ProcessName 'CRAddUser' -ProcessArgs $ProcessArgs -Log $Log
}

function Invoke-1CCRCopyUsers {
    param(
        $Conn,
        $Path,
        $User,
        $Pwd,
        [switch]$RestoreDeletedUser,
        $Log
    )

    $ProcessArgs = '/ConfigurationRepositoryCopyUsers';

    $TArgs = [ordered]@{
        Path = $Path;
        User = $User;
        Pwd = $Pwd;
        RestoreDeletedUser = $RestoreDeletedUser;
    }
    $ProcessArgs = Get-1CArgs -TArgs $TArgs -ArgsStr $ProcessArgs -ArgEnter '-' -RoundValueSign '"'

    Invoke-1CProcess -Conn $Conn -ProcessName 'CRCopyUsers' -ProcessArgs $ProcessArgs -Log $Log
}

function Invoke-1CCRClearChache {
    param(
        $Conn,
        [ValidateSet('All', 'Local', 'LocalDB', 'Global')]
        [string]$ChacheType,
        $Log
    )
    if ($ChacheType -eq '' -or $ChacheType.ToUpper() -eq 'ALL') {
        $ResultLocalDB = Invoke-1CCRClearChache -Conn $Conn -ChacheType LocalDB -Log $Log
        $ResultGlobal = Invoke-1CCRClearChache -Conn $Conn -ChacheType Global -Log $Log
        $ResultLocal = Invoke-1CCRClearChache -Conn $Conn -ChacheType Local -Log $Log
        $Result = Get-1CProcessResult -OK 1 -Msg ''
        if ($ResultLocalDB.OK -ne 1 -or $ResultLocalDB.OK -ne 1 -or $ResultLocalDB.OK -ne 1) {$Result.OK = 0}
        $Result.Msg = Add-CmnString -Str $Result.Msg -Add $ResultLocalDB.Msg
        $Result.Msg = Add-CmnString -Str $Result.Msg -Add $ResultGlobal.Msg
        $Result.Msg = Add-CmnString -Str $Result.Msg -Add $ResultLocal.Msg
        $Result.Out = Add-CmnString -Str $Result.Out -Add $ResultLocalDB.Out
        $Result.Out = Add-CmnString -Str $Result.Out -Add $ResultGlobal.Out
        $Result.Out = Add-CmnString -Str $Result.Out -Add $ResultLocal.Out
    }
    elseif ($ChacheType.ToUpper() -eq 'LocalDB'.ToUpper()) {
        $ProcessName = 'CRClearCache';
        $ProcessArgs = '/ConfigurationRepositoryClearCache';
        $Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log
    }
    elseif ($ChacheType.ToUpper() -eq 'Global'.ToUpper()) {
        $ProcessName = 'CRClearGlobalCache';
        $ProcessArgs = '/ConfigurationRepositoryClearGlobalCache';
        $Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log
    }
    elseif ($ChacheType.ToUpper() -eq 'Local'.ToUpper()) {
        $ProcessName = 'CRClearLocalCache';
        $ProcessArgs = '/ConfigurationRepositoryClearLocalCache';
        $Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log
    }
    else {
        $Result = Get-1CProcessResult -OK 0 -Msg 'Bad parameter value "ChacheType".'
    }
    $Result
}

function Invoke-1CCRSetLabel ($Conn, $v, $Label, $LabelComment, $Log) {
    
    $ProcessName = 'CRSetLabel'

    $LabelSets = @($Label)
    if (-not [String]::IsNullOrEmpty($LabelComment)) {
        $LabelSets += $LabelComment
    }

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Start' -LogText ('ver ' + $v + ' ' + [String]::Join(' - ', $LabelSets))

    $ProcessArgs = '/ConfigurationRepositorySetLabel';

    $ProcessArgs = Get-1CArgs -TArgs @{v = $v} -ArgsStr $ProcessArgs -ArgEnter '-'

    if ($Label -ne $null) {
        $ProcessArgs = $ProcessArgs + ' -name"' + $Label + '"'
    }

    $CharNS = "`n"

    [String[]]$CommentStrings = @();
    if ($LabelComment -is [String]) {
        $CommentStrings = ([String]$LabelComment).Split($CharNS)
    }
    elseif ($LabelComment -is [System.Array]) {
        $CommentStrings = $LabelComment
    }

    if ($CommentStrings.Count -gt 0) {
        foreach ($CommentStr in $CommentStrings) {
            $ProcessArgs = $ProcessArgs + ' -comment"' + $CommentStr.TrimEnd() + '"'
        }
    }

    Invoke-1CProcess -Conn $Conn -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Log $Log
}

function Invoke-1CCRReport {
    param(
        $Conn,
        $ReportFile,
        $NBegin,
        $NEnd,
        [switch]$GroupByObject,
        [switch]$GroupByComment,
        $Log
    )

    $ProcessArgs = '/ConfigurationRepositoryReport "[ReportFile]"';
    $ProcessArgs = $ProcessArgs.Replace('[ReportFile]', $ReportFile);

    $TArgs = [ordered]@{
        NBegin = $NBegin;
        NEnd = $NEnd;
        GroupByObject= $GroupByObject;
        GroupByComment = $GroupByComment;
    }
    $ProcessArgs = Get-1CArgs -TArgs $TArgs -ArgsStr $ProcessArgs -ArgEnter '-'

    Invoke-1CProcess -Conn $Conn -ProcessName 'CRReport' -ProcessArgs $ProcessArgs -Log $Log
}

function Invoke-1CCROptimizeData ($Conn, $Log) {
    $ProcessArgs = '/ConfigurationRepositoryOptimizeData';
    Invoke-1CProcess -Conn $Conn -ProcessName 'CROptimizeData' -ProcessArgs $ProcessArgs -Log $Log
}

function Backup-1CCR ($Path, $BackupPath, $Log) {

    $ProcessName = 'CRBackup'

    $Result = @{OK = 1; Msg = ''}

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Begin' -LogText ('"' + $Path + '" to "' + $BackupPath + '"')

    if (-not (Test-Path -Path $BackupPath)) {
        New-Item -Path $BackupPath -ItemType Directory -Force
    }

    $DataFile = Add-1CPath -Path $Path -AddPath 1cv8ddb.1cd
    $DataDir = Add-1CPath -Path $Path -AddPath data

    $DataFileDest = Add-1CPath -Path $BackupPath -AddPath 1cv8ddb.1cd
    $DataDirDest = Add-1CPath -Path $BackupPath -AddPath data

    if (Test-Path -Path $DataFile) {
        Copy-Item -Path $DataFile -Destination $DataFileDest -Force
        if (-not (Test-Path -Path $DataFileDest)) {
            Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Error' -LogText ('Copy error: ' + $DataFileDest) -Result $Result -OK 0
        }
    }

    if (Test-Path -Path $DataDir) {
        Copy-Item -Path $DataDir -Destination $DataDirDest -Force -Recurse
        if (-not (Test-Path -Path $DataDirDest)) {
            Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Error' -LogText ('Copy error: ' + $DataDirDest) -Result $Result -OK 0
        }
    }

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'End' -LogText ('OK ' + $Result.OK)

    $Result
}

# Invoke CR commands.

function Get-1CCRObjectsFromFile($FilePath) {

    [string[]]$Objects = @()

    # Read objects for locking.
    $FileSystemObject = New-Object -ComObject Scripting.FileSystemObject
    
    $FileStream = $FileSystemObject.OpenTextFile($FilePath, 1, $false, -2)
    while (-not $FileStream.AtEndOfStream) {
        $Objects += $FileStream.ReadLine()
    }

    $Objects
}

# Read objects from "out" result command.
function Get-1CCRProcessedObjectsOut([string]$OutText) {

    $Result = @{Objects = @(); OK = 1; Msg = ''};

    $CRBeginText = "Начало операции с хранилищем конфигурации";
    $CREndText = "Операция с хранилищем конфигурации завершена";

    $OutTextArr = $OutText.Split("`n");
    if ($OutTextArr.Count -lt 2) {
        $Result.OK = 0
        $Result.Msg = "Не ожиданный ответ конфигуратора."
    }
    elseif ($OutTextArr.Get(0).Contains($CRBeginText) -and $OutTextArr.Get(1).Contains($CREndText)) {
        $Result.Msg = "Нет изменений в хранилище.";
    }
    else {
        $IsObject = $false
        foreach ($TextStr in $OutTextArr) {
            if ($TextStr.Contains($CRBeginText)) {
                $IsObject = $true;
            }
            elseif ($TextStr.Contains($CREndText)) {
                $IsObject = $false;
            }
            elseif ($IsObject -and $TextStr.Contains(':')) {
                $ObjectName = $TextStr.Split(':').Get(1);
                $ObjectName = $ObjectName.Trim();
                $Result.Objects += $ObjectName;
            };
        }     
    }
    $Result
}

# Inner function.
function Invoke-1CCRObjectsCommand($Conn, $ProcessName, $ObjectsCommand, $Objects, [switch]$includeChildObjectsAll, $AddCmd = '', $Log) {
    
    $ProcessArgs = '/' + $ObjectsCommand + ' [objects]';
    
    $ResultObjectsArgument = Set-1CCRObjectsArgument -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Objects $Objects -includeChildObjectsAll:$includeChildObjectsAll -Log $Log
    if ($ResultObjectsArgument.OK -ne 1) {Return $ResultObjectsArgument}
    $ProcessArgs = $ResultObjectsArgument.ProcessArgs

    # Addition command for object action.
    $ProcessArgs = Add-CmnString -Str $ProcessArgs -Add $AddCmd -Sep ' '

    [hashtable]$Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log
 
    Remove-1CResultDump -DumpFile $ResultObjectsArgument.DumpFile
    $Result.Add('ProcessedObjects', @())

    if ($Result.OK -ne 1) {
        $Msg = "Ошибка обработки объектов в хранилище конифгурации. Выполняемая соманда: [ObjectsCommand].";
        $Msg = $Msg.Replace('[ObjectsCommand]', $ObjectsCommand); 
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "End.Error" -LogText $Msg -Result $Result
        Return $Result;
    }

    # Changed objects.
    $ProcessObjectResult = Get-1CCRProcessedObjectsOut -OutText $Result.Out;
    if ($ProcessObjectResult.OK -ne 1) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Error' -LogText -$ProcessObjectResult.Msg -Result $Result -OK 0
        return $Result
    }
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "ProcessedObjects.Msg" -LogText $ProcessObjectResult.Msg -Result $Result
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "ProcessedObjects.Count" -LogText $ProcessObjectResult.Objects.Count.ToString()
    
    $Result.ProcessedObjects = $ProcessObjectResult.Objects;
    $Result
}


####
# OBJECTS LIST/COMPARE/LOCKING
####

function Get-1CObjectsListTmpl($fullName = '', $includeChildObjects, $fullNameInSecondConfiguration = '', $Subsystem) {
   @{
        fullName = $fullName;
        includeChildObjects = $includeChildObjects;
        fullNameInSecondConfiguration = $fullNameInSecondConfiguration;
        Subsystem = $Subsystem
    }
}

function Get-1CObjectsSubsystemTmpl($includeObjectsFromSubordinateSubsystems = $false, $configuration = '') {
    @{
        includeObjectsFromSubordinateSubsystems = $false;
        configuration = ''; # Main, Second       
    }
}

function Save-1CObjectListFile($Objects, $FileName, [switch]$includeChildObjectsAll) {

    $ObjectListTL = Get-1CObjectsListTmpl 
    $ObjectsArray = @()

    $Configuration = $null

    foreach ($Object in $Objects) {
        
        $NewObject = $ObjectListTL.Clone()
        
        if ($Object -is [string]) {
            $NewObject.fullName = $Object
        }
        else {
            $ObjectListTL.Keys | % {$NewObject.($_) = $Object.($_)}
        }

        if ($NewObject.fullName -in ('', $null)) {continue}

        if (-not $NewObject.fullName.Contains('.')) {
            $Configuration = $NewObject
        }
        else {
            $ObjectsArray += $NewObject
        }
    }

    $XmlDoc = New-Object System.Xml.XmlDocument
    $xmlDecl = $XmlDoc.CreateXmlDeclaration('1.0', "UTF-8", $null);
    $XmlDoc.AppendChild($xmlDecl);
     
    # Root element 'Objects'
    $XmlObjects = $XmlDoc.CreateElement("Objects")
    $XmlObjects.SetAttribute('xmlns', 'http://v8.1c.ru/8.3/config/objects')
    $XmlObjects.SetAttribute('version', '1.0')
    $XmlDoc.AppendChild($XmlObjects)

    # Configuration
    if ($Configuration -ne $null) {    
        $Element = $XmlDoc.CreateElement("Configuration")
        if ($Configuration.includeChildObjects -eq $true) {
            $includeChildObjects = $true
        }
        # Will Lock Child objects only if has includeChildObjects -eq $true (no group action)
        #elseif ($Configuration.includeChildObjects -ne $false -and $includeChildObjectsAll -eq $true) {
            #$includeChildObjects = $true
        #}
        else {
            $includeChildObjects = $false
        }
        $Element.SetAttribute('includeChildObjects', $includeChildObjects)
        $XmlObjects.AppendChild($Element)
    }
    
    #Objects
    if ($ObjectsArray.Count -gt 0) {
         
        foreach ($Object in $ObjectsArray) {
            $Element = $XmlDoc.CreateElement('Object')
            $Element.SetAttribute('fullName', $Object.fullName)
            # fullNameInSecondConfiguration
            if ($Object.fullNameInSecondConfiguration -ne $null -and $Object.fullNameInSecondConfiguration -ne '') {
                $Element.SetAttribute('fullNameInSecondConfiguration', $Object.fullNameInSecondConfiguration)
            }
            # includeChildObjects
            if ($Object.includeChildObjects -eq $true) {
                $includeChildObjects = $true
            }
            elseif ($Object.includeChildObjects -ne $false -and $includeChildObjectsAll -eq $true) {
                $includeChildObjects = $true
            }
            else {
                $includeChildObjects = $false
            }
            $Element.SetAttribute('includeChildObjects', $includeChildObjects)
            $XmlObjects.AppendChild($Element)
      
            # subsystem  
            if ($Object.Subsystem -ne $null) {
                $ElementSubsys = $XmlDoc.CreateElement("Subsystem")
                if ($Object.Subsystem.includeObjectsFromSubordinateSubsystems -eq $true) {
                    $ElementSubsys.SetAttribute('includeObjectsFromSubordinateSubsystems', 'true')
                }
                if ($Object.Subsystem.configuration -in ('Main', 'Second')) {
                    $ElementSubsys.SetAttribute('configuration', $Object.Subsystem.configuration)
                }
                $Element.AppendChild($ElementSubsys)
            }
        }
    }

    $XmlDoc.Save($FileName);
}

# Replace substring '[objects]' in argruments string.
function Set-1CCRObjectsArgument($ProcessName, $ProcessArgs, $Objects, [switch]$includeChildObjectsAll, $Log) {
    
    $Result = Get-1CProcessResult -OK 1 -Msg $Msg -Dump ''
    $Result.Add('ProcessArgs', '')
    $Result.Add('DumpFile', '')

    $DumpDir = Get-1CLogDumpDir -Log $Log
    $DumpObjectsFile = ''

    if ($Objects -eq $null) {
        $ProcessArgs = $ProcessArgs.Replace("[objects]", "");   
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "Start.Objects" -LogText "Все объекты."
    }
    elseif ($Objects.Count -eq 0) {
        $Msg = "Пустой список объектов."
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "End" -LogText $Msg -Result -OK 0
        return $Result
    }
    else {
        $DumpGuid = (Get-Date).ToString('yyyyMMdd-HHmmss');
        $DumpObjectsFile = Add-1CPath -Path $DumpDir -AddPath ($ProcessName + '_' + $DumpGuid + '_Objects-Dump.xml')
        $SaveResult = Save-1CObjectListFile -Objects $Objects -FileName $DumpObjectsFile -includeChildObjectsAll:$includeChildObjectsAll
        $ProcessArgs = $ProcessArgs.Replace('[objects]', '-objects "' + $DumpObjectsFile + '"')
        if (-not $Log.ClearDump) {
            Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "DumpObjects" -LogText $DumpObjectsFile
        }
        $Result.DumpFile = $DumpObjectsFile
    } 
   
    $Result.ProcessArgs = $ProcessArgs;
    $Result 
}

function Get-1CCompareTable($CompareFilePath, [string]$CompareText = '') {

    if ($CompareFilePath -ne $null) {
        $CompText = Get-Content -Path $CompareFilePath
    }
    else {
        $CompText = $CompareText.Split('`n')
    }

    $Enters = @{Changed = '***'; InFirst = '-->'; InSecond = '<--'}
    $ReservedChars = ('[]().\^$|?*+{}').ToCharArray()

    # ComEpare enters for using in match string.
    $CompEntersForMatch = @()
    foreach ($CompEnter in $Enters.Values) {
        $ReservedChars | % {if ($CompEnter.Contains($_)) {$CompEnter = $CompEnter.Replace($_, [string]('\' + $_))}}   
        $CompEntersForMatch += $CompEnter
    }

    # Match string for changed object. Example: '- ***Справочник.Контрагенты'
    $MatchString = '^\s*- (' + [string]::Join('|', $CompEntersForMatch) + ')(\S+)';

    $CompTable = @()
    foreach ($CompStr in $CompText) {
        if (-not ($CompStr -match $MatchString)) {continue}
        $CompFields = [ordered]@{
            Metadata = ($Matches.2);
            Changed   = ($Matches.1 -eq $Enters.Changed);
            InFirst  = ($Matches.1 -eq $Enters.InFirst);
            InSecond = ($Matches.1 -eq $Enters.InSecond)
        }
        $CompTable += (New-Object PSCustomObject -Property $CompFields)
    }
    $CompTable
}

function Get-1CCRObjectsToLock($CompareTable) {
    $Objects = [string[]]@()
    foreach ($CompObject in $CompareTable) {
        $Object = Get-1CCRLockingObject -Metadata $CompObject.Metadata
        if ($Object -ne '' -and $Object -ne $null -and $Object -notin $Objects) {
            $Objects += $Object
        }
    }
    $Objects
}

function Get-1CCRLockingObject([string]$Metadata) {
   
    if ($Metadata -isnot [string] -or $Metadata -eq '') {return $flase}
   
    $MetadataParts = ([string]$Metadata).Split('.')
    if ($MetadataParts.Count -eq 2) {
        $FirstPart = $MetadataParts.Get(0)
        if ($FirstPart -eq 'Конфигурация') {
            return $FirstPart
        }
        else {
            return $Metadata
        }
    }
    elseif ($MetadataParts.Count -eq 4) {
        $FirstPart = $MetadataParts.Get(0)
        $SecondPart = $MetadataParts.Get(1)
        $ThirdPart = $MetadataParts.Get(2)
        if ($ThirdPart -in ('Форма', 'Макет')) {
            return $Metadata
        }
        else {
            return ($FirstPart + '.' + $SecondPart)
        }
    }
    elseif ($MetadataParts.Count -gt 4) {
        $FirstPart = $MetadataParts.Get(0)
        $SecondPart = $MetadataParts.Get(1)
        return ($FirstPart + '.' + $SecondPart)
    }
    else {
        return ''
    }
}



####
# INVOKE 1C-WEBINST
####

function Invoke-1CWebInst {
    param (
        $Conn,
        [ValidateSet('publish', 'delete')]
        $Command,
        [ValidateSet('iis', 'apache2', 'apache22', 'apache24')]
        $Ws,
        $WsPath,
        $Dir,
        $ConfPath,
        $Descriptor,
        $OAuth
    )

    # webinst [-publish] | -delete <веб-сервер>
    # -wsdir <виртуальный каталог>
    # -dir <физический каталог>
    # -connstr <строка соединения>
    # -confpath <путь к файлу httpd.conf>
    # -descriptor <путь к файлу-шаблону default.vrd>
    # [-osauth]

    if ($Conn -is [String]) {
        $ConnStr = $Conn
    }
    else {
        $ConnStr = Get-1CConnStringCommon -Conn $Conn
    }

    if ([String]::IsNullOrEmpty($WsDir)) {
        if (-not [String]::IsNullOrEmpty($Conn.Ref)) {
            $WsDir = $Conn.Ref
        }
    } 

    if ($Ws = 'iis') {
        if ([String]::IsNullOrEmpty($Dir)) {
            $Dir = Add-1CPath -Path 'C:\inetpub\wwwroot\' -AddPath ([String]$WsPath).Replace('/', '\')
        }
        elseif (-not ($dir -like '?:\*') -and -not ($dir -like '\\*')) {
            $Dir = Add-1CPath -Path 'C:\inetpub\wwwroot\' -AddPath $Dir
        }
    }

    if ($Ws = 'iis') {
        $DefaultVrd = $Dir + '\default.vrd'
        $DefaultVrdTemp = $DefaultVrd + '.tmp'
        if (Test-Path -Path $DefaultVrd) {
            Move-Item -Path $DefaultVrd -Destination $DefaultVrdTemp -Force
        }
    }

    $TArgs = [ordered]@{}
    $TArgs[$Command] = $true
    $TArgs[$Ws] = $true
    $TArgs.wsdir = $WsPath
    $Targs.dir = Add-RoundSign -RoundSign '"' -Str $Dir
    $TArgs.connstr = Add-RoundSign -RoundSign '"' -Str $ConnStr
    $TArgs.confpath = Add-RoundSign -RoundSign '"' -Str $ConfPath
    $TArgs.descriptor = Add-RoundSign -RoundSign '"' -Str $Descriptor 
    $TArgs.OAuth = $OAuth

    $ArgsList = Get-1CArgs -TArgs $TArgs -ArgEnter '-'

    $WebInst = Add-1CPath -Path (Get-1Cv8Bin -V8 $Conn.V8) -AddPath 'webinst.exe'

    #$CommandStr = '"' + $WebInst + '" ' + $ArgsList
    $Result = Start-Process -FilePath $WebInst -ArgumentList $ArgsList -PassThru -WindowStyle Hidden -Wait
  
    if ($Ws = 'iis') {
        if (Test-Path -Path $DefaultVrdTemp) {
            if (Test-Path -Path $DefaultVrd) {
                Remove-Item -Path $DefaultVrdTemp -Force
            }
            else {
                Move-Item -Path $DefaultVrdTemp -Destination $DefaultVrd -Force
            }
        }
    }

    @{WebInst = $WebInst; ArgumentList = $ArgsList; ExitCode = $Result.ExitCode}
}

####
# INVOKE 1C PROCESS
####

# Invoke process 1cv8
function Invoke-1CProcess {
    param (
        [ValidateSet('DESIGNER', 'ENTERPRISE', 'CREATEINFOBASE')]
        $Mode,
        $Conn, 
        $ProcessCommand,
        $ProcessArgs,
        $ProcessName,
        [int]$Timeout,
        [switch]$NoCrConn,
        $Log
    )

    if ($Mode -eq $null) {
        $Mode = 'DESIGNER'
    }
   
    $ConnStr = ''
    if ($Conn -ne $null) {
        if (-not [String]::IsNullOrWhiteSpace($Conn.CRPath) -and [String]::IsNullOrWhiteSpace($Conn.CRUsr)) {
            $Result = Get-1CProcessResult
            Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Err' -LogText ('Не указан пользователь хранилища: ' + $Conn.CRPath) -Result $Result -OK 0
            return $Result
        }
        if ($NoCrConn) {
            $ConnNoCr = Get-1CConn -CRPath '' -Conn $Conn
            $ConnStr = Get-1CConnString -Conn $ConnNoCr
        }
        else {
            $ConnStr = Get-1CConnString -Conn $Conn
        }
    }

    if (Test-1CHashTable -Object $ProcessArgs) {
        $ProcessArgs = Get-1CArgs -TArgs $ProcessArgs -ArgEnter '-' -ValueSep ' ' -ArgSep ' ' -RoundValueSign '"'
    }

    $ArgList = ''
    $ArgList = Add-CmnString -Str $ArgList -Add $Mode -Sep ' '
    $ArgList = Add-CmnString -Str $ArgList -Add $ConnStr -Sep ' '
    $ArgList = Add-CmnString -Str $ArgList -Add $ProcessCommand -Sep ' /'
    $ArgList = Add-CmnString -Str $ArgList -Add $ProcessArgs -Sep ' '

    if (-not [string]::IsNullOrEmpty($Conn.Extension)) {
        $ArgList = Add-CmnString -Str $ArgList -Add ('-Extension "' + $Conn.Extension + '"') -Sep ' '
    }

    if ([String]::IsNullOrEmpty($ProcessName)) {
        $ProcessName = $ProcessCommand
    }
   
    if ($Conn -ne $null) {
        $Base = Get-1CConnStringBase -Conn $Conn
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Start.Base' -LogText $Base
    }

    if ((-not [String]::IsNullOrEmpty($Conn.CRPath)) -and (-not $NoCrConn)) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Start.ConfRep' -LogText $Conn.CRPath
    }

    if (-not [String]::IsNullOrEmpty($Conn.Extension)) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Start.Extension' -LogText $Conn.Extension
    }

    # Startup messages and dialogs
    $ArgList = Get-1CArgs -TArgs @{L = $Conn.Local; VL = $Conn.VLocal} -ArgsStr $ArgList

    # Startup messages and dialogs
    $ArgList = Get-1CArgs -TArgs @{DisableStartupMessages = $Conn.DisableStartupMessages; DisableStartupDialogs = $Conn.DisableStartupDialogs} -ArgsStr $ArgList

    $DumpDir = Get-1CLogDumpDir -Log $Log
    #$DumpGuid = (New-Guid).ToString();
    $DumpGuid = (Get-Date).ToString('yyyyMMdd-HHmmss-fff');
    $Dump = Add-1CPath -Path $DumpDir -AddPath ($ProcessName + '_' + $DumpGuid + '_Dump.log')
    $Out = Add-1CPath -Path $DumpDir -AddPath ($ProcessName + '_' + $DumpGuid + '_Out.log')

    if (-not $Log.ClearDump) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Dump' -LogText $Dump
    }

    # Add dump arguments '/DumpResult' '/Out'
    $ArgList = Get-1CArgs -TArgs @{DumpResult = $Dump; Out = $Out} -ArgsStr $ArgList -RoundValueSign '"'

    $File1Cv8 = Get-1CV8Exe -V8 $Conn.V8

    if ($Timeout -le 0) {
        $Timeout = [int]$Conn.Timeout
    }

    $Wait = ($Timeout -le 0)
    $Begin = Get-Date
    
    $Process = Start-Process -FilePath $File1cv8 -ArgumentList $ArgList -NoNewWindow -Wait:$Wait -PassThru

    $TimeoutExceeded = $false

    if ($Wait) {
        $End = Get-Date
    }
    else {
        $BorderDate = $Begin.AddSeconds($Timeout)
        While (-not $Process.HasExited) {
            if ((Get-Date) -gt $BorderDate) {
                $Process.Kill()
                $TimeoutExceeded = $true
                break
            }
            Start-Sleep -Seconds 1
        }
        $End = Get-Date
    }

    if ($Process.ExitCode -ne 0) {
        $Msg = 'Exit code ' + $Process.ExitCode.ToString()
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Error' -LogText $Msg
    }

    if (-not $TimeoutExceeded) {

        $DumpValue = Get-Content -Path $Dump -Raw
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'DumpResult' -LogText $DumpValue

        $OutValue = Get-Content -Path $Out -Raw
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Out' -LogText $OutValue
    
        Remove-1CResultDump -DumpFile $Dump
        Remove-1CResultDump -DumpFile $Out

    }
    else {
        $DumpValue = '1'
        $OutValue = 'Timeout exceeded'
    }

    $Result = Get-1CProcessResult -Dump $DumpValue -Out $OutValue -OK 1;
    if ($Result.Dump -ne '0') {$Result.OK = 0}

    $Result
}

# Standart return result.
function Get-1CProcessResult($Dump = '0', $Out = '', $OK = 1, $Msg = '') {
    @{Out = $Out; Dump = $Dump; OK = $OK; Msg = $Msg}      
}

function Remove-1CResultDump($DumpFile) {
    if (-not [string]::IsNullOrEmpty($DumpFile)) {
        Remove-Item -Path $DumpFile
    }
}

function Get-1CLogDumpDir($Log) {

    [string]$DumpDir = ''

    if ($Log) {
        $DumpDir = $Log.Dir
    }
 
    if ($DumpDir -eq '' -or $DumpDir -eq $null) {
        $DumpDir = $env:TEMP
    }
    Test-CmnDir -path $DumpDir -CreateIfNotExist | Out-Null

    $DumpDir
}

