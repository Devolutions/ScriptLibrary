#requires -Version 7.0
#requires -Module ActiveDirectory

<#
.SYNOPSIS
Unlocks a user's account in Active Directory.

.DESCRIPTION
This script unlocks an Active Directory user's account. It requires the user's name and optionally the domain name and credentials.
If the domain name is not provided, it will use the domain of the computer where the script is executed. The script will
prompt for credentials if the computer is part of a workgroup.

.PARAMETER UserName
Specifies the name of the user whose account needs to be unlocked. This parameter is mandatory.

.PARAMETER DomainName
Specifies the domain where the user's account resides. If not provided, the script will attempt to use the domain of the
executing computer.

.PARAMETER Credential
Specifies the credentials to use when connecting to the Active Directory. This is required if the machine is part of a
workgroup or if different credentials are needed to access the domain.

.EXAMPLE
PS> .\Unlock-UserAccount.ps1 -UserName "jdoe" -DomainName "corp.contoso.com"

This command unlocks the account of user 'jdoe' in the 'corp.contoso.com' domain.

.EXAMPLE
PS> .\Unlock-UserAccount.ps1 -UserName "jdoe" -Credential (Get-Credential)

This command prompts for credentials and then unlocks the account of user 'jdoe' in the domain of the executing machine.

.NOTES
For more information about the Active Directory cmdlets used in this script, see:
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
        Identity = $UserName
        Server = $DomainName
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


$adUser | Unlock-ADAccount