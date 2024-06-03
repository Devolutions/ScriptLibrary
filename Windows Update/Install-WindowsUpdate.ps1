#requires -modules @{ModuleName='PSWindowsUpdate'; ModuleVersion='2.2.1.4'}

<#
.SYNOPSIS
    This script facilitates the installation, downloading, and management of Windows updates on one or multiple computers.

.DESCRIPTION
    The script utilizes the PSWindowsUpdate module to manage Windows updates. It supports various parameters for filtering 
    and specifying the updates to be managed, including scheduling options, criteria for selection, and actions to be taken. 
    The script also supports reporting and history features, allowing for detailed control and monitoring of update activities.

.PARAMETER ComputerName
    The name of the computer(s) on which to manage Windows updates.

.PARAMETER SendReport
    Sends a report of the update status.

.PARAMETER PSWUSettings
    A hashtable of settings for PSWindowsUpdate module.

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

.PARAMETER Download
    Downloads the specified updates.

.PARAMETER ForceDownload
    Forces the download of updates, ignoring any preconditions.

.PARAMETER Install
    Installs the specified updates.

.PARAMETER ForceInstall
    Forces the installation of updates, ignoring any preconditions.

.PARAMETER AutoReboot
    Automatically reboots the computer after installing updates.

.PARAMETER IgnoreReboot
    Ignores reboot requests after installing updates.

.PARAMETER ScheduleReboot
    Schedules a reboot at a specified date and time after updates are installed.

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
    PS> .\Install-WindowsUpdate.ps1 -ComputerName 'Server01' -Install -AutoReboot
    
    This example installs updates on 'Server01' and automatically reboots the computer after installation.

.EXAMPLE
    PS> .\Install-WindowsUpdate.ps1 -ComputerName 'Server01','Server02' -Download -SendReport
    
    This example downloads updates on 'Server01' and 'Server02' and sends a report of the update status.
#>


[CmdletBinding(DefaultParameterSetName = 'Default', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string[]]
    ${ComputerName},

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

    [switch]
    ${Download},

    [switch]
    ${ForceDownload},

    [switch]
    ${Install},

    [switch]
    ${ForceInstall},

    [switch]
    ${AutoReboot},

    [switch]
    ${IgnoreReboot},

    [datetime]
    ${ScheduleReboot},

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
    ${IgnoreRebootRequired},

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