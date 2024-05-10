#requires -Version 7
#requires -Modules DNSServer

<#
.SYNOPSIS
Updates DNS records in specified DNS server zone.

.DESCRIPTION
This script updates DNS records such as A, AAAA, CNAME, MX, NS, PTR, SOA, SRV, and TXT in a specified DNS zone on a DNS
server. The script requires mandatory input parameters including the name, type, and zone name of the DNS record, along 
with specific parameters based on the type of DNS record being updated.

.PARAMETER Name
The name of the DNS record to update.

.PARAMETER Type
The type of DNS record to update. Valid options include A, AAAA, CNAME, MX, NS, PTR, SOA, SRV, and TXT.

.PARAMETER ZoneName
The name of the DNS zone where the record resides.

.PARAMETER IPv4Address
The IPv4 address for the A record type. This parameter is mandatory when updating an A record.

.PARAMETER IPv6Address
The IPv6 address for the AAAA record type. This parameter is mandatory when updating an AAAA record.

.PARAMETER HostNameAlias
The alias for the CNAME record type. This parameter is mandatory when updating a CNAME record.

.PARAMETER MailExchange
The mail exchange server for the MX record type.

.PARAMETER Preference
The preference number for the MX record type, which is used to prioritize mail delivery if multiple MX records exist.

.PARAMETER PtrDomainName
The domain name for the PTR record type. This parameter is mandatory when updating a PTR record.

.PARAMETER DomainName
The domain name for the SRV record type. This parameter is mandatory when updating an SRV record.

.PARAMETER Priority
The priority of the SRV record, which helps to determine the order in which the records are used.

.PARAMETER Weight
The weight of the SRV record, which is used to determine load balancing between multiple servers that provide equivalent 
services.

.PARAMETER Port
The port number for the SRV record type. This parameter is mandatory when updating an SRV record.

.PARAMETER TextRecord
The descriptive text for the TXT record type. This parameter is mandatory when updating a TXT record.

.PARAMETER TimeToLive
The time to live (TTL) of the DNS record in hours. This parameter is optional.

.PARAMETER Server
Specifies the target DNS server where the DNS zone and record are located. The default is 'localhost'.

.EXAMPLE
PS> .\Update-DnsRecord.ps1 -Name "example" -Type "A" -ZoneName "example.com" -IPv4Address "192.168.1.1" -Server "dns.example.com"

This example updates an A record for "example.example.com" with the IPv4 address "192.168.1.1" in the DNS zone "example.com" 
on the server "dns.example.com".

.NOTES
For more details on DNS records and PowerShell DNS server module, visit:
https://docs.microsoft.com/en-us/powershell/module/dnsserver/?view=windowsserver2022-ps

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern("^[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*$")]
    [string]$Name,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('A', 'AAAA', 'CNAME', 'MX', 'NS', 'PTR', 'SOA', 'SRV', 'TXT')]
    [string]$Type,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern("^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*$")]
    [string]$ZoneName,

    [Parameter(Mandatory, ParameterSetName = 'A')]
    [ValidateNotNullOrEmpty()]
    [ipaddress]$IPv4Address,

    [Parameter(Mandatory, ParameterSetName = 'AAAA')]
    [ValidateNotNullOrEmpty()]
    [ipaddress]$IPv6Address,

    [Parameter(Mandatory, ParameterSetName = 'CNAME')]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern("^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*$")]
    [string]$HostNameAlias,

    [Parameter(ParameterSetName = 'MX')]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern("^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*$")]
    [string]$MailExchange,

    [Parameter(ParameterSetName = 'MX')]
    [ValidateNotNullOrEmpty()]
    [int]$Preference,

    [Parameter(Mandatory, ParameterSetName = 'PTR')]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern("^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*$")]
    [string]$PtrDomainName,

    [Parameter(Mandatory, ParameterSetName = 'SRV')]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern("^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*$")]
    [string]$DomainName,

    [Parameter(Mandatory, ParameterSetName = 'SRV')]
    [ValidateNotNullOrEmpty()]
    [int]$Priority,

    [Parameter(Mandatory, ParameterSetName = 'SRV')]
    [ValidateNotNullOrEmpty()]
    [int]$Weight,

    [Parameter(Mandatory, ParameterSetName = 'SRV')]
    [ValidateNotNullOrEmpty()]
    [int]$Port,

    [Parameter(Mandatory, ParameterSetName = 'TXT')]
    [ValidateNotNullOrEmpty()]
    [string]$TextRecord,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [int]$TimeToLive,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Server = 'localhost'

)

$ErrorActionPreference = 'Stop'

#region Functions
function testDnsServerZone ($zoneName) {
    try { 
        ## Force the command to stop on error, ensuring that the script does not proceed with an invalid zone.
        $null = Get-DnsServerZone -Name $zoneName -ErrorAction Stop
        $true
    } catch [Microsoft.Management.Infrastructure.CimException] {
        ## Handle specific exception when the DNS zone is not found, returning false to indicate absence.
        if ($_.Exception.Message -like '*was not found on server*') {
            $false
        } else {
            ## Re-throw any other exceptions to be handled upstream.
            throw $_
        }
    }
}

function getRecord ($name, $zonename, $computername, $rrtype) {
    try {
        Get-DnsServerResourceRecord @PSBoundParameters
    } catch [Microsoft.Management.Infrastructure.CimException] {
        if ($_.Exception.Message -like 'Failed to get * record*') {
            throw "The DNS record [$Name] type [$Type] does not exist on [$Server] in zone [$ZoneName]."
        } else {
            throw $_
        }
    }
}
#endregion

$getParams = @{
    Name         = $Name
    ZoneName     = $ZoneName
    ComputerName = $Server
    RRType       = $Type
}

if ($PSCmdlet.ParameterSetName -ne $Type) {
    throw "Invalid parameter(s) used for updating the [$Type] DNS record."
}

try {
    ## Ensure the DNS zone exists before attempting to add a record.
    if (!(testDnsServerZone $ZoneName)) {
        throw "DNS zone [$ZoneName] not found on server [$Server]"
    } else {
        $record = getRecord @getParams

        $newRecord = [ciminstance]::new($record)

        switch ($Type) {
            'A' {
                $newRecord.RecordData.IPv4Address = $IPv4Address
            }
            'AAAA' {
                $newRecord.RecordData.IPv6Address = $IPv6Address
            }
            'CNAME' {
                $newRecord.RecordData.HostNameAlias = $HostNameAlias

            }
            'MX' {
                if (!$MailExchange -and !$Preference) {
                    throw "Either MailExchange or Preference must be provided for an MX record."
                } else {
                    if ($MailExchange) {
                        $newRecord.RecordData.MailExchange = $MailExchange
                    }
                    if ($Preference) {
                        $newRecord.RecordData.Preference = $Preference
                    }
                }
            }
            'PTR' {
                $newRecord.RecordData.PtrDomainName = $PtrDomainName
            }
            'SRV' {
                $newRecord.RecordData.DomainName = $DomainName  
                $newRecord.RecordData.Port = $Port
                $newRecord.RecordData.Priority = $Priority
                $newRecord.RecordData.Weight = $Weight
            }
            'TXT' {
                $newRecord.RecordData.DescriptiveText = $TextRecord
            }
            default {
                ## Handle unexpected record types by throwing an error.
                throw "Unrecognized input: [$_]"
            }
        }

        if ($PSBoundParameters.ContainsKey('TimeToLive')) {
            $newRecord.TimeToLive = [System.TimeSpan]::FromHours($TimeToLive)
        }

        $setParams = @{
            ZoneName       = $ZoneName
            ComputerName   = $Server
            OldInputObject = $record
            NewInputObject = $newRecord
        }

        Set-DnsServerResourceRecord @setParams

    }
} catch {
    ## Provide a clear error message if something goes wrong during the record addition.
    throw "An error occurred while adding the DNS record. Error: $($_.Exception.Message)"
}