#requires -Version 7.0
#requires -Modules @{ ModuleName='Microsoft.Graph.Authentication'; ModuleVersion='2.19.0' },@{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.19.0' }
<#
.SYNOPSIS
    Disables a specified user account in Entra ID.

.DESCRIPTION
    This script disables the account of a specified user in Entra ID. It checks for authentication to Entra ID,
    verifies the existence of the user, and then disables the user account. The script requires the user ID of the Entra ID
    account to be provided.

.PARAMETER UserId
    Specifies the user ID of the Entra ID account to be disabled. This must be a valid user identifier.

.EXAMPLE
    PS> .\Disable-EntraIdUserAccount.ps1 -UserId "a1234567-89b0-12d3-a456-426614174000"

    This example disables the account for the user with the specified user ID.

.INPUTS
    None. Parameters must be provided when the script is called.

.OUTPUTS
    None directly from the script. Actions performed are related to Entra ID user management operations.

.NOTES
    The script requires authentication to Entra ID with appropriate permissions. Users should be authenticated with
    permissions to manage user accounts, such as User.ReadWrite.All.

.LINK
    https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.users/update-mguser

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$UserId
)

$ErrorActionPreference = 'Stop'

#region Functions
function Test-MgGraphAuthenticated {
    [CmdletBinding()]
    param ()

    [bool](Get-MgContext)
}
#endregion

#region Prereq checks
if (-not (Test-MgGraphAuthenticated)) {
    throw 'You are not authenticated to Microsoft Graph. Please run "Connect-MgGraph -Scopes User.ReadWrite.All, Organization.Read.All" and provide an account with approppriate rights to add the license requested.'
}

try {
    $null = Get-MgUser -UserId $UserId
} catch {
    if ($_.exception.message -match '^\[Request_ResourceNotFound\]') {
        throw "User $UserId not found. Please check the user ID and try again."
    } else {
        throw "Error occurred while fetching user $UserId : $($_.exception.message)"
    }
}
#endregion

Update-MgUser -UserId $UserId -AccountEnabled:$False