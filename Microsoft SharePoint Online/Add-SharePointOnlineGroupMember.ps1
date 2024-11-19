#requires -Modules @{ModuleName="pnp.powershell";ModuleVersion="2.4.0"}

<#
.SYNOPSIS
    Connects to a SharePoint tenant and adds a specified user to a specified group.

.DESCRIPTION
    This script connects to a SharePoint tenant using either certificate-based or client secret-based authentication. 
    It verifies the existence of the specified group and user within the SharePoint tenant. If both the group and 
    user are found, it adds the user to the group.

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

.PARAMETER GroupName
    The name of the SharePoint group to which the user will be added.

.PARAMETER LoginName
    The login name of the user to be added to the group.

.PARAMETER SiteUrl
    The URL of the SharePoint site. This parameter is optional.

.NOTES
    To run this script, you need the PnP PowerShell module installed with version 2.4.0 or higher.
    For more information on PnP PowerShell, visit: https://pnp.github.io/powershell/

.EXAMPLE
    PS> .\Add-SharePointOnlineGroupMember.ps1 -EntraIdTenantId "00000000-0000-0000-0000-000000000000" -SharePointTenant "yourtenant" `
                              -PrivateKeyFilePath "C:\keys\privatekey.pfx" -PrivateKeyPassword (ConvertTo-SecureString "password" -AsPlainText -Force) `
                              -ClientId "00000000-0000-0000-0000-000000000000" -GroupName "TeamSite Members" -LoginName "user@domain.com"
    Connects to the specified SharePoint tenant using certificate-based authentication and adds the user to the specified group.

.EXAMPLE
    PS> .\Add-SharePointOnlineGroupMember.ps1 -EntraIdTenantId "00000000-0000-0000-0000-000000000000" -SharePointTenant "yourtenant" `
                              -ClientId "00000000-0000-0000-0000-000000000000" -ClientSecret (ConvertTo-SecureString "secret" -AsPlainText -Force) `
                              -GroupName "TeamSite Members" -LoginName "user@domain.com"
    Connects to the specified SharePoint tenant using client secret-based authentication and adds the user to the specified group.
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

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$GroupName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$LoginName,

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

try {
    $null = Get-PnPSiteGroup -Group $GroupName
} catch {
    if ($_.Exception.Message -like '*Group not found*') {
        throw "The group [$GroupName] was not found"
    } else {
        throw $_
    }
}

if (-not (Get-PnpUser -Identity $LoginName)) {
    throw "User [$LoginName] was not found"
}

Add-PnPGroupMember -LoginName $LoginName -Group $GroupName