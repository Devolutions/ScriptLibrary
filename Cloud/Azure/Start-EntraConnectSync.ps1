#requires -Module AdSync

<#
.SYNOPSIS
    Checks if Azure AD Connect is installed and initiates a Delta synchronization cycle.

.DESCRIPTION
    This script checks for the presence of the Azure AD Connect executable in the default installation
    path and initiates a Delta synchronization cycle if the executable is found. If Azure AD Connect is
    not installed, the script throws an exception.

.PARAMETER
    None

.EXAMPLE
    PS> .\ScriptName.ps1
    This example runs the script which will check for Azure AD Connect and start a Delta sync cycle if
    it's installed.

.NOTES
    This script requires the Active Directory Sync module. It uses the ADSyncCmd PowerShell module to
    start the synchronization cycle. Ensure that the Azure AD Connect is installed in the default
    directory or modify the script to reflect the correct installation path.

.LINK
    https://docs.microsoft.com/en-us/azure/active-directory/hybrid/how-to-connect-sync-feature-scheduler
#>

[CmdletBinding()]
param ()

#region functions
function testAdConnectInstalled {
    $adConnectPath = Join-Path -Path $env:ProgramFiles -ChildPath 'Microsoft Azure AD Sync\Bin\ADSync\ADSync.exe'
    Test-Path -Path $adConnectPath -PathType Leaf
}
#endregion

if (-not (testAdConnectInstalled)) {
    throw 'Azure AD Connect is not installed on this server.'
}

Start-ADSyncSyncCycle -PolicyType Delta