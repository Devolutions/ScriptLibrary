#requires -Modules @{ModuleName="pnp.powershell";ModuleVersion="2.4.0"}

<#
.SYNOPSIS
    Connects to a SharePoint Online site and uploads a file to a specified folder.

.DESCRIPTION
    This script connects to a SharePoint Online site using either certificate authentication or client secret authentication. 
    After establishing the connection, it uploads a specified file to a destination folder within the SharePoint site.

.PARAMETER EntraIdTenantId
    The GUID of the Azure AD tenant ID.

.PARAMETER SharePointTenant
    The SharePoint Online tenant name.

.PARAMETER PrivateKeyFilePath
    The file path of the private key used for certificate authentication.

.PARAMETER PrivateKeyPassword
    The password for the private key used for certificate authentication.

.PARAMETER ClientId
    The Client ID of the Azure AD application.

.PARAMETER ClientSecret
    The client secret of the Azure AD application used for client secret authentication.

.PARAMETER SourceFilePath
    The full path of the source file to be uploaded.

.PARAMETER DestinationFolderPath
    The destination folder path within the SharePoint Online site where the file will be uploaded.

.NOTES
    Requires the 'pnp.powershell' module version 2.4.0 or higher.
    For more information on PnP PowerShell, visit: https://pnp.github.io/powershell/

.EXAMPLE
    PS> .\Invoke-SharePointOnlineFileUpload -EntraIdTenantId '00000000-0000-0000-0000-000000000000' -SharePointTenant 'contoso' -PrivateKeyFilePath 
    'C:\path\to\privatekey.pfx' -PrivateKeyPassword (ConvertTo-SecureString -String 'password' -AsPlainText -Force) -ClientId 
    '00000000-0000-0000-0000-000000000000' -SourceFilePath 'C:\path\to\sourcefile.txt' -DestinationFolderPath 'Shared Documents'
    
    This example connects to the SharePoint Online site 'https://contoso.sharepoint.com' using certificate authentication 
    and uploads the file 'C:\path\to\sourcefile.txt' to the 'Shared Documents' folder.

.EXAMPLE
    PS> .\Invoke-SharePointOnlineFileUpload -EntraIdTenantId '00000000-0000-0000-0000-000000000000' -SharePointTenant 'contoso' -ClientId 
    '00000000-0000-0000-0000-000000000000' -ClientSecret (ConvertTo-SecureString -String 'clientsecret' -AsPlainText -Force) -SourceFilePath 
    'C:\path\to\sourcefile.txt' -DestinationFolderPath 'Shared Documents'
    
    This example connects to the SharePoint Online site 'https://contoso.sharepoint.com' using client secret authentication 
    and uploads the file 'C:\path\to\sourcefile.txt' to the 'Shared Documents' folder.
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
    [ValidateScript(
        { Test-Path -Path $_ -PathType Leaf },
        ErrorMessage = 'The file [{0}] does not exist.'
    )]
    [uri]$SourceFilePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationFolderPath
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

$pnpFileParams = @{
    Path   = $SourceFilePath
    Folder = $DestinationFolderPath
}
Add-PnPFile @pnpFileParams
