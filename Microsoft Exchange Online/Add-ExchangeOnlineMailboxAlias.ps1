#requires -Modules @{ModuleName="ExchangeOnlineManagement";ModuleVersion="3.5.0"}

<#
.SYNOPSIS
    Adds a new alias to an existing mailbox in Exchange Online.

.DESCRIPTION
    This script retrieves the specified mailbox using the provided identity and adds a new alias email address.
    The new alias is constructed using the provided alias and the domain from the mailbox's primary SMTP address.
    If the mailbox cannot be found, an appropriate error message is displayed.

.PARAMETER Identity
    The identity of the mailbox (e.g., email address, user principal name, or alias) to which the new alias will be added. 
    This parameter is mandatory.

.PARAMETER Alias
    The alias to be added to the mailbox. This parameter is mandatory.

.NOTES
    This script requires the ExchangeOnlineManagement module version 3.5.0 or higher.
    For more information on managing Exchange Online mailboxes, visit:
    https://docs.microsoft.com/en-us/powershell/exchange/exchange-online/exchange-online-powershell

.EXAMPLE
    PS> .\Add-MailboxAlias.ps1 -Identity "user@example.com" -Alias "newalias"

    This example adds the alias "newalias@example.com" to the mailbox identified by "user@example.com".
#>


[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Identity,

    [Parameter(Mandatory)]
    [string]$Alias
)

$errorActionPreference = "Stop"

try {
    $mbox = Get-Mailbox -Identity $Identity
} catch {
    if ($_.Exception.Message -like "*because object '*' couldn't be found*") {
        throw "Mailbox not found for user: $Identity"
    } else {
        throw $_
    }
}

$newEmail = "$Alias@$(([mailaddress]$mbox.PrimarySmtpAddress).Host)"
Set-Mailbox -Identity $Identity -EmailAddresses @{Add = $newEmail }