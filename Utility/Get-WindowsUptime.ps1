<#
.SYNOPSIS
    Retrieves the system uptime.

.DESCRIPTION
    This script calculates the duration the system has been up since the last boot. It uses CIM (Common Information Model) to query
    the Win32_OperatingSystem class and obtain the last boot-up time. Then, it calculates the difference between the current date and
    the last boot-up time to determine the uptime duration.

.EXAMPLE
    PS> .\Get-WindowsUptime.ps1

    Retrieves and displays the system uptime.
#>

[CmdletBinding()]
param ()

$uptime = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime

# Calculate the uptime duration
(Get-Date) - $uptime