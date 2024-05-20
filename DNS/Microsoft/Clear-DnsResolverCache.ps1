#requires -Version 7
<#
    .SYNOPSIS
        Clears the DNS resolver cache on a local Windows system

    .EXAMPLE
        PS> .\Clear-DnsResolverCache.ps1

    .NOTES
        Built: 05/06/24
        Tested with:
        - PowerShell v7.4.1
        - Windows 22 21H2
#>
[CmdletBinding()]
param ()

$ErrorActionPreference = 'Stop'

#region Function definitions
function isLocalAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
#endregion

#region Prereq check
if (!(isLocalAdmin)) {
    throw 'This script must be run as an administrator.'
}
#endregion

Clear-DnsClientCache