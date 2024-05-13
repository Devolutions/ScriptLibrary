#requires -Version 7.0
#requires -Modules @{ ModuleName='Microsoft.Graph.Authentication'; ModuleVersion='2.19.0' },@{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.19.0' }

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