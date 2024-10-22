<#
.SYNOPSIS
    Authenticates to Microsoft Graph using either a certificate or client secret and retrieves an access token.

.DESCRIPTION
    This script supports two authentication methods for accessing Microsoft Graph: certificate-based and client secret-based.
    Depending on the provided parameters, it constructs the appropriate request and retrieves an OAuth 2.0 access token from 
    Microsoft Identity Platform.

.PARAMETER Certificate
    The X.509 certificate used for certificate-based authentication. This parameter is mandatory for the CertificateAuth parameter set.

.PARAMETER PfxCertificate
    The PFX certificate used for signing the JWT in certificate-based authentication. This parameter is mandatory for the CertificateAuth parameter set.

.PARAMETER ClientId
    The client ID of the application in Azure AD. This parameter is mandatory for the ClientSecretAuth parameter set.

.PARAMETER ClientSecret
    The client secret associated with the application in Azure AD. This parameter is mandatory for the ClientSecretAuth parameter set.

.PARAMETER Scope
    The scope of the access request. The default value is 'https://graph.microsoft.com/.default'.

.PARAMETER TenantId
    The Azure AD tenant ID. This parameter is mandatory.

.PARAMETER ApplicationId
    The application ID of the Azure AD application. This parameter is mandatory.

.NOTES
    For more information on Microsoft identity platform and OAuth 2.0, visit: 
    https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-client-creds-grant-flow

.EXAMPLE
    PS> $tenantId = (Get-AzContext).Tenant.Id
    PS> $appId = (Get-AzADApplication -DisplayName 'someapp').AppId
    PS> $pfxCert = get-pfxcertificate -FilePath 'path\to\your\pfx\file.pfx'
    PS> $cert = get-pfxcertificate -FilePath 'path\to\your\cert\file.cer'
    PS> .\Get-EntraIdAppAccessToken.ps1 -Certificate $cert -PfxCertificate $pfxCert -TenantId $tenantId -ApplicationId $appId
    <access_token_here>

    This example demonstrates how to use certificate-based authentication to retrieve an access token from Microsoft Graph.

.EXAMPLE
    PS> $tenantId = (Get-AzContext).Tenant.Id
    PS> $appId = (Get-AzADApplication -DisplayName 'Entra ID').AppId
    PS> .\Get-EntraIdAppAccessToken.ps1 -ClientId $appId -ClientSecret $secureSecret -TenantId $tenantId -ApplicationId $appId
    <access_token_here>

    This example demonstrates how to use client secret-based authentication to retrieve an access token from Microsoft Graph.
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory, ParameterSetName = 'CertificateAuth')]
    [ValidateNotNullOrEmpty()]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

    [Parameter(Mandatory, ParameterSetName = 'CertificateAuth')]
    [ValidateNotNullOrEmpty()]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$PfxCertificate,

    [Parameter(Mandatory, ParameterSetName = 'ClientSecretAuth')]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,

    [Parameter(Mandatory, ParameterSetName = 'ClientSecretAuth')]
    [ValidateNotNullOrEmpty()]
    [SecureString]$ClientSecret,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Scope = 'https://graph.microsoft.com/.default',

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationId
)

$ErrorActionPreference = 'Stop'

$httpBody = @{
    client_id  = $ApplicationId
    scope      = $Scope
    grant_type = "client_credentials"
}

$getIrmParams = @{
    ## Dont use tenant name here or you will get "Specified tenant identifier ...... is neither a valid DNS name, nor a valid external domain"
    Uri         = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    Method      = 'POST'
    ContentType = "application/x-www-form-urlencoded"
}

switch ($PSCmdlet.ParameterSetName) {
    'CertificateAuth' {
        # Create base64 hash of certificate  
        $CertificateBase64Hash = [System.Convert]::ToBase64String($Certificate.GetCertHash())  
  
        # Create JWT timestamp for expiration  
        $StartDate = (Get-Date "1970-01-01T00:00:00Z" ).ToUniversalTime()  
        $JWTExpirationTimeSpan = (New-TimeSpan -Start $StartDate -End (Get-Date).ToUniversalTime().AddMinutes(2)).TotalSeconds  
        $JWTExpiration = [math]::Round($JWTExpirationTimeSpan, 0)  
  
        # Create JWT validity start timestamp  
        $NotBeforeExpirationTimeSpan = (New-TimeSpan -Start $StartDate -End ((Get-Date).ToUniversalTime())).TotalSeconds  
        $NotBefore = [math]::Round($NotBeforeExpirationTimeSpan, 0)  
  
        # Create JWT header  
        $JWTHeader = @{  
            alg = "RS256"  
            typ = "JWT"  
            # Use the CertificateBase64Hash and replace/strip to match web encoding of base64  
            x5t = $CertificateBase64Hash -replace '\+', '-' -replace '/', '_' -replace '='  
        }  
  
        # Create JWT payload  
        $JWTPayLoad = @{  
            # What endpoint is allowed to use this JWT  
            ## Dont use tenant name here or you will get "Specified tenant identifier ...... is neither a valid DNS name, nor a valid external domain"
            aud = "https://login.microsoftonline.com/$TenantId/oauth2/token"  
            exp = $JWTExpiration  # Expiration timestamp  
            iss = $ApplicationId  # Issuer = your application  
            jti = [guid]::NewGuid()  # JWT ID: random guid  
            nbf = $NotBefore  # Not to be used before  
            sub = $ApplicationId  # JWT Subject  
        }  
  
        # Convert header and payload to base64  
        $JWTHeaderToByte = [System.Text.Encoding]::UTF8.GetBytes(($JWTHeader | ConvertTo-Json))  
        $EncodedHeader = [System.Convert]::ToBase64String($JWTHeaderToByte)  
  
        $JWTPayLoadToByte = [System.Text.Encoding]::UTF8.GetBytes(($JWTPayload | ConvertTo-Json))  
        $EncodedPayload = [System.Convert]::ToBase64String($JWTPayLoadToByte)  
  
        # Join header and Payload with "." to create a valid (unsigned) JWT  
        $JWT = $EncodedHeader + "." + $EncodedPayload  
  
        # Get the private key object of your certificate  
        $privKey = ([System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($PfxCertificate))  
  
        # Define RSA signature and hashing algorithm  
        $RSAPadding = [Security.Cryptography.RSASignaturePadding]::Pkcs1  
        $HashAlgorithm = [Security.Cryptography.HashAlgorithmName]::SHA256  
  
        # Create a signature of the JWT  
        $Signature = [Convert]::ToBase64String(  
            $privKey.SignData([System.Text.Encoding]::UTF8.GetBytes($JWT), $HashAlgorithm, $RSAPadding)  
        ) -replace '\+', '-' -replace '/', '_' -replace '='  
  
        # Join the signature to the JWT with "."  
        $jwt = $JWT + "." + $Signature

        $httpBody += @{
            client_assertion      = $jwt
            client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
        }

        $getIrmParams += @{
            Headers = @{
                Authorization = "Bearer $JWT"
            }
            Body    = $httpBody
        }
    }
    'ClientSecretAuth' {
        $httpBody.client_secret = [System.Net.NetworkCredential]::new("", $ClientSecret).Password
        $getIrmParams += @{
            Headers = @{
                Authorization = "Bearer $JWT"
            }
            Body        = $httpBody
        }
    }
    default {
        throw "Unrecognized input: [$_]"
    }
}

$Request = Invoke-RestMethod @getIrmParams

$Request.access_token