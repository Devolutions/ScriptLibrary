#requires -Version 7.0
#requires -Modules @{ ModuleName='Microsoft.Graph.Authentication'; ModuleVersion='2.19.0' }
#requires -Modules @{ ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.19.0' }
#requires -Modules @{ ModuleName='Microsoft.Graph.Identity.SignIns'; ModuleVersion='2.19.0' }
#requires -Modules @{ ModuleName='Microsoft.Graph.Applications'; ModuleVersion='2.19.0' }

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$UserId
)

$ErrorActionPreference = 'Stop'

#region Functions
function Clear-MgUserAuthenticationMethods {
    [CmdletBinding()]
    param ()

    $authMethods = Get-MgUserAuthenticationMethod -UserId $UserId
    $authMethodParams = @{
        UserId = $UserId
    }
    foreach ($authMethod in $authMethods) {
        switch ($authMethod.AdditionalProperties."@odata.type") {
            "#microsoft.graph.emailAuthenticationMethod" {
                Remove-MgUserAuthenticationEmailMethod @authMethodParams -EmailAuthenticationMethodId $authMethod.Id
            }
            "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                Remove-MgUserAuthenticationMicrosoftAuthenticatorMethod @authMethodParams -MicrosoftAuthenticatorAuthenticationMethodId $authMethod.Id
            }
            "#microsoft.graph.fido2AuthenticationMethod" {
                Remove-MgUserAuthenticationFido2Method @authMethodParams -Fido2AuthenticationMethodId $authMethod.Id
            }
            "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                Remove-MgUserAuthenticationWindowsHelloForBusinessMethod @authMethodParams -WindowsHelloForBusinessAuthenticationMethodId $authMethod.Id
            }
            "#microsoft.graph.phoneAuthenticationMethod" {
                Remove-MgUserAuthenticationPhoneMethod @authMethodParams -PhoneAuthenticationMethodId $authMethod.Id
            }
            "#microsoft.graph.softwareOathAuthenticationMethod" {
                Remove-MgUserAuthenticationSoftwareOathMethod @authMethodParams -SoftwareOathAuthenticationMethodId $authMethod.Id
            }
        }
    }
}
#endregion

#region Prereq checks

$requiredScopes = @(
    'UserAuthenticationMethod.ReadWrite.All',
    'User.Read.All'
    'Organization.Read.All'
    'AppRoleAssignment.ReadWrite.All'
)

if (-not ($userContext = Get-MgContext)) {
    throw "You are not authenticated to Microsoft Graph. Please run 'Connect-MgGraph -Scopes $($requiredScopes -join ', ')' to connect with all required scopes."
}

## Ensure the logged-in user has the necessary scopes
if (-not ((Compare-Object $requiredScopes $userContext.Scopes -ExcludeDifferent).Count -eq $requiredScopes.Count)) {
    throw "The logged-in user does not have the necessary scopes to run this script. Ensure the user is authenticated with the following scopes: $($requiredScopes -join ', ')"
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

try {
    Clear-MgUserAuthenticationMethods
} catch {
    throw "Failed to remove authentication methods for user $UserId : $($_.exception.message)"
}