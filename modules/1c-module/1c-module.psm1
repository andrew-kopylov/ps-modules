
####
# MANAGE 1C-MODULE
####

function Get-1CModuleVersion() {
    '1.4.2'
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
# INIT PARAMETERS FUNCTION
####

# Platform parameters {Ver, Cat}.
function Get-1CV8($Ver = '', $Dir = '') {
    @{Ver = $Ver; Dir = $Dir}
}

# Base connection parameters.
function Get-1CConn {
    param (
        $V8,
        $File,
        $Srvr,
        $Ref,
        $Usr,
        $Pwd,
        $CRPath,
        $CRUsr,
        $CRPwd,
        $Extension,
        $UC,
        $AgSrvr,
        $AgUsr,
        $AgPwd,
        $ClSrvr,
        $ClUsr,
        $ClPwd,
        [switch]$Visible
    )
    @{
        V8 = $V8;
        File = $File;
        Srvr = $Srvr;
        Ref = $Ref;
        Usr = $Usr;
        Pwd = $Pwd;
        CRPath = $CRPath;
        CRUsr = $CRUsr;
        CRPwd = $CRPwd;
        Extension = $Extension;
        UC = $UC;
        AgSrvr = $AgSrvr;
        AgUsr = [string]$AgUsr;
        AgPwd = [string]$AgPwd;
        ClSrvr = $ClSrvr;
        ClUsr = [string]$ClUsr;
        ClPwd = [string]$ClPwd;
        Visible = $Visible
    }
}

# Log parameters.
function Get-1CLog($Dir, $Name, $Dump, $ClearDump = $true) {
    # Log directory, Log file base name, Dump catalog for /Out /DumpResult
    @{Dir = $Dir; Name = $Name; Dump = $Dump; ClearDump = $ClearDump;}
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
    Invoke-1CProcess -Conn $Conn -ProcessCommand 'CheckConfig' -ProcessArgs $ProcessArgs -Log $Log
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
    Invoke-1CProcess -Conn $Conn -ProcessCommand 'CheckModules' -ProcessArgs $ProcessArgs -Log $Log
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
    
    $Result = Invoke-1CProcess -Conn $Conn -ProcessCommand $ProcessCommand -ProcessArgs $ProcessArgs -Log $Log
    
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

    $FirstCfgDescr = Add-String -Str $FirstConfigurationType -Add ($ArgsTable.FirstName + $ArgsTable.FirstFile + $ArgsTable.FirstVersion) -Sep ' '
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "Start.FirstCfg" -LogText $FirstCfgDescr
    
    $SecondCfgDescr = Add-String -Str $SecondConfigurationType -Add ($ArgsTable.SecondName + $ArgsTable.SecondFile + $ArgsTable.SecondVersion) -Sep ' '
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "Start.SecondCfg" -LogText $SecondCfgDescr
    
    $Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log

    Remove-1CResultDump -Log $Log -DumpFile $ResultObjectsArgument.DumpFile

    if ($Result.OK -ne 1) {
        $Msg = 'Ошибка сравнения конфигураций.';
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "End.Error" -LogText $Msg -Result $Result
    };

    $Result;      
}

function Invoke-1CMergeCfg {
    param {
        $CfgFile,
        $SettingsFile,
        [ValidateSet('Enable', 'Disable')]
        $Support,
        [ValidateSet('IncludeObjects', 'Clear')]
        $UnresolvedRefs,
        [switch]$Force
    }

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

    $Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log

    $Result;
}

function Invoke-1CDumpCfg($Conn, $CfgFile, $Log) {

    $ProcessName = 'DumpCfg';
    $ProcessArgs = '/DumpCfg "[CfgFile]"';
    $ProcessArgs = $ProcessArgs.Replace('[CfgFile]', $CfgFile);

    Test-AddDir -Path ([System.IO.Path]::GetDirectoryName($CfgFile))

    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead "Start.CfgFile" -LogText $CfgFile

    $Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log
    if ($Result.OK -ne 1) {
        $Msg = "Ошибка выгузки файла конфигурации.";
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


####
# CONFIGURAITON REPOSITORY COMMANDS
####

## Public repository functions.

function Invoke-1CCRCreate{
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

function Invoke-1CCRUpdateCfg($Conn, $v, $Revised, $force, $Objects, [switch]$includeChildObjectsAll, $Log) {

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

    Test-AddDir -Path ([System.IO.Path]::GetDirectoryName($CfgFile))

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
        $Result.Msg = Add-String -Str $Result.Msg -Add $ResultLocalDB.Msg
        $Result.Msg = Add-String -Str $Result.Msg -Add $ResultGlobal.Msg
        $Result.Msg = Add-String -Str $Result.Msg -Add $ResultLocal.Msg
        $Result.Out = Add-String -Str $Result.Out -Add $ResultLocalDB.Out
        $Result.Out = Add-String -Str $Result.Out -Add $ResultGlobal.Out
        $Result.Out = Add-String -Str $Result.Out -Add $ResultLocal.Out
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
                $Version.Version = $ParamValue.Trim();

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

function Invoke-1CCROptimizeData ($Conn, $Log) {
    $ProcessArgs = '/ConfigurationRepositoryOptimizeData';
    Invoke-1CProcess -Conn $Conn -ProcessName 'CROptimizeData' -ProcessArgs $ProcessArgs -Log $Log
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

function Get-1CCRVersionTmpl {
    return @{
        Version = 0;
        User = '';
        Date = $null;
        Time = $null;
        Comment = '';
        #Added = $null;
        #Changed = $null;
        #Deleted = $null;
    }
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
    $ProcessArgs = Add-String -Str $ProcessArgs -Add $AddCmd -Sep ' '

    [hashtable]$Result = Invoke-1CProcess -ProcessName $ProcessName -ProcessArgs $ProcessArgs -Conn $Conn -Log $Log
 
    Remove-1CResultDump -Log $Log -DumpFile $ResultObjectsArgument.DumpFile
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
# 1C-Administration
####


function Test-1CConfigurationChanged($Conn) {
    $ComConn = Get-1CComConnection -Conn $Conn
    $IsChanged = Invoke-ComObjectMethod -ComObject $ComConn -MethodName 'ConfigurationChanged'
    Remove-Variable -Name 'ComConn'
    $IsChanged
}

function Stop-1CIBSessions($Conn, [string]$TermMsg, $AppID, $StartedBefore, $Log) {
    $ProcessName = 'TeminateSessions'
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogText ('Start "' + $TermMsg + '"')
    $SessionsInfo = Get-1CIBSessions -Conn $Conn
    $Agent = $SessionsInfo.Agent
    $Sessions = $SessionsInfo.Sessions
    $TerminatedSessions = @()
    foreach ($Session in $Sessions) {

        # Filter by AppID (1CV8, 1CV8C, Designer, COMConsole, SrvrConsole, ...)
        if ($AppID -ne $null -and $Session.AppID -notin $AppID) {continue}
        if ($StartedBefore -ne $null -and $Session.StartedAt -ge $StartedBefore) {continue}
        
        if ($Session.AppID -ne 'SrvrConsole') {
            $Agent.TerminateSession($SessionsInfo.Cluster, $Session, $TermMsg)
            $SessionDescr = [ordered]@{
                ID = $Session.SessionID;
                User = $Session.UserName;
                AppID = $Session.AppID;
                Host = $Session.Host;
                Started = $Session.StartedAt;
                cpuCurr = $Session.cpuTimeCurrent;
                cpu5min = $Session.cpuTimeLast5Min;
            }
            $TerminatedSessions += $Session;
            $SessionDescr = Get-1CArgs -TArgs $SessionDescr -ArgEnter '' -ValueSep '=' -ArgSep ' '
            Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Done' -LogText ('Session ' + $SessionDescr)

        }
    }    
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogText 'End'
    @{TerminatedSessions = $TerminatedSessions}
 }

function Get-1CIBSessions($Conn) {

    $ClusterInfo = Get-1CCluster -Conn $Conn -Auth
    
    $Agent = $ClusterInfo.Agent
    $Cluster = $ClusterInfo.Cluster
    
    $InfoBases = $Agent.GetInfoBases($Cluster)

    $FindedInfoBase = $null

    foreach ($InfoBase in $InfoBases) {
        if ($Conn.Ref -isnot [string]) {continue}
        [string]$InfoBaseName = $InfoBase.Name
        if ($InfoBaseName.ToUpper() -eq $Conn.Ref.ToUpper()) {
            $FindedInfoBase = $InfoBase;
            break
        }
    }

    $Sessions = $Agent.GetInfoBaseSessions($Cluster, $FindedInfoBase)

    @{
        Agent = $Agent;
        Cluster = $Cluster;
        InfoBase = $FindedInfoBase;
        Sessions = $Sessions;
    }
}

function Set-1CIBSessionsDenied($Conn, [switch]$Denied, $From, $To, [string]$Msg, [string]$PermissionCode) {

    if ($From -is [datetime]) {
        $From = $From.ToString('yyyy-MM-dd HH:mm:ss')
    }

    if ($To -is [datetime]) {
        $To = $To.ToString('yyyy-MM-dd HH:mm:ss')
    }
    
    $IBInfo = Get-1CIBInfo -Conn $Conn
    $InfoBase = $IBInfo.InfoBase
    $InfoBase.ConnectDenied = $Denied
    if ($Denied) {
        $InfoBase.DeniedFrom = $From
        $InfoBase.DeniedTo = $To
        $InfoBase.DeniedMessage = $Msg
        if ($PermissionCode -ne '') {
            $InfoBase.PermissionCode = $PermissionCode
        }
    }
    $IBInfo.WPConnection.UpdateInfoBase($InfoBase)
    $IBInfo
}

function Get-1CIBInfo($Conn) {
    
    $WPInfo = Get-1CWorkingProcessConnection -Conn $Conn -Auth

    $WPConnection = $WPInfo.WPConnection
    if ($Conn.Usr -ne $null -and $Conn.Usr -ne '') {
        $WPConnection.AddAuthentication($Conn.Usr, $Conn.Pwd)
    } 

    $InfoBases = $WPConnection.GetInfoBases()

    $FindedInfoBase = $null

    foreach ($InfoBase in $InfoBases) {
        if ($Conn.Ref -isnot [string]) {continue}
        [string]$InfoBaseName = $InfoBase.Name
        if ($InfoBaseName.ToUpper() -eq $Conn.Ref.ToUpper()) {
            $FindedInfoBase = $InfoBase;
            break
        }
    }
   
    @{
        Agent = $WPInfo.Agent;
        Cluster = $WPInfo.Cluster;
        WorkingProcess = $WPInfo.WorkingProcess;
        WPConnection = $WPConnection;
        InfoBase = $FindedInfoBase;
    }
}

function Get-1CWorkingProcessConnection($Conn, $WorkingProcess, [switch]$Auth) {

    $ClusterInfo = Get-1CCluster -Conn $Conn -Auth:$Auth   
    if ($ClusterInfo -eq $null -or $ClusterInfo.Cluster -eq $null) {
        return $null
    }

    if ($WorkingProcess -eq $null) {
        $WorkingProcesses = $ClusterInfo.Agent.GetWorkingProcesses($ClusterInfo.Cluster)
        if ($WorkingProcesses -eq $null -or $WorkingProcesses.GetLength(0) -eq 0) {
            return $null
        }
        $WorkingProcess = $WorkingProcesses.GetValue($WorkingProcesses.GetUpperBound(0))
    }
    
    $ComConntector = Get-1CComConnector -V8 $Conn.V8
    $WPConnection = $ComConntector.ConnectWorkingProcess($WorkingProcess.hostname + ':' + $WorkingProcess.MainPort)

    if ($Auth -and $WPConnection -ne $null) {
        $WPConnection.AuthenticateAdmin($Conn.ClUsr, $Conn.ClPwd)
    }

    @{
        Agent = $ClusterInfo.Agent;
        Cluster = $ClusterInfo.Cluster;
        WorkingProcess = $WorkingProcess;
        WPConnection = $WPConnection;
    }
}

function Get-1CWorkingProcesses($Conn, $Agent, $Cluster, [switch]$Auth) {

    if ($Agent -eq $null) {
        $Agent = Get-1CAgent -Conn $Conn -Auth:$Auth
    }

    if ($Cluster -eq $null) {
        $ClusterInfo = Get-1CCluster -Conn $Conn -Agent $Agent -Auth:$Auth   
        if ($ClusterInfo -eq $null -or $ClusterInfo.Cluster -eq $null) {
            return $null
        }
        $Agent = $ClusterInfo.Agent
        $Cluster = $ClusterInfo.Cluster
    }
    
    $WorkingProcesses = $Agent.GetWorkingProcesses($Cluster)

    @{
        Agent = $Agent;
        Cluster = $Cluster;
        WorkingProcesses = $WorkingProcesses;
    }
}

function Get-1CAllClusters($Conn, $Agent, [switch]$Auth) {
    
    if ($Agent -eq $null) {
        $Agent = Get-1CAgent -Conn $Conn -Auth:$Auth
    }
    if ($Agent -eq $null) {
        return $null
    }
    $Clusters = $Agent.GetClusters()

    foreach ($Cluster in $Clusters) {
        # Authentication on Cluster
        if ($Auth) {
            $Agent.Authenticate($Cluster, $Conn.ClUsr, $Conn.ClPwd)
        }
    }
    @{Agent = $Agent; Clusters = $Clusters}
}

function Get-1CCluster($Conn, $Agent, [switch]$Auth) {
    
    if ($Agent -eq $null) {
        $Agent = Get-1CAgent -Conn $Conn -Auth:$Auth
    }
    if ($Agent -eq $null) {
        return $null
    }
    $Clusters = $Agent.GetClusters()

    $FindedCluster = $null

    # Cluster search
    if ($Clusters.GetLength(0) -eq 0) {
        # No clasters.
    } elseif ($Clusters.GetLength(0) -eq 1) {
       $FindedCluster = $Clusters.GetValue($Clusters.GetUpperBound(0))
    } else {
        foreach ($Cluster in $Clusters) {
            if (Test-1CClusterConn -Cluster $Cluster -Conn $Conn) {
                $FindedCluster = $Cluster
                break;
            }     
        }
        if ($FindedCluster -eq $null -and $Clusters.GetLength(0) -gt 1) {
            $FindedCluster = $Clusters.GetValue($Clusters.GetUpperBound(0))
        }
    }

    # Authentication on Cluster
    if ($Auth -and $FindedCluster -ne $null) {
        $Agent.Authenticate($FindedCluster, $Conn.ClUsr, $Conn.ClPwd)
    }

    @{Agent = $Agent; Cluster = $FindedCluster}
}

function Test-1CClusterConn($Cluster, $Conn) {
    if (Test-1CClusterSrvrString -Cluster $Cluster -Srvr $Conn.ClSrvr) {
        return ($true)
    } elseif (Test-1CClusterSrvrString -Cluster $Cluster -Srvr $Conn.Srvr) {
        return ($true)
    } elseif ($Conn.AgSrvr -is [string] -and $Conn.AgSrvr -ne '') {
        $AgSrvr = $Conn.AgSrvr.Split(':')[0];
        $AgPort = $Conn.AgSrvr.Split(':')[1];
        $AgPort = Get-ValueIfEmpty -Value $AgPort -IfEmptyValue '1540'
        $ClPort = [decimal]$AgPort + 1
        if ($Cluster.HostName -eq $AgSrvr -and $Cluster.MainPort -eq $ClPort) {
            return ($true)
        }
    }
    ($false)
}

function Test-1CClusterSrvrString($Cluster, [string]$Srvr) {
    [string]$ClusterConnStr = $Cluster.HostName + ':' + $Cluster.MainPort
    return ($ClusterConnStr.ToUpper() -eq $Srvr.ToUpper() -or $ClusterConnStr.ToUpper() -eq ($Srvr + ':1541').ToUpper())
}

function Get-1CAgent($Conn, [switch]$Auth) {
    $ComConnector = Get-1CComConnector -V8 $Conn.V8
    $AgentConnStr = $Conn.AgSrvr;
    if ($AgentConnStr -eq '' -or $AgentConnStr -eq $null) {
        $SubstrSrvr = $Conn.Srvr.Split(':')
        $AgentConnStr = $SubstrSrvr[0]
    }
    if ($AgentConnStr -eq '' -or $AgentConnStr -eq $null) {
        $AgentConnStr = 'localhost';
    }
    $AgentConn = $ComConnector.ConnectAgent($AgentConnStr)
    if ($Auth) {
        $AgentConn.AuthenticateAgent($Conn.AgUsr, $Conn.AgPwd)
    }
    $AgentConn;
}


####
# COM-Connector (work with com-objects)
####

function Convert-1CMXLtoTXT($ComConn, $MXLFile, $TXTFile) {
    # $ComConn - reterned by Get-1CComConnection
    # SD - sheet document.
    $SDFileTypeTXT = (Get-ComObjectProperty -ComObject $ComConn -PropertyName 'ТипФайлаТабличногоДокумента')[3]
    $SD = Invoke-ComObjectMethod -ComObject $ComConn -MethodName 'NewObject' -Parameters 'ТабличныйДокумент'
    Invoke-ComObjectMethod -ComObject $SD -MethodName 'Прочитать' -Parameters $MXLFile
    Invoke-ComObjectMethod -ComObject $SD -MethodName 'Записать' -Parameters ($TXTFile, $SDFileTypeTXT)
}

function Get-1CComConnection($Conn) {
    $ComConnector = Get-1CComConnector -V8 $Conn.V8
    $ComConnStr = Get-1CComConnectionString -Conn $Conn
    $ComConn = $ComConnector.Connect($ComConnStr)
    return $ComConn
}

function Get-1CComConnectionString($Conn) {
    $TArgs = [ordered]@{
        File = $Conn.File;
        Srvr = $Conn.Srvr;
        Ref = $Conn.Ref;
        Usr = $Conn.Usr;
        Pwd = $Conn.Pwd;
        UC = $Conn.UC;
    }
    $ArgsStr = Get-1CArgs -TArgs $TArgs -ArgEnter '' -ValueSep '=' -ArgSep ';'
    $ArgsStr
}

function Register-1CComConnector($V8) {
    $BinDir = Get-1CV8Bin -V8 $V8
    $DllPath = Add-1CPath -Path $BinDir -AddPath 'comcntr.dll'
    $ProcessArgs = '/s "' + $DllPath + '"'
    Start-Process -FilePath 'regsvr32.exe' -ArgumentList $ProcessArgs -NoNewWindow
}

function Get-1CComConnector($V8) {
    New-Object -ComObject 'V83.ComConnector' -Strict 
}

function Get-1CComObjectString($ComConn, $ComObject) {
    Invoke-ComObjectMethod -ComObject $ComConn -MethodName 'String' -Parameters $ComObject
}

function Get-ComObjectProperty($ComObject, $PropertyName) {
    $PropertyValue = [System.__ComObject].InvokeMember($PropertyName, [System.Reflection.BindingFlags]::GetProperty, $null, $ComObject, $null)
    $PropertyValue
}

function Invoke-ComObjectMethod($ComObject, $MethodName, $Parameters) {
    $MethodReturn = [System.__ComObject].InvokeMember($MethodName, [System.Reflection.BindingFlags]::InvokeMethod, $null, $ComObject, $Parameters)
    $MethodReturn
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
        $ConnStr = Get-1CConnString -Conn $Conn
    }

    if (Test-1CHashTable -Object $ProcessArgs) {
        $ProcessArgs = Get-1CArgs -TArgs $ProcessArgs -ArgEnter '-' -ValueSep ' ' -ArgSep ' ' -RoundValueSign '"'
    }

    $ArgList = ''
    $ArgList = Add-String -Str $ArgList -Add $Mode -Sep ' '
    $ArgList = Add-String -Str $ArgList -Add $ConnStr -Sep ' '
    $ArgList = Add-String -Str $ArgList -Add $ProcessCommand -Sep ' /'
    $ArgList = Add-String -Str $ArgList -Add $ProcessArgs -Sep ' '

    if ([String]::IsNullOrEmpty($ProcessName)) {
        $ProcessName = $ProcessCommand
    }
   
    if ($Conn -ne $null) {
        $Base = Get-1CConnStringBase -Conn $Conn
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Start.Base' -LogText $Base
    }

    if (-not [String]::IsNullOrEmpty($Conn.CRPath)) {
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Start.ConfRep' -LogText $Conn.CRPath
    }

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
    
    $Process = Start-Process -FilePath $File1cv8 -ArgumentList $ArgList -NoNewWindow -Wait -PassThru
    if ($Process.ExitCode -ne 0) {
        $Msg = 'Exit code ' + $Process.ExitCode
        Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Error' -LogText $Msg
    }

    $DumpValue = Get-Content -Path $Dump -Raw
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'DumpResult' -LogText $DumpValue

    $OutValue = Get-Content -Path $Out -Raw
    Add-1CLog -Log $Log -ProcessName $ProcessName -LogHead 'Out' -LogText $OutValue
    
    Remove-1CResultDump -Log $Log -DumpFile $Dump
    Remove-1CResultDump -Log $Log -DumpFile $Out

    $Result = Get-1CProcessResult -Dump $DumpValue -Out $OutValue -OK 1;
    if ($Result.Dump -ne '0') {$Result.OK = 0}

    $Result
}

# Get arguments string.
function Get-1CArgs($TArgs, $ArgsStr = '', $ArgEnter = '/', $ValueSep = ' ', $ArgSep = ' ', $RoundValueSign = '', [switch]$IsMandatoryRoundSign) {
    foreach ($ArgKey in $TArgs.Keys) {
        $ArgValue = $TArgs.($ArgKey)

        if ($ArgValue -eq $null) {continue}

        $ArgStr = ''
        if ($ArgValue -is [bool] -or $ArgValue -is [switch]) {
            if ($ArgValue -eq $true) {
                $ArgStr = $ArgEnter + $ArgKey
            }
        }
        elseif ($ArgValue -is [string]) {
            if (('[' + $ArgKey + ']').ToUpper() -eq $ArgValue.ToUpper()) {
                # It's template: ArgValue = '[ArgKey]' then adding only ArgValue as template.
                $ArgStr = $ArgValue
            }
            elseif ($IsMandatoryRoundSign -or ($ArgValue -match '\s')) {
                $ArgStr = $ArgEnter + $ArgKey + $ValueSep + (Add-RoundSign -Str $ArgValue -RoundSign $RoundValueSign)
            }
            else {
                $ArgStr = $ArgEnter + $ArgKey + $ValueSep + $ArgValue
            }
        }
        else {
            $ArgStr = $ArgEnter + $ArgKey + $ValueSep + $ArgValue.ToString()
        }
        $ArgsStr = Add-String -Str $ArgsStr -Add $ArgStr -Sep $ArgSep
    }
    $ArgsStr
}

# Standart return result.
function Get-1CProcessResult($Dump = '0', $Out = '', $OK = 1, $Msg = '') {
    @{Out = $Out; Dump = $Dump; OK = $OK; Msg = $Msg}      
}

function Remove-1CResultDump($Log, $DumpFile) {
    if ($Log.ClearDump) {  
        if ($DumpFile -is [string] -and $DumpFile -ne '') {
            Remove-Item -Path $DumpFile
        }
    }
}

function Get-1CLogDumpDir($Log) {

    [string]$DumpDir = ''

    if ($Log -ne $null) {
        $DumpDir = $Log.Dump
    }
 
    if ($DumpDir -eq '' -or $DumpDir -eq $null) {
        $DumpDir = $env:TEMP
    }
    Test-AddDir -path $DumpDir

    $DumpDir
}

# Log text for 1C process. 
function Add-1CLog($Log, $ProcessName, $LogHead = "", $LogText, $Result = $null, $OK = $null) {

    $LogDir = ''
    $LogName = ''
    $LogMark = $ProcessName;

    if ($Log -ne $null) {
        $LogDir = $Log.Dir
        $LogName = $LogName.Name
    }

    if ($LogDir -eq '') {
        $LogDir = Get-1CLogDumpDir -Log $Log
    }
    Test-AddDir -path $LogDir

    $LogName = $Log.Name;
    if ($LogName -eq '') {
        $LogName = "1c-module";
    }

    $OutLogText = Add-LogText -LogDir $LogDir -LogName $LogName -LogMark $ProcessName -LogHead $LogHead -LogText $LogText;
      
    if ($Result -ne $null) {
         if ($OK -ne $null) {$Result.OK = $OK}
         $Result.Msg = Add-String -Str $Result.Msg -Add $LogText
    }
}

# Return full filename 1cv8 ".../bin/1cv8.exe".
function Get-1CV8Exe($V8) {
    Add-1CPath -Path (Get-1Cv8Bin -V8 $V8) -AddPath '1cv8.exe'
}

function Get-1CV8Bin($V8) { 
    $V8 = 1CV8VerInfo -V8 $V8
    $V8DirVer = Add-1CPath -Path $V8.Dir -AddPath $V8.Ver
    Add-1CPath -Path $V8DirVer -AddPath 'bin'
}

function Get-1CV8VerInfo($V8) {

    if ($V8 -eq $null) {
        $V8Dir = ''
        $V8Ver = ''
    }
    elseif ($V8 -is [string]) {
        $V8Dir = ''
        $V8Ver = $V8
    }
    else {
        $V8Dir = $V8.Dir     
        $V8Ver = $V8.Ver
    }

    $V8Dir32 = 'C:\Program Files (x86)\1cv8'
    $V8Dir64 = 'C:\Program Files\1cv8'

    if ($V8Dir -eq 'x64') {
        $V8Dir = $V8Dir64
    }
    elseif ($V8Dir -eq 'x32') {
        $V8Dir = $V8Dir32
    }
    if ($V8Ver -eq 'x64') {
        $V8Ver = ''
        $V8Dir = $V8Dir64
    }
    elseif ($V8Ver -eq 'x32') {
        $V8Ver = ''
        $V8Dir = $V8Dir32
    }
    else {
        if (Test-Path -Path $V8Dir64) {
            $V8Dir = $V8Dir64
        }
        else {
            $V8Dir = $V8Dir32
        }    
    }

    if ($V8Ver -eq '' -or $V8Ver -eq $null) {
        # Seach last version.
        $DirMask = Add-1CPath -Path $V8Dir -AddPath ('*.*.*.*')
        $LastVerDir = Get-ChildItem -Path $DirMask -Directory | Sort-Object -Property 'Name' | Select-Object -Last 1
        $V8Ver = $LastVerDir.Name
        $V8Dir = $LastVerDir.Parent.FullName
    }

    @{Dir = $V8Dir; Ver = $V8Ver}
}

function Get-1CConnStringCommon($Conn) {
    
    $TArgs = [ordered]@{}

    if (-not [String]::IsNullOrEmpty($Conn.File)) {
        $TArgs.File = $Conn.File
    }
    else {
        $TArgs.Srvr = $Conn.Srvr
        $TArgs.Ref = $Conn.Ref
    }

    if (-not [String]::IsNullOrEmpty($Conn.Usr)) {
        $TArgs.Usr = $Conn.Usr
        $TArgs.Pwd = $Conn.Pwd
    }

    $ConnString = (Get-1CArgs -TArgs $TArgs -ArgEnter '' -ValueSep '=' -ArgSep ';' -RoundValueSign '""' -IsMandatoryRoundSign) + ';'
    $ConnString
}

function Get-1CConnString($Conn) {
    $Base = Get-1CConnStringBase -Conn $Conn
    $Auth = Get-1CConnStringAuth -Conn $Conn
    $CR = Get-1CCRConnString -Conn $Conn
    $ConnStr = ''
    if ($Conn.UC -ne $null -and $Conn.UC -ne '') {
        $ConnStr = Add-String -str $ConnStr -Add ('/UC ' + $Conn.UC) -Sep ' ';
    }
    $ConnStr = Add-String -str $ConnStr -Add $Base -Sep ' ';
    $ConnStr = Add-String -str $ConnStr -Add $Auth -Sep ' ';
    $ConnStr = Add-String -str $ConnStr -Add $CR -Sep ' ';

    if ($Conn.Visible -eq $true) {
        $ConnStr = Add-String -str $ConnStr -Add ' /Visible' -Sep ' ';
    }

    $ConnStr 
}

function Get-1CConnStringBase($Conn) {
    # Base path parameters $Prm @{File, Srvr, Ref}.
    $Base = '';
    if ($Conn.File -ne '' -and $Conn.File -ne $null) {
        $Base = '/F "[File]"';
        $Base = $Base.Replace("[File]", $Conn.File);
    }
    elseif ($Conn.Ref -ne '' -and $Conn.Ref -ne $null) {
        $Base = '/S "[Srvr]\[Ref]"';
        $Base = $Base.Replace("[Srvr]", $Conn.Srvr);
        $Base = $Base.Replace("[Ref]", $Conn.Ref);
    }
    $Base;
}

function Get-1CConnStringAuth($Conn) { 
    # Authorization parameters @{Usr, Pwd}.
    $Auth = ''
    if (($Conn.File -ne '' -and $Conn.File -ne $null) -or ($Conn.Ref -ne '' -and $Conn.Ref -ne $null)) {
        $Auth = '/N "[Usr]" /P "[Pwd]"'
        $Auth = $Auth.Replace("[Usr]", $Conn.Usr)
        $Auth = $Auth.Replace("[Pwd]", $Conn.Pwd)
    }
    $Auth
}

function Get-1CCRConnString($Conn) {
    [string]$ConnStr = ''
    if ($Conn.CRPath -ne '' -and $Conn.CRPath -ne $null) {
        $ConnStr = '/ConfigurationRepositoryF "[Path]" /ConfigurationRepositoryN "[Usr]" /ConfigurationRepositoryP "[Pwd]"';
        $ConnStr = $ConnStr.Replace("[Path]", $Conn.CRPath);
        $ConnStr = $ConnStr.Replace("[Usr]", $Conn.CRUsr);
        $ConnStr = $ConnStr.Replace("[Pwd]", $Conn.CRPwd);
        if ($Conn.Extension -ne '' -and $Conn.Extension -ne $null) {
            $ConnStr = Add-String -Str $ConnStr -Add ('-Extension ' + $Conn.Extension) -Sep ' '
        }
    }
    $ConnStr; 
}


####
# Auxiliary functions
####

# Test dir, if not exist then add it.
function Test-AddDir($Path) {
    if ($Path -eq $null) {Return}
    $TestRes = Test-Path -Path $Path
    if (-not $TestRes) {
        New-Item -Path $Path -ItemType Directory
    }
}

# Log text: 
function Add-LogText($LogDir, $LogName, $LogMark = '', $LogHead = '', $LogText) {
    
    if ($LogText -eq '') {
        return;
    };
    Test-AddDir -Path $LogDir

    $LogDate = Get-Date
    $LogFile = Add-1CPath -Path $LogDir -AddPath ($LogDate.ToString('yyyyMMdd') + '_' + $LogName + '.log')

    $FullLogText = $LogDate.ToString('yyyy.MM.dd HH:mm:ss');
    $FullLogText = Add-String -Str $FullLogText -Add $LogMark -Sep ' ';
    $FullLogText = Add-String -Str $FullLogText -Add $LogHead -Sep '.';
    $FullLogText = Add-String -Str $FullLogText -Add $LogText -Sep ': ';

    $FullLogText | Out-File -FilePath $LogFile -Append;
    $FullLogText | Out-Host;
    $FullLogText
}

function Add-String([string]$Str, [string]$Add, [string]$Sep = '') {
    if ($Str -eq '') {$ResStr = $Add}
    elseif ($Add -eq '') {$ResStr = $Str}
    else {$ResStr = $Str + $Sep + $Add};
    $ResStr;
} 

function Add-RoundSign($Str, $RoundSign) {
    if ([String]::IsNullOrEmpty($Str)) {return $Str}
    if (-not $Str.StartsWith($RoundSign)) {$Str = $RoundSign + $Str}
    if (-not $Str.EndsWith($RoundSign)) {$Str = $Str + $RoundSign}
    $Str
}

function Remove-RoundSign([string]$Str, [string]$RoundSign) {
    if ([String]::IsNullOrEmpty($Str)) {return $Str}
    $Str.Trim($RoundSign)   
}

function Add-1CPath([string]$Path, $AddPath, $Sep = '\') {
    
    if ([String]::IsNullOrEmpty($AddPath)) {return $Path}
    if ([String]::IsNullOrEmpty($Path)) {return $AddPath}

    if ($AddPath -is [System.Array]) {
        foreach ($AddPathItem in $AddPath) {
            $Path = Add-1CPath -Path $Path -AddPath $AddPathItem -Sep $Sep
        }
    }
    else {
        if ($Path.EndsWith($Sep)) {
            $Path = $Path.Substring(0, $Path.Length - 1)
        }

        if ($AddPath.StartsWith($Sep)) {
            $AddPath = $AddPath.Substring(1, $Path.Length - 1)
        }
        $Path = $Path + $Sep + $AddPath    
    }

    $Path
}

function Get-ValueIsEmpty($Value, $AddEmptyValues) {
    $EmptyValues = ($null, '', 0)
    ($Value -in $EmptyValues -or $Value -in $AddEmptyValues)
}

function Get-ValueIfEmpty($Value, $IfEmptyValue, $AddEmptyValues) {
    if (Get-ValueIsEmpty -Value $Value -AddEmptyValues $AddEmptyValues) {
        return $IfEmptyValue
    }
    $Value
}

function Get-ValueIfNull($Value, $IfNullValue) {
    if ($Value -eq $null) {
        return $IfNullValue
    }
    $Value
}

function Get-1CPropertyValues {
    param (
        $Collection,
        $Property
    )
    
    begin {
        $ValuesArray = @()
        if ($Collection -ne $null) {
            $ValuesArray = ($Collection | Get-1cPropertyValues -Property $Property)
        }
    }

    process {
        if ($_ -is [System.Array]) {
            $NewValuesArray = ($_ | Get-1cPropertyValues -Property $Property)
            foreach ($PropertyValue in $NewValuesArray) {
                if ($PropertyValue -ne $null -and $PropertyValue -notin $ValuesArray) {
                    $ValuesArray += $PropertyValue
                }
            }
        }
        elseif ($_ -ne $null) {
            $PropertyValue = $_.$Property
            if ($PropertyValue -ne $null -and $PropertyValue -notin $ValuesArray) {
                $ValuesArray += $PropertyValue
            }
        }
    }
    end {
        $ValuesArray
    }
}

function Test-1CHashTable ($Object) {
    if ($Object -eq $null) {return $false}
    # Is HashTable or OrderedDictionary
    (($Object -is [hashtable]) -or ($Object -is [System.Object] -and $Object.GetType().name -eq 'OrderedDictionary'))
}
