<#
.SYNOPSIS
This script retrieves the primary user of a managed device by querying the Microsoft Graph API.

.DESCRIPTION
This script authenticates to the Microsoft Graph API using client credentials, retrieves a token, and uses it to query for a managed device
by its name. It returns the user principal name of the primary user associated with the device.

.PARAMETER DeviceName
Specifies the name of the device to query.

.PARAMETER TenantId
Specifies the tenant ID for the Azure Active Directory.

.PARAMETER ClientId
Specifies the client ID for the Azure application used for authentication.

.PARAMETER ClientSecret
Specifies the client secret for the Azure application used for authentication.

.EXAMPLE
    PS> $app = Get-AzADApplication -DisplayName DeviceManagementScriptApp
    PS> $secret = New-AzADAppCredential -ObjectId $app.Id
    PS> .\Get-IntuneDevicePrimaryUser.ps1 -DeviceId "1234567890" -TenantId (Get-AzContext).tenant.id
    -ClientId $app.AppId -ClientSecret (ConvertTo-SecureString $secret.SecretText -AsPlainText -Force)

.NOTES
    For more information on the Microsoft Graph API, visit: https://docs.microsoft.com/en-us/graph/overview

    The application used to authenticate to Azure must have at least DeviceManagementConfiguration.ReadWrite.All 
    API permission and Device.Read.All with admin consent. You can create a new Azure AD app for this by running the following PowerShell:

    $requiredResourceAccess = @(
        @{
            ResourceAppId = "00000003-0000-0000-c000-000000000000"  # Microsoft Graph API ID
            ResourceAccess = @(
                @{
                    Id = "2f51be20-0bb4-4fed-bf7b-db946066c75e"     # DeviceManagementManagedDevices.Read.All permission ID
                    Type = "Role"
                },
                @{
                    Id = "7438b122-aefc-4978-80ed-43db9fcc7715"     # Device.Read.All permission ID
                    Type = "Role"
                }
            )
        }
    )
    $app = New-AzADApplication -DisplayName DeviceManagementScriptApp -RequiredResourceAccess $requiredResourceAccess
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DeviceName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [guid]$TenantId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [guid]$ClientId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$ClientSecret
)

#region Functions
function decryptSecureString {
    param(
        [securestring]$SecureString
    )
    try {
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        ## Clear the decrypted password from memory
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function getGraphApiToken {
    param ()
    $body = @{
        grant_type    = "client_credentials"
        scope         = "https://graph.microsoft.com/.default"
        client_id     = $ClientId
        client_secret = (decryptSecureString $ClientSecret)
    }
    $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
    $tokenResponse.access_token
}

function invokeGraphApiCall {
    param (
        [string]$uri,
        [string]$method,
        [hashtable]$headers,
        [hashtable]$body
    )

    # Prepare parameters for the Invoke-RestMethod call
    $irmParams = @{
        Uri                = $uri
        Method             = $method
        Headers            = $headers
        StatusCodeVariable = 'respStatus' # Capture the status code of the API response
        SkipHttpErrorCheck = $true
    }

    # Make the API call to get the primary user
    $response = Invoke-RestMethod @irmParams

    # Check the response status code
    if ($respStatus -ne 200) {
        throw $response.error.message
    }

    $response.value

}

function getManagedDevice {
    param($headers)

    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$DeviceName'"
    invokeGraphApiCall -uri $uri -method 'GET' -headers $headers
}
#endregion

# Get authentication token
$token = getGraphApiToken -tenantId $TenantId -clientId $ClientId -clientSecret $ClientSecret

# Prepare the header with the token
$headers = @{
    Authorization  = "Bearer $token"
    'Content-Type' = 'application/json'
}

## Find the device
$device = getManagedDevice -headers $headers
$device.userPrincipalName