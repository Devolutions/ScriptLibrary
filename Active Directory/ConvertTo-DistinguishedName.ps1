<#
.SYNOPSIS
Converts a domain name and optionally an OU path into a distinguished name (DN) format.

.DESCRIPTION
The ConvertTo-DistinguishedName function takes a domain name and an optional organizational unit (OU) path and converts 
them into a distinguished name format used in LDAP environments. This is useful for scripting against Active Directory 
and other directory services.

.PARAMETER DomainName
Specifies the domain name to convert into the distinguished name format. The domain name must be in 'domain.com' format.

.PARAMETER OUPath
Specifies the organizational unit path which will be included in the distinguished name. This parameter is optional. 
If provided, it should be in the LDAP OU path format but can use either '\' or '/' as separators.

.EXAMPLE
PS> .\ConvertTo-DistinguishedName.ps1 -DomainName "example.com"
Outputs: "DC=example,DC=com"
This example converts a simple domain name into its distinguished name format.

.EXAMPLE
PS> .\ConvertTo-DistinguishedName.ps1 -DomainName "example.com" -OUPath "OU=Sales\OU=West"
Outputs: "OU=West,OU=Sales,DC=example,DC=com"
This example includes an organizational unit path in the distinguished name conversion.

.OUTPUTS
String
Returns the distinguished name as a string.
#>
[CmdletBinding()]
[OutputType([string])]
param
(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^\w+\.\w+$')]
    [string]$DomainName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OUPath
)

$domainSplit = $DomainName.Split('.')

if ($PSBoundParameters.ContainsKey('OUPath')) {
    $OUPath = $OUPath.Replace('\', '/')
    $ouSplit = $OUPath.Split('/')
    "OU=$($ouSplit -join ',OU='),DC=$($domainSplit -join ',DC=')"
} else {
    "DC=$($domainSplit -join ',DC=')"
}