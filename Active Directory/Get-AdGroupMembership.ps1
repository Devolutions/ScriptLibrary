#requires -Version 7.0
#requires -Module ActiveDirectory

<#
.SYNOPSIS
Retrieves the group memberships of a specified Active Directory user.

.DESCRIPTION
This script fetches and lists the groups that a specified user is a member of within Active Directory. It requires 
the user's name and optionally the domain name and credentials for authentication. If the domain name is not provided,
it defaults to the domain of the computer executing the script. The script supports execution in environments where the
computer is part of a workgroup by accepting credentials via the Credential parameter.

.PARAMETER UserName
Specifies the username of the Active Directory account for which to retrieve group memberships. This parameter is mandatory.

.PARAMETER DomainName
Specifies the domain in which to search for the user. If not provided, the domain of the computer executing the script
is used.

.PARAMETER Credential
Provides the credentials to authenticate with Active Directory when the executing machine is in a workgroup or 
different credentials are needed to access the domain.

.EXAMPLE
PS> .\Get-AdGroupMembership.ps1 -UserName "jdoe" -DomainName "corp.contoso.com"

This example retrieves the group memberships of the user 'jdoe' in the 'corp.contoso.com' domain.

.EXAMPLE
PS> .\Get-AdGroupMembership.ps1 -UserName "jdoe" -Credential (Get-Credential)

This example prompts for credentials and retrieves the group memberships of the user 'jdoe' in the domain of the executing
machine.

.NOTES
This script is dependent on the ActiveDirectory module and requires at least PowerShell version 7.0. It will throw
exceptions if the user is not found or if there are issues with fetching data from Active Directory.

For more information on the Active Directory cmdlets used in this script, visit:
https://docs.microsoft.com/en-us/powershell/module/activedirectory/?view=windowsserver2022-ps

#>


[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$UserName,
    
    [Parameter()]
    [string]$DomainName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [pscredential]$Credential
)

$ErrorActionPreference = 'Stop'

#region Functions

function getDomainMembership {
    $computerSystem = Get-CimInstance -Class Win32_ComputerSystem
    [pscustomobject]@{
        IsInWorkgroup = $computerSystem.DomainRole -in @(0, 2)
        Domain        = $computerSystem.Domain
    }
}

#endregion

#region Prereq checks
$domainMembership = getDomainMembership
if (!$PSBoundParameters.ContainsKey('Credential') -and $domainMembership.IsInWorkgroup) {
    throw "The current machine is in a workgroup. Please provide valid credentials using the Credential parameter to authenticate to the domain [$DomainName]."
}
#endregion

if (!$PSBoundParameters.ContainsKey('DomainName') -and !$domainMembership.IsInWorkgroup) {
    $DomainName = $domainMembership.Domain
}

try {
    $getAdUserParams = @{
        Identity   = $UserName
        Server     = $DomainName
        Properties = 'MemberOf'
    }
    if ($PSBoundParameters.ContainsKey('Credential')) {
        $getAdUserParams.Credential = $Credential
    }
    $adUser = Get-ADUser @getAdUserParams
} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    throw "User '$UserName' not found in domain '$DomainName'."
} catch {
    throw "An error occurred while fetching the user '$UserName': $_"
}

# Get the group names from the MemberOf property
$adUser.MemberOf | ForEach-Object { 
    ($_ -split ',')[0].Substring(3) 
}