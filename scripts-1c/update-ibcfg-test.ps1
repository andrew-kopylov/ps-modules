
$PSItem= Get-Item -Path $PSCommandPath

$ConfigPath = Add-1CPath -Path $PSItem.DirectoryName -AddPath config, config.json
$Config = Get-Content -Path $ConfigPath | ConvertFrom-Json

#C:\scripts\update-ibcfg-from-cr.ps1 `
D:\git\ps-modules\scripts-1c\update-ibcfg-from-cr.ps1 `
-BaseDescr 'TEST-BASE' `
-V8 $Config.V8 `
-Srvr $Config.Srvr `
-Ref git-test-update-ib `
-Extension UpdateIBFromCRExt `
-Usr $Config.updaterUsr `
-Pwd $Config.updaterPwd `
-CRPath $Config.crPath `
-CRPathExt $Config.crPathExt `
-CRUsr $Config.crUsr `
-CRPwd $Config.crPwd `
-UseDynamicUpdate $false `
-BlockDelayMinutes 0.1 `
-BlockPeriodMinutes 1 `
-TerminateDesigner $true `
-SlackHookUrl $Config.slackHookUrl `
-SlackHookUrlAlerts $Config.slackHookUrlAlerts `
-DesignerOpenHours 2