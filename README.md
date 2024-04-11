# wsus_check_icinga2
Modify the PowerShell script Goldie2009/check_wsus for compatibility with Windows Server 2022 and integration with Icinga Director.
You can execute the script in cmd by invoking all its options, for example:
powershell -ExecutionPolicy Bypass -File ".\wsus_check.ps1" -Options "ComputersNeedingUpdates,ComputersWithErrors,ComputersNotContacted,ComputersNotAssigned,UpdatesNeededByComputersNotApproved" -WarningThreshold 10 -CriticalThreshold 20
