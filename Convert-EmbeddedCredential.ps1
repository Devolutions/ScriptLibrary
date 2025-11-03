#Requires -Modules Devolutions.PowerShell

<#
.SYNOPSIS
    Converts embedded credential entries to proper credential entries in specified Remote Desktop Manager (RDM) vaults.

.DESCRIPTION
    This script processes specified RDM vaults and converts embedded credential entries to proper credential entries. 
    It sets the current repository to each vault, retrieves embedded credential entries, and updates their username and password 
    if they exist. The script supports confirmation prompts and impact levels for actions taken.

.PARAMETER VaultName
    The name of the RDM vault to process. If not specified, all available vaults will be processed.

.EXAMPLE
    PS> .\Convert-EmbeddedCredential.ps1 -VaultName 'MyVault' -InformationAction Continue
    
    This example processes the 'MyVault' vault, converts any embedded credential entries to proper credential entries, 
    and refreshes the entries list.

.EXAMPLE
    PS> .\Convert-EmbeddedCredential.ps1
    
    This example processes all available vaults, converts any embedded credential entries to proper credential entries, 
    and refreshes the entries list.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$VaultName
)

$ErrorActionPreference = 'Stop'

$getRdmVaultParams = @{}
if ($PSBoundParameters.ContainsKey('VaultName')) {
    $getRdmVaultParams['Name'] = $VaultName
}
[array]$vaults = Get-RDMVault @getRdmVaultParams

$embeddedCredentialCount = 0
foreach ($vault in $vaults) {
    Set-RDMCurrentRepository -Repository $vault
    $vaultname = $vault.Name
 
    if (-not ($embeddedCredentialEntries = Get-RDMEntry | Where-Object { $_.CredentialConnectionID -eq '0C0C8D0A-CE6D-40E7-84D0-343D488E2DBA' })) {
        Write-Information -Message "Vault: $vaultname | No embedded credential entries found"
    } else {
        Write-Information -Message "Vault: $vaultname | Found $($embeddedCredentialEntries.Count) embedded credential entries"
        foreach ($entry in $embeddedCredentialEntries) {
            $entry.CredentialConnectionID = ''

            if ($username = Get-RDMSessionUserName $entry) {
                Write-Information -Message "Vault: $vaultname | Entry: $($entry.Name) : Updating username..."
                Set-RDMEntryUsername -InputObject $entry -UserName $username
            }

            if ($password = Get-RDMSessionPassword $entry) {
                Write-Information -Message "Vault: $vaultname | Entry: $($entry.Name) : Updating password..."
                Set-RDMEntryPassword -InputObject $entry -Password $password
            }
            if ($username -or $password) {
                $embeddedCredentialCount++
                if ($PSCmdlet.ShouldProcess("Vault: $vaultname | Entry: $($entry.Name)", "Update embedded credential to username: $username, password: $password")) {
                    Set-RDMEntry -InputObject $entry
                }
            }
        }
    }
}
if ($embeddedCredentialCount -gt 0) {
    Write-Information -Message "Converted $embeddedCredentialCount embedded credential entries in $($vaults.Count) vaults"

    ## Refresh the entries list
    Update-RDMEntries
}