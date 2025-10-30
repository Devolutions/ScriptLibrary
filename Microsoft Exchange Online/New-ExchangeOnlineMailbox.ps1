#requires -Modules @{ModuleName="ExchangeOnlineManagement";ModuleVersion="3.5.0"}

<#
.SYNOPSIS
    Creates a new mailbox in an Exchange environment with various options for user, room, shared, and more.

.DESCRIPTION
    The script wraps around the New-Mailbox cmdlet, providing a rich set of parameters to create different types of mailboxes.
    It supports various parameter sets to handle specific scenarios such as creating room mailboxes, shared mailboxes, equipment mailboxes,
    and more. The cmdlet also integrates with Microsoft Online Services for federated users and supports remote and inactive mailboxes.

.PARAMETER ActiveSyncMailboxPolicy
    Specifies the ActiveSync mailbox policy to apply to the new mailbox.

.PARAMETER Alias
    Specifies the alias for the new mailbox. This parameter is required.

.PARAMETER Archive
    Specifies whether to create an archive mailbox for the user.

.PARAMETER Discovery
    Specifies that the mailbox is a discovery mailbox. This parameter is mandatory for the Discovery parameter set.

.PARAMETER DisplayName
    Specifies the display name for the new mailbox.

.PARAMETER EnableRoomMailboxAccount
    Specifies whether to enable the account for a room mailbox. This parameter is mandatory for the EnableRoomMailboxAccount parameter set.

.PARAMETER Equipment
    Specifies that the mailbox is an equipment mailbox. This parameter is mandatory for the Equipment parameter set.

.PARAMETER FederatedIdentity
    Specifies the federated identity for a federated user. This parameter is mandatory for the MicrosoftOnlineServicesFederatedUser and FederatedUser parameter sets.

.PARAMETER FirstName
    Specifies the first name of the user for the new mailbox.

.PARAMETER Force
    Forces the command to execute without asking for user confirmation.

.PARAMETER HoldForMigration
    Specifies that the mailbox is being held for migration. This parameter is used with the PublicFolder parameter set.

.PARAMETER ImmutableId
    Specifies the immutable ID for the mailbox.

.PARAMETER InactiveMailbox
    Specifies the inactive mailbox object. Used in various parameter sets that involve inactive or removed mailboxes.

.PARAMETER Initials
    Specifies the initials of the user.

.PARAMETER IsExcludedFromServingHierarchy
    Specifies whether the public folder mailbox is excluded from serving the hierarchy.

.PARAMETER LastName
    Specifies the last name of the user for the new mailbox.

.PARAMETER MailboxPlan
    Specifies the mailbox plan to apply to the new mailbox. Used in various parameter sets.

.PARAMETER MailboxRegion
    Specifies the region for the new mailbox.

.PARAMETER MicrosoftOnlineServicesID
    Specifies the Microsoft Online Services ID for the user. This parameter is mandatory in certain parameter sets.

.PARAMETER Migration
    Specifies that the mailbox is created for migration purposes. This parameter is mandatory for the Migration parameter set.

.PARAMETER ModeratedBy
    Specifies the users who moderate the mailbox. Used in various parameter sets.

.PARAMETER ModerationEnabled
    Specifies whether moderation is enabled for the mailbox. Used in various parameter sets.

.PARAMETER Name
    Specifies the name of the new mailbox. This parameter is mandatory and positional.

.PARAMETER Office
    Specifies the office location of the new mailbox. Used in room and linked room mailboxes.

.PARAMETER OrganizationalUnit
    Specifies the organizational unit (OU) for the new mailbox.

.PARAMETER Password
    Specifies the password for the new mailbox. This parameter is mandatory in certain parameter sets.

.PARAMETER Phone
    Specifies the phone number for the new mailbox. Used in room and linked room mailboxes.

.PARAMETER PrimarySmtpAddress
    Specifies the primary SMTP address for the new mailbox.

.PARAMETER PublicFolder
    Specifies that the mailbox is a public folder mailbox. This parameter is mandatory for the PublicFolder parameter set.

.PARAMETER RemotePowerShellEnabled
    Specifies whether remote PowerShell is enabled for the new mailbox.

.PARAMETER RemovedMailbox
    Specifies the removed mailbox object. Used in various parameter sets involving removed or inactive mailboxes.

.PARAMETER ResetPasswordOnNextLogon
    Specifies whether the user must reset the password on next logon.

.PARAMETER ResourceCapacity
    Specifies the resource capacity for the new mailbox. Used in room and linked room mailboxes.

.PARAMETER RoleAssignmentPolicy
    Specifies the role assignment policy for the new mailbox.

.PARAMETER Room
    Specifies that the mailbox is a room mailbox. This parameter is mandatory for the Room parameter set.

.PARAMETER RoomMailboxPassword
    Specifies the password for the room mailbox account. This parameter is mandatory for the EnableRoomMailboxAccount parameter set.

.PARAMETER SendModerationNotifications
    Specifies how moderation notifications are sent. Used in various parameter sets.

.PARAMETER Shared
    Specifies that the mailbox is a shared mailbox. This parameter is mandatory for the Shared parameter set.

.PARAMETER TargetAllMDBs
    Specifies whether to target all mailbox databases.

.EXAMPLE
    PS> .\New-Mailbox.ps1 -Name "John Doe" -Alias "jdoe" -Password (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) -DisplayName "John Doe" -FirstName "John" -LastName "Doe" -User

    This example creates a new user mailbox for John Doe with the specified parameters.

.EXAMPLE
    PS> .\New-Mailbox.ps1 -Name "ConferenceRoom1" -Alias "confroom1" -Room -RoomMailboxPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) -Office "Head Office"

    This example creates a new room mailbox for a conference room at the Head Office location.

.EXAMPLE
    PS> .\New-Mailbox.ps1 -Name "Shared Mailbox" -Alias "sharedmail" -Shared

    This example creates a new shared mailbox with the specified parameters.
#>

[CmdletBinding(DefaultParameterSetName = 'User', SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [System.Object]
    ${ActiveSyncMailboxPolicy},

    [ValidateNotNullOrEmpty()]
    [string]
    ${Alias},

    [switch]
    ${Archive},

    [Parameter(ParameterSetName = 'Discovery', Mandatory = $true)]
    [switch]
    ${Discovery},

    [string]
    ${DisplayName},

    [Parameter(ParameterSetName = 'EnableRoomMailboxAccount', Mandatory = $true)]
    [bool]
    ${EnableRoomMailboxAccount},

    [Parameter(ParameterSetName = 'Equipment', Mandatory = $true)]
    [switch]
    ${Equipment},

    [Parameter(ParameterSetName = 'MicrosoftOnlineServicesFederatedUser', Mandatory = $true)]
    [Parameter(ParameterSetName = 'FederatedUser', Mandatory = $true)]
    [string]
    ${FederatedIdentity},

    [string]
    ${FirstName},

    [switch]
    ${Force},

    [Parameter(ParameterSetName = 'PublicFolder')]
    [switch]
    ${HoldForMigration},

    [string]
    ${ImmutableId},

    [Parameter(ParameterSetName = 'User', ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'InactiveMailbox', Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'WindowsLiveCustomDomains', ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'MicrosoftOnlineServicesID', ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'WindowsLiveID', ValueFromPipeline = $true)]
    [System.Object]
    ${InactiveMailbox},

    [string]
    ${Initials},

    [Parameter(ParameterSetName = 'PublicFolder')]
    [bool]
    ${IsExcludedFromServingHierarchy},

    [string]
    ${LastName},

    [Parameter(ParameterSetName = 'MicrosoftOnlineServicesID')]
    [Parameter(ParameterSetName = 'RemoteArchive')]
    [Parameter(ParameterSetName = 'MicrosoftOnlineServicesFederatedUser')]
    [Parameter(ParameterSetName = 'FederatedUser')]
    [Parameter(ParameterSetName = 'InactiveMailbox')]
    [Parameter(ParameterSetName = 'RemovedMailbox')]
    [Parameter(ParameterSetName = 'ImportLiveId')]
    [Parameter(ParameterSetName = 'DisabledUser')]
    [Parameter(ParameterSetName = 'MailboxPlan')]
    [Parameter(ParameterSetName = 'WindowsLiveCustomDomains')]
    [Parameter(ParameterSetName = 'WindowsLiveID')]
    [Parameter(ParameterSetName = 'User')]
    [System.Object]
    ${MailboxPlan},

    [ValidateNotNullOrEmpty()]
    [string]
    ${MailboxRegion},

    [Parameter(ParameterSetName = 'EnableRoomMailboxAccount')]
    [Parameter(ParameterSetName = 'MicrosoftOnlineServicesFederatedUser', Mandatory = $true)]
    [Parameter(ParameterSetName = 'MicrosoftOnlineServicesID', Mandatory = $true)]
    [System.Object]
    ${MicrosoftOnlineServicesID},

    [Parameter(ParameterSetName = 'Migration', Mandatory = $true)]
    [switch]
    ${Migration},

    [Parameter(ParameterSetName = 'GroupMailbox')]
    [Parameter(ParameterSetName = 'RemoteArchive')]
    [Parameter(ParameterSetName = 'InactiveMailbox')]
    [Parameter(ParameterSetName = 'RemovedMailbox')]
    [Parameter(ParameterSetName = 'DisabledUser')]
    [Parameter(ParameterSetName = 'ImportLiveId')]
    [Parameter(ParameterSetName = 'WindowsLiveCustomDomains')]
    [Parameter(ParameterSetName = 'MailboxPlan')]
    [Parameter(ParameterSetName = 'MicrosoftOnlineServicesID')]
    [Parameter(ParameterSetName = 'WindowsLiveID')]
    [Parameter(ParameterSetName = 'Equipment')]
    [Parameter(ParameterSetName = 'Room')]
    [Parameter(ParameterSetName = 'LinkedRoomMailbox')]
    [Parameter(ParameterSetName = 'LinkedWithSyncMailbox')]
    [Parameter(ParameterSetName = 'Linked')]
    [Parameter(ParameterSetName = 'TeamMailboxITPro')]
    [Parameter(ParameterSetName = 'TeamMailboxIW')]
    [Parameter(ParameterSetName = 'Shared')]
    [Parameter(ParameterSetName = 'User')]
    [System.Object]
    ${ModeratedBy},

    [Parameter(ParameterSetName = 'RemoteArchive')]
    [Parameter(ParameterSetName = 'InactiveMailbox')]
    [Parameter(ParameterSetName = 'RemovedMailbox')]
    [Parameter(ParameterSetName = 'DisabledUser')]
    [Parameter(ParameterSetName = 'ImportLiveId')]
    [Parameter(ParameterSetName = 'WindowsLiveCustomDomains')]
    [Parameter(ParameterSetName = 'MailboxPlan')]
    [Parameter(ParameterSetName = 'MicrosoftOnlineServicesID')]
    [Parameter(ParameterSetName = 'WindowsLiveID')]
    [Parameter(ParameterSetName = 'Equipment')]
    [Parameter(ParameterSetName = 'Room')]
    [Parameter(ParameterSetName = 'LinkedRoomMailbox')]
    [Parameter(ParameterSetName = 'LinkedWithSyncMailbox')]
    [Parameter(ParameterSetName = 'Linked')]
    [Parameter(ParameterSetName = 'TeamMailboxITPro')]
    [Parameter(ParameterSetName = 'TeamMailboxIW')]
    [Parameter(ParameterSetName = 'Shared')]
    [Parameter(ParameterSetName = 'User')]
    [bool]
    ${ModerationEnabled},

    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [string]
    ${Name},

    [Parameter(ParameterSetName = 'LinkedRoomMailbox')]
    [Parameter(ParameterSetName = 'Room')]
    [string]
    ${Office},

    [System.Object]
    ${OrganizationalUnit},

    [Parameter(ParameterSetName = 'MicrosoftOnlineServicesID')]
    [Parameter(ParameterSetName = 'RemoteArchive', Mandatory = $true)]
    [Parameter(ParameterSetName = 'InactiveMailbox')]
    [Parameter(ParameterSetName = 'RemovedMailbox')]
    [Parameter(ParameterSetName = 'DisabledUser')]
    [Parameter(ParameterSetName = 'Discovery')]
    [Parameter(ParameterSetName = 'Migration')]
    [Parameter(ParameterSetName = 'Arbitration')]
    [Parameter(ParameterSetName = 'WindowsLiveID', Mandatory = $true)]
    [Parameter(ParameterSetName = 'TeamMailboxITPro')]
    [Parameter(ParameterSetName = 'TeamMailboxIW')]
    [Parameter(ParameterSetName = 'Shared')]
    [Parameter(ParameterSetName = 'Scheduling')]
    [Parameter(ParameterSetName = 'Equipment')]
    [Parameter(ParameterSetName = 'Room')]
    [Parameter(ParameterSetName = 'LinkedRoomMailbox')]
    [Parameter(ParameterSetName = 'LinkedWithSyncMailbox')]
    [Parameter(ParameterSetName = 'Linked')]
    [Parameter(ParameterSetName = 'User', Mandatory = $true)]
    [securestring]
    ${Password},

    [Parameter(ParameterSetName = 'LinkedRoomMailbox')]
    [Parameter(ParameterSetName = 'Room')]
    [string]
    ${Phone},

    [System.Object]
    ${PrimarySmtpAddress},

    [Parameter(ParameterSetName = 'PublicFolder', Mandatory = $true)]
    [switch]
    ${PublicFolder},

    [bool]
    ${RemotePowerShellEnabled},

    [Parameter(ParameterSetName = 'User', ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'ImportLiveId', ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'RemoteArchive', ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'RemovedMailbox', Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'WindowsLiveCustomDomains', ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'MicrosoftOnlineServicesFederatedUser', ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'FederatedUser', ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'MicrosoftOnlineServicesID', ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'WindowsLiveID', ValueFromPipeline = $true)]
    [System.Object]
    ${RemovedMailbox},

    [bool]
    ${ResetPasswordOnNextLogon},

    [Parameter(ParameterSetName = 'LinkedRoomMailbox')]
    [Parameter(ParameterSetName = 'Room')]
    [System.Object]
    ${ResourceCapacity},

    [System.Object]
    ${RoleAssignmentPolicy},

    [Parameter(ParameterSetName = 'EnableRoomMailboxAccount', Mandatory = $true)]
    [Parameter(ParameterSetName = 'Room', Mandatory = $true)]
    [switch]
    ${Room},

    [Parameter(ParameterSetName = 'EnableRoomMailboxAccount')]
    [securestring]
    ${RoomMailboxPassword},

    [Parameter(ParameterSetName = 'GroupMailbox')]
    [Parameter(ParameterSetName = 'RemoteArchive')]
    [Parameter(ParameterSetName = 'InactiveMailbox')]
    [Parameter(ParameterSetName = 'RemovedMailbox')]
    [Parameter(ParameterSetName = 'DisabledUser')]
    [Parameter(ParameterSetName = 'ImportLiveId')]
    [Parameter(ParameterSetName = 'WindowsLiveCustomDomains')]
    [Parameter(ParameterSetName = 'MailboxPlan')]
    [Parameter(ParameterSetName = 'MicrosoftOnlineServicesID')]
    [Parameter(ParameterSetName = 'WindowsLiveID')]
    [Parameter(ParameterSetName = 'Equipment')]
    [Parameter(ParameterSetName = 'Room')]
    [Parameter(ParameterSetName = 'LinkedRoomMailbox')]
    [Parameter(ParameterSetName = 'LinkedWithSyncMailbox')]
    [Parameter(ParameterSetName = 'Linked')]
    [Parameter(ParameterSetName = 'TeamMailboxITPro')]
    [Parameter(ParameterSetName = 'TeamMailboxIW')]
    [Parameter(ParameterSetName = 'Shared')]
    [Parameter(ParameterSetName = 'User')]
    [System.Object]
    ${SendModerationNotifications},

    [Parameter(ParameterSetName = 'Shared', Mandatory = $true)]
    [switch]
    ${Shared},

    [switch]
    ${TargetAllMDBs})

begin
{
    try {
        $outBuffer = $null
        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer)) {
            $PSBoundParameters['OutBuffer'] = 1
        }

        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('New-Mailbox', [System.Management.Automation.CommandTypes]::Function)
        $scriptCmd = { & $wrappedCmd @PSBoundParameters }

        $steppablePipeline = $scriptCmd.GetSteppablePipeline()
        $steppablePipeline.Begin($PSCmdlet)
    } catch {
        throw
    }
}

process
{
    try {
        $steppablePipeline.Process($_)
    } catch {
        throw
    }
}

end
{
    try {
        $steppablePipeline.End()
    } catch {
        throw
    }
}

clean
{
    if ($null -ne $steppablePipeline) {
        $steppablePipeline.Clean()
    }
}
<#

.ForwardHelpTargetName New-Mailbox
.ForwardHelpCategory Function

#>