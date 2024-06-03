#requires -Modules @{ModuleName="pnp.powershell";ModuleVersion="2.4.0"}

<#
.SYNOPSIS
    Connects to a SharePoint tenant and downloads a specified file from the site to a local folder.

.DESCRIPTION
    This script connects to a SharePoint tenant using either certificate-based or client secret-based authentication. 
    It downloads a file from the specified SharePoint path to a local folder. The script ensures that the destination 
    folder exists and supports overwriting the file if the -Force switch is specified.

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

.PARAMETER SourceFilePath
    The URI path of the source file in the SharePoint site.

.PARAMETER DestinationFolderPath
    The local path to the folder where the file will be downloaded. The folder must exist.

.PARAMETER Force
    If specified, forces the download by overwriting the file if it already exists in the destination folder.

.NOTES
    To run this script, you need the PnP PowerShell module installed with version 2.4.0 or higher.
    For more information on PnP PowerShell, visit: https://pnp.github.io/powershell/

.EXAMPLE
    PS> .\Invoke-SharePointOnlineFileDownload.ps1 -EntraIdTenantId "00000000-0000-0000-0000-000000000000" -SharePointTenant "yourtenant" `
                                      -PrivateKeyFilePath "C:\keys\privatekey.pfx" -PrivateKeyPassword (ConvertTo-SecureString "password" -AsPlainText -Force) `
                                      -ClientId "00000000-0000-0000-0000-000000000000" -SourceFilePath "/sites/sitecollection/documents/file.txt" `
                                      -DestinationFolderPath "C:\Downloads"
    Connects to the specified SharePoint tenant using certificate-based authentication and downloads the specified file to the local folder.

.EXAMPLE
    PS> .\Invoke-SharePointOnlineFileDownload -EntraIdTenantId "00000000-0000-0000-0000-000000000000" -SharePointTenant "yourtenant" `
                                      -ClientId "00000000-0000-0000-0000-000000000000" -ClientSecret (ConvertTo-SecureString "secret" -AsPlainText -Force) `
                                      -SourceFilePath "/sites/sitecollection/documents/file.txt" -DestinationFolderPath "C:\Downloads" -Force
    Connects to the specified SharePoint tenant using client secret-based authentication and downloads the specified file to the local folder, 
    overwriting the file if it already exists.
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
    [uri]$SourceFilePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript(
        { Test-Path -Path $_ -PathType Container },
        ErrorMessage = 'The folder [{0}] does not exist.'
    )]
    [string]$DestinationFolderPath,

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$tenantUrl = "https://$SharePointTenant.sharepoint.com"

$connectParams = @{
    ClientId = $ClientId
    Tenant   = $EntraIdTenantId
    Url      = $tenantUrl
}

if ($PSCmdlet.ParameterSetName -eq 'CertificateAuth') {
    $connectParams.CertificatePath = $PrivateKeyFilePath
    $connectParams.CertificatePassword = $PrivateKeyPassword
} else {
    $connectParams.ClientSecret = $ClientSecret
}

Connect-PnPOnline @connectParams

$sourceFileUrl = '{0}/{1}' -f $tenantUrl, $SourceFilePath
$encodedSourceFileUrl = [uri]::EscapeUriString($sourceFileUrl)

$pnpFileParams = @{
    Url      = $encodedSourceFileUrl
    Path     = $DestinationFolderPath
    FileName = ($SourceFilePath | Split-Path -Leaf)
    AsFile   = $true
}
$pnpFileParams.Force = $Force.IsPresent ? $true : $false
Get-PnPFile @pnpFileParams