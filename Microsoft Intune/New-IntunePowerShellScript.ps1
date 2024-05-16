<#
.SYNOPSIS
    Uploads a PowerShell script to Microsoft Graph API as a platform script.

.DESCRIPTION
    This script uploads a specified PowerShell script to Microsoft Graph API as a platform script, allowing for 
    automated deployment and management. The script supports authentication using client credentials, encoding the script 
    content to base64, and setting various optional parameters.

.PARAMETER ScriptPath
    The path to the PowerShell script file to be uploaded. The file must exist.

.PARAMETER TenantId
    The Tenant ID (GUID) for the Azure AD tenant.

.PARAMETER ClientId
    The Client ID (GUID) for the Azure AD application.

.PARAMETER ClientSecret
    The client secret for the Azure AD application, provided as a secure string.

.PARAMETER DisplayName
    The display name for the device management script in Microsoft Graph API.

.PARAMETER RunAsUser
    Specifies whether the script should run as 'user' or 'system'. Defaults to 'system'.

.PARAMETER RunAs32Bit
    If specified, the script will run in a 32-bit process.

.PARAMETER EnforceSignatureCheck
    If specified, the script will enforce signature checks.

.PARAMETER Description
    An optional description for the device management script.

.EXAMPLE
    PS> $app = Get-AzADApplication -DisplayName DeviceManagementScriptApp
    PS> $secret = New-AzADAppCredential -ObjectId $app.Id
    PS> .\New-IntunePowerShellScript.ps1 -ScriptPath "C:\Scripts\MyScript.ps1" -TenantId (Get-AzContext).tenant.id
    -ClientId $app.AppId -ClientSecret (ConvertTo-SecureString $secret.SecretText -AsPlainText -Force) -DisplayName "My Script" -Description "This is a 
    sample script" -RunAsUser "system" -RunAs32Bit -EnforceSignatureCheck

.NOTES
    For more information on the Microsoft Graph API for device management scripts, visit:
    https://docs.microsoft.com/en-us/graph/api/resources/intune-devices-deviceManagementScript?view=graph-rest-beta

    The application used to authenticate to Azure must have at least DeviceManagementConfiguration.ReadWrite.All API permission
    and with admin consent. You can create a new Azure AD app for this by running the following PowerShell:

    $requiredResourceAccess = @(
        @{
            ResourceAppId = "00000003-0000-0000-c000-000000000000"  # Microsoft Graph API ID
            ResourceAccess = @(
                @{
                    Id = "9241abd9-d0e6-425a-bd4f-47ba86e767a4"     # DeviceManagementConfiguration.ReadWrite.All permission ID
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
    [ValidateScript({
            if (-not (Test-Path $_ -PathType Leaf)) {
                throw "The PowerShell script file '$_' does not exist."
            }
            $true
        })]
    [string]$ScriptPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [guid]$TenantId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [guid]$ClientId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$ClientSecret,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DisplayName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('user', 'system')]
    [string]$RunAsUser = 'system',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [switch]$RunAs32Bit,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [switch]$EnforceSignatureCheck,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Description
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
#endregion

# Get authentication token
$token = getGraphApiToken -tenantId $TenantId -clientId $ClientId -clientSecret $ClientSecret

# Read the script content and encode to base64
$scriptContent = Get-Content -Path $ScriptPath -Raw
$base64ScriptContent = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($scriptContent))

# Prepare the header with the token
$headers = @{
    Authorization  = "Bearer $token"
    'Content-Type' = 'application/json'
}

$body = @{
    "@odata.type"    = "#microsoft.graph.deviceManagementScript"
    "scriptContent"  = $base64ScriptContent
    "scriptLanguage" = "PowerShell"
}

$paramToApiMap = @{
    "DisplayName"           = "displayName"
    "Description"           = "description"
    "RunAsUser"             = "runAsAccount"
    "RunAs32Bit"            = "runAs32Bit"
    "EnforceSignatureCheck" = "enforceSignatureCheck"
}

$paramToApiMap.GetEnumerator() | Where-Object { $PSBoundParameters.ContainsKey($_.Key) } | ForEach-Object {
    $val = $PSBoundParameters[$_.Key]
    if ($_.Key -in @('RunAs32Bit','EnforceSignatureCheck')) {
        $val = [bool]$val
    }
    $body[$_.Value] = $val
}

$irmParams = @{
    Uri                = 'https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts'
    Method             = 'POST'
    Headers            = $headers
    StatusCodeVariable = 'respStatus' # Capture the status code of the API response
    SkipHttpErrorCheck = $true
    Body               = ($body | ConvertTo-Json)
}

# Make the API call
$response = Invoke-RestMethod @irmParams

if ($respStatus -ne 201) {
    throw $response.error.message
}