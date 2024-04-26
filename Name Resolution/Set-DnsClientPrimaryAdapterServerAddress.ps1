<#
.SYNOPSIS
Updates the DNS server search order on network adapters.

.DESCRIPTION
This script checks network adapters that have a default gateway and are IP enabled. 
It updates the DNS server search order if the current order differs from the specified addresses.

.PARAMETER ServerAddress
A mandatory array of DNS server IP addresses (in string format) to be set as the new search order.

.EXAMPLE
Update DNS settings using two DNS servers:
.\Set-DnsClientPrimaryAdapterServerAddress.ps1 -ServerAddress "10.0.0.10", "10.0.0.20" 
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ServerAddress
)

Get-CimInstance -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled='true' AND DefaultIPGateway[0]" | 
    Where-Object { $_.DNSServerSearchOrder -notmatch ($ServerAddress -join ',') } | # Filter for adapters needing updates
    ForEach-Object {
        Write-Verbose "Changing DNS server search order to '$($ServerAddress -join ',')'"

        $setDnsResult = $_.SetDNSServerSearchOrder($ServerAddress)  # Update the DNS search order 
        if ($setDnsResult.ReturnValue -notin @(0, 1)) {   # Basic error checking
            throw "Error setting DNS server search order: [$setDnsResult]"
        }
    }
