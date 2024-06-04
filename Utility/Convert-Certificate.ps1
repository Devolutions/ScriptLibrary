<#
.SYNOPSIS
    Converts a certificate from one format to another.

.DESCRIPTION
    This script converts a certificate file from one format to another, supporting PFX, PEM, and DER formats. 
    It handles the conversion based on the source and destination file extensions, and optionally uses a password 
    for PFX files. The script can also force overwrite the destination file if it already exists.

.PARAMETER SourcePath
    The path to the source certificate file. The file must exist.

.PARAMETER DestinationPath
    The path to the destination certificate file. The script will convert the source certificate to this file.

.PARAMETER Password
    The password for the PFX certificate, if applicable.

.PARAMETER Force
    Forces the script to overwrite the destination file if it already exists.

.NOTES
    To validate the converted certificates, you can use the following OpenSSL commands:
    - For PEM: `openssl x509 -in ./output.pem -inform pem -text -noout`
    - For DER: `openssl verify -CAfile ./output.der ./output.der`
    - For PFX: `openssl pkcs12 -info -in ./output.pfx`

.EXAMPLE
    PS> .\Convert-Certificate.ps1 -SourcePath 'C:\path\to\cert.pfx' -DestinationPath 'C:\path\to\cert.pem' -Password (ConvertTo-SecureString 'password' -AsPlainText -Force) -Force
    
    This example converts a PFX certificate to a PEM certificate, using a specified password and forcing overwrite of the destination file.

.EXAMPLE
    PS> .\Convert-Certificate.ps1 -SourcePath 'C:\path\to\cert.pem' -DestinationPath 'C:\path\to\cert.der'
    
    This example converts a PEM certificate to a DER certificate.

.EXAMPLE
    PS> .\Convert-Certificate.ps1 -SourcePath 'C:\path\to\cert.der' -DestinationPath 'C:\path\to\cert.pem'
    
    This example converts a DER certificate to a PEM certificate.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript(
        { Test-Path -Path $_ -PathType Leaf },
        ErrorMessage = 'The file [{0}] does not exist.'
    )]
    [string]$SourcePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [securestring]$Password,

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Function to extract file extension and convert to certificate type
function Get-CertificateType {
    param (
        [string]$Path
    )
    $extension = [System.IO.Path]::GetExtension($Path).TrimStart('.')
    switch ($extension.ToUpper()) {
        'PFX' { return 'PFX' }
        'PEM' { return 'PEM' }
        'DER' { return 'DER' }
        default { throw "Unsupported file extension: $extension" }
    }
}

try {
    $SourceType = Get-CertificateType -Path $SourcePath
    $DestinationType = Get-CertificateType -Path $DestinationPath

    # Check if destination file exists and handle based on $Force parameter
    if (Test-Path -Path $DestinationPath -PathType Leaf) {
        if (-not $Force) {
            throw "The destination file already exists. Use -Force to overwrite."
        }
    }

    switch ($SourceType) {
        'PFX' {
            $pfxPassword = $Password | ConvertFrom-SecureString -AsPlainText
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($SourcePath, $pfxPassword)

            if ($DestinationType -eq 'PEM') {
                $pemBytes = [System.Text.Encoding]::UTF8.GetBytes($cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
                [System.IO.File]::WriteAllBytes($DestinationPath, $pemBytes)
            } elseif ($DestinationType -eq 'DER') {
                $derBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
                [System.IO.File]::WriteAllBytes($DestinationPath, $derBytes)
            }
        }
        'PEM' {
            if ($DestinationType -eq 'PFX') {
                $pfxPassword = $Password | ConvertFrom-SecureString -AsPlainText
                $pemContent = Get-Content $SourcePath -Raw
                $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
                $certCollection.ImportFromPem($pemContent)
                
                # Assuming you want to export the first certificate in the collection
                $cert = $certCollection[0]
                $bytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $pfxPassword)
                [System.IO.File]::WriteAllBytes($DestinationPath, $bytes)
            } elseif ($DestinationType -eq 'DER') {
                $pemContent = Get-Content $SourcePath -Raw
                $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
                $certCollection.ImportFromPem($pemContent)
                
                # Assuming you want to export the first certificate in the collection
                $cert = $certCollection[0]
                $derBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
                [System.IO.File]::WriteAllBytes($DestinationPath, $derBytes)
            }
        }
        'DER' {
            if ($DestinationType -eq 'PFX') {
                throw "Cannot convert from DER to PFX without the private key."
            } elseif ($DestinationType -eq 'PEM') {
                try {
                    $derBytes = [System.IO.File]::ReadAllBytes($SourcePath)
                    # Ensure that the byte array is not empty or malformed
                    if ($derBytes.Length -eq 0) {
                        throw "The DER file appears to be empty or invalid."
                    }

                    # Load the certificate from DER bytes using the constructor
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($derBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)

                    # Export the certificate to PEM format
                    $pemBytes = [System.Text.Encoding]::UTF8.GetBytes("-----BEGIN CERTIFICATE-----`n" + [System.Convert]::ToBase64String($cert.RawData, 'InsertLineBreaks') + "`n-----END CERTIFICATE-----")
                    [System.IO.File]::WriteAllBytes($DestinationPath, $pemBytes)
                } catch {
                    throw "Failed to load or convert the DER file: $($_.Exception.Message)"
                }
            }
        }
    }
} catch {
    throw "An error occurred during the certificate conversion: $($_.Exception.Message)"
}