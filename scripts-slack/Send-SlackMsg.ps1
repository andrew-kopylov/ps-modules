Import-Module ($PSScriptRoot + '/modules/slack-module.ps1') -Force

$ScriptItem = $PSCommandPath | Get-Item 

# Read script config parameters
$Config = Get-Content -Path ($ScriptItem.DirectoryName + '\config\config.json') -Raw | ConvertFrom-Json
$ScriptConfig = Get-Content -Path ($ScriptItem.DirectoryName + '\config\' + $ScriptItem.BaseName + '.json') -Raw | ConvertFrom-Json

# Msg text hooked to slac
$AddText = ''
if (-not [string]::IsNullOrEmpty($args[0])) {
    $AddText = $args[0]
}
else {
    $AddText = "<no message>"
}

$MsgText = $Config.hostDescr + ' - ' + $AddText

Send-SlackWebHook -HookUrl $ScriptConfig.HookUrl -Text $MsgText
