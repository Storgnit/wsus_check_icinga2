param (
    [string]$Options,
    [int]$WarningThreshold,
    [int]$CriticalThreshold
)

# Variables - set these to fit your needs
###############################################################################

$serverName = 'wsus.server.ru'
$useSecureConnection = $False
$portNumber = 8530
$daysBeforeWarn = 60

# Script - don't change anything below this line!
###############################################################################

# Load WSUS framework
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")

# Connect to specified WSUS server
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($serverName, $useSecureConnection, $portNumber)

# Get general status information
$status = $wsus.GetStatus()
$totalComputers = $status.ComputerTargetCount

function Generate-Output {
    param (
        [int]$CurrentValue,
        [string]$Message,
        [string]$PerfDataLabel
    )
    
    $returnCode = 0
    if ($CurrentValue -gt $WarningThreshold) {
        $returnCode = 1
        if ($CurrentValue -gt $CriticalThreshold) {
            $returnCode = 2
        }
    }
    $perfdata = "|'$PerfDataLabel'=$CurrentValue;$WarningThreshold;$CriticalThreshold;0;$totalComputers"

    # Return a single string with comma-separated values
    return "$returnCode, $CurrentValue $Message, $perfdata"
}

$returnCode = 0
$optionsArray = $Options -split ','

foreach ($Option in $optionsArray) {
    switch ($option.Trim()) {
        "ComputersNeedingUpdates" {
            $computerTargetScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
            $computerTargetScope.IncludedInstallationStates = [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::NotInstalled -bor [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::InstalledPendingReboot -bor [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::Downloaded
            $computerTargetScope.ExcludedInstallationStates = [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::Failed
            $count = $wsus.GetComputerTargetCount($computerTargetScope)
            $tempReturnCode, $output, $perfdata = (Generate-Output $count "Client(s) needing updates." "Clients_needing_updates") -split ', '
        }
        "ComputersWithErrors" {
            $computerTargetScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
            $computerTargetScope.IncludedInstallationStates = [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::Failed
            $count = $wsus.GetComputerTargetCount($computerTargetScope)
            $tempReturnCode, $output, $perfdata = (Generate-Output $count "Client(s) with errors." "Clients_with_errors") -split ', '
        }
        "ComputersNotContacted" {
            $timeSpan = New-Object TimeSpan ($daysBeforeWarn, 0, 0, 0)
            $count = $wsus.GetComputersNotContactedSinceCount([DateTime]::UtcNow.Subtract($timeSpan))
            $tempReturnCode, $output, $perfdata = (Generate-Output $count "Client(s) not contacted in last $daysBeforeWarn days." "Clients_not_contacted") -split ', '
        }
        "ComputersNotAssigned" {
            $computerTargetScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
            $count = $wsus.GetComputerTargetGroup([Microsoft.UpdateServices.Administration.ComputerTargetGroupId]::UnassignedComputers).GetComputerTargets().Count
            $tempReturnCode, $output, $perfdata = (Generate-Output $count "Client(s) not assigned to WSUS." "Clients_not_assigned") -split ', '
        }
        "UpdatesNeededByComputersNotApproved" {
            $updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
            $updateScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::NotApproved
            $count = $wsus.GetUpdateStatus($updateScope, $False).UpdatesNeededByComputersCount
            $tempReturnCode, $output, $perfdata = (Generate-Output $count "Updates needed but not approved." "Unapproved_needed_updates") -split ', '
        }
        default {
            $output = "Invalid option selected: $Option. Please choose a valid option."
            $tempReturnCode = 3
            $perfdata = ""
        }
    }
    if ([int]$tempReturnCode -gt $returnCode) {
        $returnCode = [int]$tempReturnCode
    }

    Write-Output $output
    if ($perfdata -ne "") {
        Write-Output $perfdata
    }
}

exit $returnCode