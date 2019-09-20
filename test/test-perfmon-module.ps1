
Import-Module ($PSScriptRoot + "\modules\perfmon-module.ps1") -Force

#Create-PmIamAliveAlertTask -SendMsgScript 'D:\git\ps-modules\scripts-slack\Send-SlackMsg.ps1'

#Invoke-PmLogmanCommand -Verb create -Adverb counter

Create-PmCounter -Name 'Order monitor (bin1)' -Counters '\Processor(_Total)\% Processor Time' -Format bin

#Export-PmGroup -Name 'Order monitor (bin)' -XMLFile 'd:\om.xml'

