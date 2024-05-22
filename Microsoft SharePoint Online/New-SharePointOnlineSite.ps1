#requires -Modules @{ModuleName="pnp.powershell";ModuleVersion="2.4.0"}
#requires -Modules @{ModuleName="Az.Accounts";ModuleVersion="2.15.1"}

<#
.SYNOPSIS
Creates a new SharePoint site using PnP PowerShell with either certificate or client secret authentication.

.DESCRIPTION
This script connects to a SharePoint Online tenant and creates a new site. The connection can be established using either 
certificate-based or client secret-based authentication, depending on the provided parameters.

.PARAMETER Title
The title of the new SharePoint site.

.PARAMETER Name
The name (URL segment) of the new SharePoint site.

.PARAMETER Type
The type of the SharePoint site. Valid values are 'TeamSite', 'CommunicationSite', and 'TeamSiteWithoutMicrosoft365Group'.

.PARAMETER EntraIdTenantId
The Azure AD tenant ID. If logged into Azure AD, this can be retrieved with (Get-AzContext).Tenant.Id.

.PARAMETER SharePointTenant
The SharePoint tenant name (e.g., "contoso" for "contoso.sharepoint.com").

.PARAMETER Owner
An array of owners for the new SharePoint site.

.PARAMETER PrivateKeyFilePath
The file path to the private key for certificate-based authentication. Required when using the CertificateAuth parameter set.

.PARAMETER PrivateKeyPassword
The password for the private key. Required when using the CertificateAuth parameter set.

.PARAMETER ClientId
The client ID for the Azure AD application.

.PARAMETER ClientSecret
The client secret for client secret-based authentication. Required when using the ClientSecretAuth parameter set.

.NOTES
Requires the PnP PowerShell module (v2.4.0) and Az.Accounts module (v2.15.1).
For more information on PnP PowerShell, visit: https://pnp.github.io/powershell/

.EXAMPLE

    PS> $tenantId = (Get-AzContext).Tenant.Id
    PS> $app = Get-AzADApplication -DisplayName "SharePoint Online"
    PS> .\New-SharePointOnlineSite.ps1 -Title "New Team Site" -Name "newteamsite" -Type "TeamSite" -EntraIdTenantId $tenantId 
    -SharePointTenant "contoso" -Owner "user@contoso.com" -ClientId $app.AppId -ClientSecret (ConvertTo-SecureString "your-client-secret" -AsPlainText -Force)

    Creates a new Team Site using client secret authentication.

.EXAMPLE

    PS> $tenantId = (Get-AzContext).Tenant.Id
    PS> $app = Get-AzADApplication -DisplayName "SharePoint Online"
    PS> .\New-SharePointOnlineSite.ps1 -Title "New Communication Site" -Name "newcommsite" -Type "CommunicationSite" -EntraIdTenantId $tenantId 
    -SharePointTenant "contoso" -Owner "user@contoso.com" -ClientId $app.AppId -PrivateKeyFilePath "path\to\privatekey.pfx" 
    -PrivateKeyPassword (ConvertTo-SecureString "your-password" -AsPlainText -Force)

    Creates a new Communication Site using certificate-based authentication.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Title,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory)]
    [ValidateSet('TeamSite', 'CommunicationSite', 'TeamSiteWithoutMicrosoft365Group')]
    [string]$Type,
    
    [Parameter(Mandatory)]
    [guid]$EntraIdTenantId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SharePointTenant,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Owner,

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
    [securestring]$ClientSecret
)

$ErrorActionPreference = 'Stop'

$connectParams = @{
    ClientId = $ClientId
    Tenant   = $EntraIdTenantId
    Url      = "https://$SharePointTenant.sharepoint.com"
}

if ($PSCmdlet.ParameterSetName -eq 'CertificateAuth') {
    $connectParams.CertificatePath = $PrivateKeyFilePath
    $connectParams.CertificatePassword = $CertificatePassword
} else {
    $connectParams.ClientSecret = $ClientSecret
}

Connect-PnPOnline @connectParams

New-PnPSite -Type $Type -Title $Title -Url "https://$SharePointTenant.sharepoint.com/sites/$Name" -Owner ($Owner -join ";")