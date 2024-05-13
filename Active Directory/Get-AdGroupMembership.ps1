#requires -Version 7.0
#requires -Module ActiveDirectory

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