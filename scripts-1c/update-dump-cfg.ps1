# Recieve last dev configuration
$ModulePath = $PSScriptRoot + "\modules\1c-module.ps1"
Import-Module $ModulePath -Force

# Current Powershell command file
$PSCmdFile = Get-Item -Path $PSCommandPath

# Platform version
$V8Dev = Get-1CV8 -Ver '8.3.14.1565' #develop

# Develop Config
$ConnDev = Get-1CConn -V8 $V8Dev -File 'c:\cr-dev-base'  -Usr 'UserName' -Pwd 'Password' -CRPath 'tcp://confrep/rep1' -CRUsr 'RepUser' -CRPwd 'Password'
$CfgDevFile = $PSCmdFile.DirectoryName + '\dev.cf'

# Log
$Log = Get-1CLog -Dir ($PSCmdFile.DirectoryName + '\logs') -Name $PSCmdFile.BaseName -Dump ($PSCmdFile.DirectoryName + '\logs')

$ResultUCF = Invoke-1CCRUpdateCfg -Conn $ConnDev -Log $Log
if ($ResultUCF.ProcessedObjects -gt 0) {
    Invoke-1CUpdateDBCfg -Conn $ConnDev -Log $Log
    Invoke-1CDumpCfg -Conn $ConnDev -CfgFile $CfgDevFile -Log $Log
}
