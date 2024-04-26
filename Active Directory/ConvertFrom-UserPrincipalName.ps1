
<#
.SYNOPSIS
Converts a User Principal Name (UPN) to a DOMAIN\Username format.

.DESCRIPTION
Takes a User Principal Name (UPN) as input and converts it to a DOMAIN\Username format. The UPN must be in the correct 
format (username@domain.com).

.PARAMETER UserPrincipalName
The User Principal Name that needs to be converted. Must contain an "@" symbol and be in the format username@domain.com.

.EXAMPLE
PS> ConvertFrom-UserPrincipalName -UserPrincipalName "jdoe@example.com"
Outputs: EXAMPLE\jdoe
This example converts the UPN "jdoe@example.com" into "EXAMPLE\jdoe".

.INPUTS
String
You can pipe a string that represents the user principal name to ConvertFrom-UserPrincipalName.

.OUTPUTS
String
Returns the DOMAIN\Username format.
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateScript( {
            if ($_.Contains('@') -eq $false) {
                throw 'The parameter is not in the correct format.'
            } else { $true }
        })]
    [string]$UserPrincipalName
)


$upnParts	= $UserPrincipalName.Split('@')
$username	= $upnParts[0]
$domain = $upnParts[1].Split('.')[0]
'{0}\{1}' -f $domain.ToUpper(), $username