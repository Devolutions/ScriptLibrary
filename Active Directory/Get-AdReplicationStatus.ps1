#requires -Module ActiveDirectory

<#
.SYNOPSIS
    Checks the replication status of Active Directory domain controllers.

.DESCRIPTION
    This script evaluates the replication status among domain controllers within a specified scope. It checks if the target
    is reachable, retrieves all domain controllers, and queries the replication status for each.

.PARAMETER Target
    Specifies the target server from which to retrieve domain controllers. Defaults to "localhost".

.PARAMETER Scope
    Defines the scope to query domain controllers. Valid options are 'Forest', 'Domain', and 'Site'.
    Defaults to 'Domain'.

.EXAMPLE
    PS> .\ScriptName.ps1
    This command checks the replication status using default parameters (Target as localhost and Scope as Domain).

.EXAMPLE
    PS> .\ScriptName.ps1 -Target "dc01.example.com" -Scope "Forest"
    This command checks the replication status for all domain controllers in the forest from the specified target.

.INPUTS
    None

.OUTPUTS
    Outputs a custom object for each domain controller with the following properties:
    - SourceDc: Name of the source domain controller.
    - TargetDc: Name of the target domain controller.
    - LastReplicationSuccess: Timestamp of the last successful replication.
    - LastReplicationAttempt: Timestamp of the last replication attempt.
    - LastReplicationResult: Result of the last replication attempt.

.NOTES
    Requires the ActiveDirectory module. Ensure that the module is installed.
    The script uses TCP port 53 to test connection to the target server, assuming DNS service availability for connection check.

.LINK
    https://learn.microsoft.com/powershell/module/addsadministration/
#>


[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Target = "localhost",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Forest', 'Domain', 'Site')]
    [string]$Scope = 'Domain'
)

#region functions
function parseDistinguishedName {
    param(
        [Parameter(Mandatory)]
        [string]$DN
    )

    $split = $DN -split ',' -replace 'CN=|DC='
    [pscustomobject]@{
        Server    = $split[1]
        Site      = $split[3]
        Partition = $split[5]
        Domain    = ($split[6..7] -join '.')
    }
}

#endregion

if (-not (Test-Connection -ComputerName $Target -TcpPort 53 -Quiet)) {
    throw "Server target [$Target] is not reachable."
}
    
# Get all domain controllers in the specified scope
$domainControllers = Get-ADDomainController -Filter * -Server $Target

$whereFilter = { '* ' }
if ($Target -ne 'localhost') {
    $whereFilter = { $_.TargetDc -eq $Target }
}
    
# Check replication status for each domain controller
$replicationStatus = foreach ($dc in $domainControllers) {
    $partnerRepl = Get-ADReplicationPartnerMetadata -Target $dc.HostName
    $dnParts = parseDistinguishedName -DN $partnerRepl.Partner
    [pscustomobject]@{
        SourceDc               = ($dc.HostName -split '\.')[0]
        TargetDc               = $dnParts.Server
        LastReplicationSuccess = $partnerRepl.LastReplicationSuccess
        LastReplicationAttempt = $partnerRepl.LastReplicationAttempt
        LastReplicationResult  = $partnerRepl.LastReplicationResult
    }
}
$replicationStatus | Where-Object -FilterScript $whereFilter
