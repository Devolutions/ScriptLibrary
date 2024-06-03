#requires -Modules @{ModuleName="pnp.powershell";ModuleVersion="2.4.0"}

<#
.SYNOPSIS
    Connects to a SharePoint tenant and retrieves a list of site collections with their URLs and storage usage.

.DESCRIPTION
    This script connects to a SharePoint tenant using either certificate-based or client secret-based authentication. 
    It retrieves and lists all site collections within the SharePoint tenant, displaying each site's URL and current storage usage in megabytes.

.PARAMETER EntraIdTenantId
    The GUID representing the Entra ID (Azure Active Directory) Tenant ID.

.PARAMETER SharePointTenant
    The name of the SharePoint tenant.

.PARAMETER PrivateKeyFilePath
    The file path to the private key used for certificate-based authentication.

.PARAMETER PrivateKeyPassword
    The password for the private key used in certificate-based authentication.

.PARAMETER ClientId
    The client ID for the Azure AD application.

.PARAMETER ClientSecret
    The client secret for client secret-based authentication.

.PARAMETER SiteUrl
    The URL of a specific SharePoint site. This parameter is optional and, if provided, the script will retrieve information for this site only.

.NOTES
    To run this script, you need the PnP PowerShell module installed with version 2.4.0 or higher.
    For more information on PnP PowerShell, visit: https://pnp.github.io/powershell/

.EXAMPLE
    PS> .\Get-SharePointOnlineSiteStorageSize -EntraIdTenantId "00000000-0000-0000-0000-000000000000" -SharePointTenant "yourtenant" `
                                  -PrivateKeyFilePath "C:\keys\privatekey.pfx" -PrivateKeyPassword (ConvertTo-SecureString "password" -AsPlainText -Force) `
                                  -ClientId "00000000-0000-0000-0000-000000000000"
    Connects to the specified SharePoint tenant using certificate-based authentication and retrieves all site collections with their URLs and storage usage.

.EXAMPLE
    PS> .\Get-SharePointOnlineSiteStorageSize -EntraIdTenantId "00000000-0000-0000-0000-000000000000" -SharePointTenant "yourtenant" `
                                  -ClientId "00000000-0000-0000-0000-000000000000" -ClientSecret (ConvertTo-SecureString "secret" -AsPlainText -Force)
    Connects to the specified SharePoint tenant using client secret-based authentication and retrieves all site collections with their URLs and storage usage.

.EXAMPLE
    PS> .\Get-SharePointOnlineSiteStorageSize -EntraIdTenantId "00000000-0000-0000-0000-000000000000" -SharePointTenant "yourtenant" `
                                  -ClientId "00000000-0000-0000-0000-000000000000" -ClientSecret (ConvertTo-SecureString "secret" -AsPlainText -Force) `
                                  -SiteUrl "https://yourtenant.sharepoint.com/sites/specificsite"
    Connects to the specified SharePoint tenant using client secret-based authentication and retrieves information for the specified site only.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [guid]$EntraIdTenantId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SharePointTenant,

    [Parameter(Mandatory, ParameterSetName = 'CertificateAuth')]
    [ValidateNotNullOrEmpty()]
    [string]$PrivateKeyFilePath,

    [Parameter(Mandatory, ParameterSetName = 'CertificateAuth')]
    [ValidateNotNullOrEmpty()]
    [securestring]$PrivateKeyPassword,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,

    [Parameter(Mandatory, ParameterSetName = 'ClientSecretAuth')]
    [ValidateNotNullOrEmpty()]
    [securestring]$ClientSecret,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [uri]$SiteUrl
)

$ErrorActionPreference = 'Stop'

$connectParams = @{
    ClientId = $ClientId
    Tenant   = $EntraIdTenantId
    Url      = "https://$SharePointTenant.sharepoint.com"
}

if ($PSCmdlet.ParameterSetName -eq 'CertificateAuth') {
    $connectParams.CertificatePath = $PrivateKeyFilePath
    $connectParams.CertificatePassword = $PrivateKeyPassword
} else {
    $connectParams.ClientSecret = $ClientSecret
}

Connect-PnPOnline @connectParams

$getPnPSiteParams = @{}
if ($PSBoundParameters.ContainsKey('SiteUrl')) {
    $getPnPSiteParams.Identity = $SiteUrl.ToString()
}

Get-PnPTenantSite @getPnPSiteParams | ForEach-Object {
    [pscustomobject]@{
        SiteUrl = $_.Url
        SizeMB  = $_.StorageUsageCurrent
    }
}