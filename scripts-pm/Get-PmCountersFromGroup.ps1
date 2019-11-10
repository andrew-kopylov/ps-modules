Import-Module perfmon-module -Force

Update-PmCountersTable -CounterGroupName 'New counters' -FilePath 'd:\New counters.xml'
