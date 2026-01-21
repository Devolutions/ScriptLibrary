#Requires -Modules Devolutions.PowerShell

<#
.SYNOPSIS
    Processes specified vaults and creates virtual folders based on entry group paths.

.DESCRIPTION
    This script processes all entries within specified vaults and extracts virtual folder paths from each entry's group.
    It then checks for the existence of these virtual folders and creates them if they do not already exist.
    The script leverages the Devolutions.PowerShell module to interact with Remote Desktop Manager (RDM).

.PARAMETER VaultName
    An optional parameter to filter the entries by vault name. If not specified, all vaults will be processed.

.PARAMETER VirtualFolderName
    An optional parameter to filter the entries by virtual folder name. If not specified, all virtual folders will be processed.

.NOTES
    Requires the Devolutions.PowerShell module to be installed.

.EXAMPLE
    PS> .\ConvertTo-Folder.ps1 -VaultName "MyVault" -VirtualFolderName "MyVirtualFolder" -InformationAction Continue
    
    This example processes the entries in the vault named "MyVault", extracts virtual folder paths from entry groups,
    and creates any missing virtual folders.

.EXAMPLE
    PS> .\ConvertTo-Folder.ps1 -InformationAction Continue
    
    This example processes all entries in all vaults and creates any missing virtual folders.

#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$VaultName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$VirtualFolderName
)

$ErrorActionPreference = 'Stop'

$getRdmVaultParams = @{}
if ($PSBoundParameters.ContainsKey('VaultName')) {
    $getRdmVaultParams['Name'] = $VaultName
}
$vaults = Get-RDMVault @getRdmVaultParams

foreach ($vault in $vaults) {
    Set-RDMCurrentRepository -Repository $vault
    $vaultname = $vault.Name
    Write-Information -Message "Processing vault: $vaultname"

    $allEntries = Get-RDMEntry

    $allVirtualFolderPaths = @()
    foreach ($entry in $allEntries) {

        ## Extract the virtual folder paths
        $folderPath = $entry.Group

        $folderPath -split ';' | Select-Object -Skip 1 | ForEach-Object {
            if ($allVirtualFolderPaths -notcontains $_) {
                Write-Information -Message "Found virtual folder [$_]"
                $allVirtualFolderPaths += $_
            }
        }
    }

    # Get all folders that exist in the database
    $folders = Get-RDMSession | Where-Object { $_.ConnectionType -eq "Group" }
    $folderLookupHt = $folders | Group-Object -Property Group -AsHashTable

    ## Extract the folder names from the paths to create flat folders
    $allVirtualFolderNames = $allVirtualFolderPaths -split '\\' | Select-Object -Unique

    ## Find all virtual folder paths that do not have folders already
    $foldersToCreate = $allVirtualFolderNames | Where-Object { !$folderLookupHt.ContainsKey($_) }

    ## Create the folders
    foreach ($folder in $foldersToCreate) {
        if ($PSCmdlet.ShouldProcess("Vault: $vaultname", "Create Virtual Folder [$folder]")) {
            ## Create the new folder in current vault
            New-RDMEntry -Name $folder -Group $folder -Type Group -Set
            Write-Information "Folder for previous virtual folder [$folder] has been successfully created." 
        }
    }

}

Update-RDMUI