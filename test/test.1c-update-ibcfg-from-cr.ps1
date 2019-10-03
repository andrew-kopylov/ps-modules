
D:\git\ps-modules\scripts-1c\update-ib-cfg-from-cr.ps1 `
-BaseDescr 'Update base test' `
-V8 '8.3.14.1565' `
-Srvr 'rdv-kaa:4541' `
-Ref 'updcr_base_srv' `
-Usr '' `
-Pwd '' `
-CRPath 'D:\work\bases\update_by_cr\cr-dev' `
-CRUsr 'fromdev_srv' `
-CRPwd '' `
-AgentSrvr 'rdv-kaa:4540' `
-BlockDelayMinutes 1 `
-BlockPeriodMinutes 1 `
-TerminateDesigner $true `
-DesignerOpenHours 0 `
-SlackHookUrl 'https://hooks.slack.com/services/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'