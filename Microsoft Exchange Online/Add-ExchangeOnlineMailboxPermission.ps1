#requires -Modules @{ModuleName="ExchangeOnlineManagement";ModuleVersion="3.5.0"}

<#
.SYNOPSIS
    Adds permissions to a mailbox in an Exchange environment.

.DESCRIPTION
    This script is a wrapper around the `Add-MailboxPermission` cmdlet, providing a variety of parameter sets to handle different scenarios.
    It supports adding access rights, setting mailbox owner, and handling inheritance types for mailbox permissions.

.PARAMETER AccessRights
    Specifies the access rights to assign to the user on the mailbox. This parameter is mandatory for the AccessRights parameter set.

.PARAMETER AutoMapping
    Specifies whether automapping is enabled. Used in conjunction with the AccessRights and Instance parameter sets.

.PARAMETER Deny
    Specifies whether to deny the specified access rights. Used in conjunction with the AccessRights and Instance parameter sets.

.PARAMETER GroupMailbox
    Specifies whether the mailbox is a group mailbox. Used in conjunction with the Owner, Instance, and AccessRights parameter sets.

.PARAMETER Identity
    Specifies the mailbox to which permissions are being added. This parameter is mandatory for multiple parameter sets.

.PARAMETER IgnoreDefaultScope
    Specifies whether to ignore the default scope and search in the entire forest.

.PARAMETER InheritanceType
    Specifies the type of inheritance for the permission. Used in conjunction with the AccessRights and Instance parameter sets.

.PARAMETER Owner
    Specifies the owner of the mailbox. This parameter is mandatory for the Owner parameter set.

.PARAMETER User
    Specifies the user to whom the permissions are being granted. This parameter is mandatory for the AccessRights parameter set.

.NOTES
    For more information on the `Add-MailboxPermission` cmdlet, visit:
    https://learn.microsoft.com/en-us/powershell/module/exchange/add-mailboxpermission

.EXAMPLE
    PS> .\Add-ExchangeOnlineMailboxPermission.ps1 -Identity "UserMailbox" -User "AnotherUser" -AccessRights FullAccess

    This example grants the 'FullAccess' permission to 'AnotherUser' on 'UserMailbox'.

.EXAMPLE
    PS> .\Add-ExchangeOnlineMailboxPermission.ps1 -Identity "UserMailbox" -Owner "NewOwner"

    This example sets 'NewOwner' as the owner of 'UserMailbox'.

.EXAMPLE
    PS> .\Add-ExchangeOnlineMailboxPermission.ps1 -Identity "UserMailbox" -User "AnotherUser" -AccessRights FullAccess -Deny

    This example denies the 'FullAccess' permission to 'AnotherUser' on 'UserMailbox'.

.EXAMPLE
    PS> .\Add-ExchangeOnlineMailboxPermission.ps1 -Identity "UserMailbox" -ClearAutoMapping

    This example clears automapping for 'UserMailbox'.
#>


[CmdletBinding(DefaultParameterSetName='AccessRights', SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    [Parameter(ParameterSetName='AccessRights', Mandatory=$true)]
    [Parameter(ParameterSetName='Instance')]
    [System.Object[]]
    ${AccessRights},

    [Parameter(ParameterSetName='AccessRights')]
    [Parameter(ParameterSetName='Instance')]
    [System.Object]
    ${AutoMapping},

    [Parameter(ParameterSetName='AccessRights')]
    [Parameter(ParameterSetName='Instance')]
    [switch]
    ${Deny},

    [Parameter(ParameterSetName='Owner')]
    [Parameter(ParameterSetName='Instance')]
    [Parameter(ParameterSetName='AccessRights')]
    [switch]
    ${GroupMailbox},

    [Parameter(ParameterSetName='ClearAutoMapping', Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
    [Parameter(ParameterSetName='ResetDefault', Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
    [Parameter(ParameterSetName='Owner', Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
    [Parameter(ParameterSetName='AccessRights', Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
    [Parameter(ParameterSetName='Instance', Position=0)]
    [System.Object]
    ${Identity},

    [switch]
    ${IgnoreDefaultScope},

    [Parameter(ParameterSetName='AccessRights')]
    [Parameter(ParameterSetName='Instance')]
    [System.DirectoryServices.ActiveDirectorySecurityInheritance]
    ${InheritanceType},

    [Parameter(ParameterSetName='Owner', Mandatory=$true)]
    [System.Object]
    ${Owner},

    [Parameter(ParameterSetName='AccessRights', Mandatory=$true)]
    [Parameter(ParameterSetName='Instance')]
    [System.Object]
    ${User})

begin
{
    try {
        $outBuffer = $null
        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
        {
            $PSBoundParameters['OutBuffer'] = 1
        }

        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Add-MailboxPermission', [System.Management.Automation.CommandTypes]::Function)
        $scriptCmd = {& $wrappedCmd @PSBoundParameters }

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

.ForwardHelpTargetName Add-MailboxPermission
.ForwardHelpCategory Function

#>
