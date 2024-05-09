#requires -Version 7
#requires -Modules DNSServer

<#
.SYNOPSIS
Adds a DNS record to a specified DNS server zone.

.DESCRIPTION
This script adds a new DNS record to a zone on a DNS server using various DNS record types such as A, AAAA, CNAME, MX, PTR, SRV, and TXT.
The DNS record type and relevant parameters must be provided to successfully add the record.

.PARAMETER Name
Specifies the name of the DNS record to add.

.PARAMETER Type
Specifies the type of DNS record to add. Valid options are A, AAAA, CNAME, MX, NS, PTR, SOA, SRV, and TXT.

.PARAMETER ZoneName
Specifies the DNS zone name within which the record will be added.

.PARAMETER IPv4Address
Specifies the IPv4 address for the record. This parameter is mandatory for A record types.

.PARAMETER IPv6Address
Specifies the IPv6 address for the record. This parameter is mandatory for AAAA record types.

.PARAMETER HostNameAlias
Specifies the alias for the CNAME record. This parameter is mandatory for CNAME record types.

.PARAMETER MailExchange
Specifies the mail exchange server for the MX record. This parameter is mandatory for MX record types.

.PARAMETER Preference
Specifies the preference number for the MX record. This parameter is mandatory for MX record types.

.PARAMETER PtrDomainName
Specifies the domain name for the PTR record. This parameter is mandatory for PTR record types.

.PARAMETER DomainName
Specifies the domain name for the SRV record. This parameter is mandatory for SRV record types.

.PARAMETER Priority
Specifies the priority of the SRV record. This parameter is mandatory for SRV record types.

.PARAMETER Weight
Specifies the weight of the SRV record. This parameter is mandatory for SRV record types.

.PARAMETER Port
Specifies the port number for the SRV record. This parameter is mandatory for SRV record types.

.PARAMETER TextRecord
Specifies the text for the TXT record. This parameter is mandatory for TXT record types.

.PARAMETER TimeToLive
Specifies the time-to-live (TTL) for the DNS record.

.PARAMETER Server
Specifies the target DNS server where the record will be added. Defaults to 'localhost' if not specified.

.EXAMPLE
PS> .\Add-DnsRecord.ps1 -Name "example" -Type "A" -ZoneName "example.com" -IPv4Address "192.168.1.1"

This example adds an A record for "example.example.com" with the IPv4 address "192.168.1.1".

.EXAMPLE
PS> .\Add-DnsRecord.ps1 -Name "alias" -Type "CNAME" -ZoneName "example.com" -HostNameAlias "realhost.example.com"

This example adds a CNAME record for "alias.example.com" pointing to "realhost.example.com".

.NOTES
For more details on DNS management with PowerShell, visit:
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

    [Parameter(Mandatory, ParameterSetName = 'MX')]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern("^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*$")]
    [string]$MailExchange,

    [Parameter(Mandatory,ParameterSetName='MX')]
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

function getDnsRecords {
    ## Retrieve all DNS records from the specified zone to check for existing records.
    $records = Get-CimInstance -Namespace root\MicrosoftDNS -ClassName MicrosoftDNS_ResourceRecord -Filter "ContainerName = '$ZoneName'" | Select-Object -ExpandProperty textrepresentation
    $records | ForEach-Object {
        $name, $null, $type, $value = $_ -split ' '
        ## Create a custom object for each record for easier manipulation and checking.
        [pscustomobject]@{
            Name  = $name
            Type  = $type
            Value = $value -join ' '
        }
    }
}

function testDnsRecord ($name, $type) {        
    ## Use getDnsRecords to check if a specific record already exists to prevent duplicates.
    $records = getDnsRecords
    $matchingRecord = $records | Where-Object { $_.Name -match "^$name\.$zoneName$" -and ($type -eq 'CNAME' -or $_.Type -eq $type) }
    [bool]$matchingRecord
}
#endregion

$commonParams = @{
    Name         = $Name
    ZoneName     = $ZoneName
    ComputerName = $Server
}

## Add TimeToLive to the parameters only if it's explicitly provided, allowing for optional TTL configuration.
if ($PSBoundParameters.ContainsKey('TimeToLive')) {
    $commonParams.Add('TimeToLive', $TimeToLive)
}
try {
    ## Ensure the DNS zone exists before attempting to add a record.
    if (!(testDnsServerZone $ZoneName)) {
        throw "DNS zone [$ZoneName] not found on server [$Server]"
    ## Check for existing DNS record to avoid conflicts.
    } elseif (testDnsRecord $Name $Type) {
        throw "A DNS record [$Name] already exists on server [$Server]"
    } else {
        ## Depending on the record type, use the appropriate cmdlet to add the DNS record.
        switch ($Type) {
            'A' {
                Add-DnsServerResourceRecordA @commonParams -IPv4Address $IPv4Address
            }
            'AAAA' {
                Add-DnsServerResourceRecordAAAA @commonParams -IPv6Address $IPv6Address
            }
            'CNAME' {
                Add-DnsServerResourceRecordCNAME @commonParams -HostNameAlias $HostNameAlias
            }
            'MX' {
                Add-DnsServerResourceRecordMX @commonParams -MailExchange $MailExchange -Preference $Preference
            }
            'PTR' {
                Add-DnsServerResourceRecordPtr @commonParams -PtrDomainName $PtrDomainName
            }
            'SRV' {
                Add-DnsServerResourceRecord @commonParams -Srv -DomainName $DomainName -Priority $Priority -Weight $Weight -Port $Port
            }
            'TXT' {
                Add-DnsServerResourceRecord @commonParams -Txt -DescriptiveText $TextRecord
            }
            default {
                ## Handle unexpected record types by throwing an error.
                throw "Unrecognized input: [$_]"
            }
        }
    }
} catch [Microsoft.Management.Infrastructure.CimException] {
    ## Provide a clear error message if something goes wrong during the record addition.
    throw "An error occurred while adding the DNS record. Error: $($_.Exception.Message)"
}