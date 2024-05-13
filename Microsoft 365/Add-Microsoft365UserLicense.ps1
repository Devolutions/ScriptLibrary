#requires -Version 7.0 -Module @{ ModuleName='Microsoft.Graph'; ModuleVersion='2.19.0' }

<#
.SYNOPSIS
Assigns a Microsoft 365 license to a specified user using Microsoft Graph API.

.DESCRIPTION
This script assigns a specific Microsoft 365 license to a user identified by their user ID. It performs necessary checks
to ensure that the SKU part number is available and the user meets the prerequisites (like having a usage location
assigned) before assigning the license.

.PARAMETER UserId
Specifies the User ID of the Microsoft 365 user to whom the license will be assigned. This parameter is mandatory.

.PARAMETER SkuPartNumber
Specifies the SKU part number of the Microsoft 365 license to assign. This parameter is mandatory.

.EXAMPLE
PS> .\Add-EntraIdUserLicense.ps1 -UserId "user@example.com" -SkuPartNumber "ENTERPRISEPACK"

This command assigns the ENTERPRISEPACK (Office 365 E3) license to the user with the user ID "user@example.com".

.NOTES
Ensure that the Microsoft Graph PowerShell module is installed and you are authenticated using Connect-MgGraph before
running this script. For detailed usage of Connect-MgGraph, refer to the official documentation:
https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/connect-mggraph

.LINK
Get-MgUser - https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.users/get-mguser
Set-MgUserLicense - https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.users/set-mguserlicense
Get-MgSubscribedSku - https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.subscriptions/get-mgsubscribedsku

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$UserId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SkuPartNumber
)

$ErrorActionPreference = 'Stop'

#region Functions
function Test-MgGraphAuthenticated {
    [CmdletBinding()]
    param ()

    [bool](Get-MgContext)
}

function Test-UsageLocationAssigned($mgUser) {
    [bool]$mgUser.UsageLocation
}

#endregion

#region Prereq checks
if (-not (Test-MgGraphAuthenticated)) {
    throw 'You are not authenticated to Microsoft Graph. Please run "Connect-MgGraph -Scopes User.ReadWrite.All, Organization.Read.All" and provide an account with approppriate rights to add the license requested.'
}

## Check if the SKU part number is available in the organization
[array]$availableSkus = Get-MgSubscribedSku -Search "`"SkuPartNumber:$SkuPartNumber`"" -All | Where-Object { $_.SkuPartNumber -eq $SkuPartNumber }
switch ($availableSkus.Count) {
    0 {
        throw "SKU part number [$SkuPartNumber] is not available in the organization. Please check the SKU part number and try again."
    }
    { $_ -gt 1 } {
        throw "Multiple SKUs with part number [$SkuPartNumber] are available in the organization ($($availableSkus.SkuPartNumber -join ',')). Please check the SKU part number and try again."
    }
}

if ($availableSkus.PrepaidUnits.Enabled -le $availableSkus.ConsumedUnits) {
    throw "No available units for SKU part number [$SkuPartNumber]. Cannot assign license to user."
}
#endregion

$mgUser = Get-MgUser -UserId $UserId -Select AssignedLicenses, UsageLocation

if (-not (Test-UsageLocationAssigned($mgUser))) {
    throw "User $UserId does not have a usage location assigned. Please assign a usage location before adding the license."
}

Set-MgUserLicense -UserId $UserId -AddLicenses @{ SkuId = $availableSkus.Id }