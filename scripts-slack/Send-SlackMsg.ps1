Import-Module ($PSScriptRoot + '/modules/slack-module.ps1') -Force

$HookUrl = 'https://hooks.slack.com/services/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'
$MsgText = 'Ya.Lavka Prod 1C-server - ' + $args[0]

Send-SlackWebHook -HookUrl $HookUrl -Text $MsgText