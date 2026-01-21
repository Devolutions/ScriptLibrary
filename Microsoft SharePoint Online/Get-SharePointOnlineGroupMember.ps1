#requires -Modules @{ModuleName="pnp.powershell";ModuleVersion="2.4.0"}

<#
.SYNOPSIS
    Connects to a SharePoint tenant and retrieves members of specified site groups.

.DESCRIPTION
    This script connects to a SharePoint tenant using either certificate or client secret authentication, then retrieves and lists 
    members of the specified site groups. The connection parameters are specified through mandatory parameters, and the script 
    ensures that proper authentication is used based on the provided parameters.

.PARAMETER EntraIdTenantId
    The GUID of the Entra ID (Azure AD) tenant.

.PARAMETER SharePointTenant
    The name of the SharePoint tenant.

.PARAMETER PrivateKeyFilePath
    The file path to the private key used for certificate authentication. This parameter is mandatory if using certificate 
    authentication.

.PARAMETER PrivateKeyPassword
    The password for the private key file used for certificate authentication. This parameter is mandatory if using certificate 
    authentication.

.PARAMETER ClientId
    The client ID of the Azure AD app registration.

.PARAMETER ClientSecret
    The client secret used for client secret authentication. This parameter is mandatory if using client secret authentication.

.PARAMETER GroupName
    The name of the SharePoint group to retrieve members from. Optional parameter.

.PARAMETER SiteUrl
    The URL of the SharePoint site to retrieve groups from. Optional parameter.

.NOTES
    For more information on using PnP PowerShell, visit: https://pnp.github.io/powershell/

.EXAMPLE
    PS> .\Get-SharePointGroupMembers.ps1 -EntraIdTenantId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -SharePointTenant 'contoso' -ClientId 'xxxx-xxxx-xxxx-xxxx' -ClientSecret (ConvertTo-SecureString 'your-secret' -AsPlainText -Force)
    <output here>
    
    Connects to the SharePoint tenant 'contoso' using client secret authentication and lists members of all site groups.

.EXAMPLE
    $sharePointOnlineRequiredResourceAccess = @(
            @{
                ResourceAppId = "00000003-0000-0ff1-ce00-000000000000"  ## Sharepoint Online resource app id
                ResourceAccess = @(
                    @{
                        Id = "fbcd29d2-fcca-4405-aded-518d457caae4"     # Permission ID: Sites.ReadWrite.All
                        Type = "Role"
                    }
                )
            }
        )
    $app = New-AzADApplication -DisplayName SharePointOnlineSiteAuth -RequiredResourceAccess $sharePointOnlineRequiredResourceAccess
    PS> Connect-AzAccount
    PS> $tenantId = (Get-AzContext).Tenant.Id
    PS> $cert = New-SelfSignedCertificate -DnsName PowerShellAuth -CertStoreLocation cert:\CurrentUser\My
    PS> $pwd = ConvertTo-SecureString -String "P@ss0word!" -Force -AsPlainText
    PS> Export-PfxCertificate -Cert $cert -FilePath .\cert.pfx -Password $pwd
    PS> Export-Certificate -Cert $cert -FilePath .\cert.cer

    ## remove the cert from the cert store
    PS> $cert | Remove-Item

    PS> $PfxCertificate = Get-PfxCertificate -FilePath ~/cert.pfx -Password (ConvertTo-SecureString -String 'P@ss0word!' -AsPlainText -Force)

    PS> .\Get-SharePointGroupMembers.ps1 -EntraIdTenantId $tenantId -SharePointTenant 'contoso' -ClientId $app.AppId -PrivateKeyFilePath '.\cert.pfx -PrivateKeyPassword $pwd -GroupName 'Site Members'
    <output here>

    Connects to the SharePoint tenant 'contoso' using certificate authentication and lists members of the 'Site Members' group.
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
    [string]$GroupName,

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

$getSiteGroupParams = @{}
if ($PSBoundParameters.ContainsKey('GroupName')) {
    $getSiteGroupParams.Group = $GroupName
}
if ($PSBoundParameters.ContainsKey('SiteUrl')) {
    $getSiteGroupParams.Site = $SiteUrl.ToString()
}

Get-PnPSiteGroup @getSiteGroupParams -PipelineVariable 'group' | ForEach-Object {
    Get-PnPGroupMember -Group $group.Title | ForEach-Object {
        [pscustomobject]@{
            GroupName = $group.Title
            LoginName = $_.LoginName
            Title     = $_.Title
        }
    }
}