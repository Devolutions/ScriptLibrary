#requires -Modules @{ModuleName="pnp.powershell";ModuleVersion="2.4.0"}

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