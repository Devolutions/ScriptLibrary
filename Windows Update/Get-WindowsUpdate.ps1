#requires -modules @{ModuleName='PSWindowsUpdate'; ModuleVersion='2.2.1.4'}

<#
.SYNOPSIS
    This script retrieves Windows updates on a local computer using various parameters to control the update process.

.DESCRIPTION
    The script utilizes the PSWindowsUpdate module to get Windows updates. It provides options to send reports, schedule updates,
    accept all updates, hide updates, and specify various criteria for update selection. The script supports Windows Update and 
    Microsoft Update services.

.PARAMETER SendReport
    Sends a report of the update status.

.PARAMETER PSWUSettings
    A hashtable of settings for the PSWindowsUpdate module.

.PARAMETER SendHistory
    Sends the update history report.

.PARAMETER ScheduleJob
    Schedules the update job to run at a specified date and time.

.PARAMETER AcceptAll
    Automatically accepts all updates.

.PARAMETER RecurseCycle
    Specifies the number of recursive cycles for checking updates.

.PARAMETER Hide
    Hides the specified updates.

.PARAMETER ServiceID
    Specifies the service ID for the updates (parameter set: 'ServiceID').

.PARAMETER WindowsUpdate
    Specifies to use Windows Update (parameter set: 'WindowsUpdate').

.PARAMETER MicrosoftUpdate
    Specifies to use Microsoft Update (parameter set: 'MicrosoftUpdate').

.PARAMETER Criteria
    Specifies criteria for selecting updates.

.PARAMETER UpdateType
    Specifies the type of updates to manage (Driver or Software).

.PARAMETER DeploymentAction
    Specifies the deployment action (Installation or Uninstallation).

.PARAMETER IsAssigned
    Filters updates that are assigned.

.PARAMETER IsPresent
    Filters updates that are present.

.PARAMETER BrowseOnly
    Browses for updates without installing them.

.PARAMETER AutoSelectOnWebSites
    Automatically selects updates on websites.

.PARAMETER UpdateID
    Specifies the IDs of updates to include.

.PARAMETER NotUpdateID
    Specifies the IDs of updates to exclude.

.PARAMETER RevisionNumber
    Specifies the revision number of updates.

.PARAMETER CategoryIDs
    Specifies the category IDs of updates.

.PARAMETER IsInstalled
    Filters updates that are installed.

.PARAMETER IsHidden
    Filters updates that are hidden.

.PARAMETER WithHidden
    Includes hidden updates.

.PARAMETER ShowPreSearchCriteria
    Shows the pre-search criteria.

.PARAMETER RootCategories
    Specifies the root categories of updates (e.g., Critical Updates, Security Updates, etc.).

.PARAMETER Category
    Specifies categories of updates to include.

.PARAMETER KBArticleID
    Specifies the KB article IDs of updates.

.PARAMETER Title
    Specifies the title of updates.

.PARAMETER Severity
    Specifies the severity of updates (e.g., Critical, Important, etc.).

.PARAMETER NotCategory
    Specifies categories of updates to exclude.

.PARAMETER NotKBArticleID
    Specifies the KB article IDs of updates to exclude.

.PARAMETER NotTitle
    Specifies the title of updates to exclude.

.PARAMETER NotSeverity
    Specifies the severity of updates to exclude.

.PARAMETER IgnoreUserInput
    Aliased as 'Silent', ignores user input during the update process.

.PARAMETER IgnoreRebootRequired
    Ignores reboot requirements after updates are installed.

.PARAMETER AutoSelectOnly
    Automatically selects updates to be installed.

.PARAMETER MaxSize
    Specifies the maximum size of updates to include.

.PARAMETER MinSize
    Specifies the minimum size of updates to include.

.PARAMETER Debuger
    Enables debugging for the update process.

.NOTES
    Requires the 'PSWindowsUpdate' module version 2.2.1.4 or higher.
    For more information on PSWindowsUpdate, visit: https://github.com/PSWindowsUpdate/PSWindowsUpdate

.EXAMPLE
    PS> .\Manage-WindowsUpdate.ps1 -Install -AutoReboot
    
    This example installs all available updates and automatically reboots the computer after installation.

.EXAMPLE
    PS> .\Manage-WindowsUpdate.ps1 -Download -SendReport
    
    This example downloads all available updates and sends a report of the update status.
#>

[CmdletBinding(DefaultParameterSetName = 'Default', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [switch]
    ${SendReport},

    [hashtable]
    ${PSWUSettings},

    [switch]
    ${SendHistory},

    [datetime]
    ${ScheduleJob},

    [switch]
    ${AcceptAll},

    [int]
    ${RecurseCycle},

    [switch]
    ${Hide},

    [Parameter(ParameterSetName = 'ServiceID')]
    [string]
    ${ServiceID},

    [Parameter(ParameterSetName = 'WindowsUpdate')]
    [switch]
    ${WindowsUpdate},

    [Parameter(ParameterSetName = 'MicrosoftUpdate')]
    [switch]
    ${MicrosoftUpdate},

    [string]
    ${Criteria},

    [ValidateSet('Driver', 'Software')]
    [string]
    ${UpdateType},

    [ValidateSet('Installation', 'Uninstallation')]
    [string]
    ${DeploymentAction},

    [switch]
    ${IsAssigned},

    [switch]
    ${IsPresent},

    [switch]
    ${BrowseOnly},

    [switch]
    ${AutoSelectOnWebSites},

    [string[]]
    ${UpdateID},

    [string[]]
    ${NotUpdateID},

    [int]
    ${RevisionNumber},

    [string[]]
    ${CategoryIDs},

    [switch]
    ${IsInstalled},

    [switch]
    ${IsHidden},

    [switch]
    ${WithHidden},

    [switch]
    ${ShowPreSearchCriteria},

    [ValidateSet('Critical Updates', 'Definition Updates', 'Drivers', 'Feature Packs', 'Security Updates', 'Service Packs', 'Tools', 'Update Rollups', 'Updates', 'Upgrades', 'Microsoft')]
    [string[]]
    ${RootCategories},

    [string[]]
    ${Category},

    [string[]]
    ${KBArticleID},

    [string]
    ${Title},

    [ValidateSet('Critical', 'Important', 'Moderate', 'Low', 'Unspecified')]
    [string[]]
    ${Severity},

    [string[]]
    ${NotCategory},

    [string[]]
    ${NotKBArticleID},

    [string]
    ${NotTitle},

    [ValidateSet('Critical', 'Important', 'Moderate', 'Low', 'Unspecified')]
    [string[]]
    ${NotSeverity},

    [Alias('Silent')]
    [switch]
    ${IgnoreUserInput},

    [switch]
    ${AutoSelectOnly},

    [long]
    ${MaxSize},

    [long]
    ${MinSize},

    [switch]
    ${Debuger})

begin {
    try {
        $outBuffer = $null
        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer)) {
            $PSBoundParameters['OutBuffer'] = 1
        }

        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('PSWindowsUpdate\Get-WindowsUpdate', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = { & $wrappedCmd @PSBoundParameters }

        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)
    } catch {
        throw
    }
}

process {
    try {
        $steppablePipeline.Process($_)
    } catch {
        throw
    }
}

end {
    try {
        $steppablePipeline.End()
    } catch {
        throw
    }
}

clean {
    if ($null -ne $steppablePipeline) {
        $steppablePipeline.Clean()
    }
}
<#

.ForwardHelpTargetName PSWindowsUpdate\Get-WindowsUpdate
.ForwardHelpCategory Cmdlet

#>
