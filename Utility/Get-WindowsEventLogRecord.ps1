# Requires -Version 7.0

<#
.SYNOPSIS
    Retrieves events from the event log based on specified criteria.

.DESCRIPTION
    This script uses the Get-WinEvent cmdlet to query and retrieve events from the event log. It supports filtering by log name, 
    event levels, event IDs, sources, and time ranges. The script builds an XPath query string based on the provided parameters 
    to fetch the matching events.

.PARAMETER LogName
    Specifies the name of the event log to query.

.PARAMETER Level
    Specifies the level(s) of the events to retrieve. Valid values are 'Error', 'Warning', 'Information', 'Critical', and 'Verbose'.

.PARAMETER EventID
    Specifies the event ID(s) of the events to retrieve.

.PARAMETER Source
    Specifies the source(s) of the events to retrieve.

.PARAMETER StartTime
    Specifies the start time for the events to retrieve. Only events created on or after this time are retrieved.

.PARAMETER EndTime
    Specifies the end time for the events to retrieve. Only events created on or before this time are retrieved.

.PARAMETER MaxEvents
    Specifies the maximum number of events to retrieve.

.NOTES
    Requires PowerShell version 7.0 or later.
    For more information on Get-WinEvent, visit: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent

.EXAMPLE
    PS> .\Get-WindowsEventLogRecord.ps1 -LogName 'Application' -Level 'Error', 'Warning' -StartTime (Get-Date).AddDays(-1)
    
    This example retrieves error and warning events from the 'Application' log that were created in the last day.

.EXAMPLE
    PS> .\Get-WindowsEventLogRecord.ps1 -LogName 'System' -EventID 1000, 2000 -Source 'Microsoft-Windows-Winlogon'
    
    This example retrieves events with IDs 1000 and 2000 from the 'System' log, where the source is 'Microsoft-Windows-Winlogon'.

.EXAMPLE
    PS> .\Get-WindowsEventLogRecord.ps1 -LogName 'Security' -Level 'Information' -MaxEvents 50
    
    This example retrieves the top 50 informational events from the 'Security' log.
#>


[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$LogName,

    [Parameter()]
    [ValidateSet("Error", "Warning", "Information", "Critical", "Verbose")]
    [string[]]$Level,

    [Parameter()]
    [int[]]$EventID,

    [Parameter()]
    [string[]]$Source,

    [Parameter()]
    [datetime]$StartTime,

    [Parameter()]
    [datetime]$EndTime,

    [Parameter()]
    [int]$MaxEvents
)

$params = @{}

if ($PSBoundParameters.ContainsKey('LogName')) {
    $params.LogName = $LogName
}

$xpathQuery = "*[System["
$conditions = @()
if ($EventID) { $conditions += "EventID=" + ($EventID -join ' or EventID=') }
if ($Level) {
    $levelMapping = @{
        'Critical'    = 1
        'Error'       = 2
        'Warning'     = 3
        'Information' = 4
        'Verbose'     = 5
    }
    $levelConditions = $Level | ForEach-Object { "Level=$($levelMapping[$_])" }
    $conditions += "(" + ($levelConditions -join ' or ') + ")"
}

if ($StartTime) {
    $conditions += "TimeCreated[@SystemTime>='$($StartTime.ToString("s"))']"
}
if ($EndTime) {
    $conditions += "TimeCreated[@SystemTime<='$($EndTime.ToString("s"))']"
}

if ($Source) {
    $conditions += "(Provider[@Name='" + ($Source -join "'] or Provider[@Name='") + "'])"
}

if ($conditions.Count -gt 0) {
    $xpathQuery += $conditions -join ' and '
}
$xpathQuery += "]]"

# Validate that at least one filtering parameter is provided
if ($xpathQuery -eq "*[System[]]" -and -not $LogName) {
    throw "You must specify at least one filtering parameter (LogName, EventID, Level, Source, User, Message, StartTime, or EndTime)."
}

$params.FilterXPath = $xpathQuery

try {
    Get-WinEvent @params | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, UserId, MachineName, LogName, Message
} catch {
    Write-Error "An error occurred while retrieving events: $($_.Exception.Message)"
}

