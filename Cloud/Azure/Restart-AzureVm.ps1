<#
.SYNOPSIS
    Restarts a specified Azure virtual machine if it is currently running.

.DESCRIPTION
    This script checks the status of a specified Azure virtual machine and restarts it if it is running.
    It requires the virtual machine name and the resource group name as inputs. The script also ensures
    that the user is logged into Azure, the resource group exists, and the virtual machine exists within
    the specified resource group.

.PARAMETER VmName
    Specifies the name of the virtual machine to be restarted. This parameter is mandatory.

.PARAMETER ResourceGroupName
    Specifies the name of the resource group in which the virtual machine resides. This parameter is mandatory.

.EXAMPLE
    PS> .\Restart-AzureVM.ps1 -VmName "MyVM" -ResourceGroupName "MyResourceGroup"

    This command restarts the virtual machine named "MyVM" in the "MyResourceGroup" if it is currently running.

.INPUTS
    None. Parameters must be provided when the script is called.

.OUTPUTS
    None directly from the script. Actions performed are related to Azure virtual machine operations.

.NOTES
    The script requires that the user be logged into Azure. The user must have appropriate permissions
    to restart the virtual machine within the specified resource group.

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.compute/restart-azvm

#>

#requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.15.1' }
#requires -Modules @{ ModuleName='Az.Resources'; ModuleVersion='6.15.0' }
#requires -Modules @{ ModuleName='Az.Compute'; ModuleVersion='7.1.1' }

[CmdletBinding()]
param(
    [Parameter(Mandatory)] 
    [string]$VmName,

    [Parameter(Mandatory)]
    [string]$ResourceGroupName
)

$ErrorActionPreference = 'Stop'

#region functions

#endregion

#region Prerequisites
# Check if the user is logged in to Azure
$context = Get-AzContext
if (-not $context) {
    throw "You are not logged in to Azure. Please run 'Connect-AzAccount' and try again."
}

# Check if the resource group exists
try {
    $rg = Get-AzResourceGroup -Name $ResourceGroupName
} catch {
    if ($_.Exception.Message -like "*does not exist*") {
        throw "The resource group '$ResourceGroupName' does not exist in the current subscription [$($context.Subscription.Name)]."
    } else {
        throw $_
    }
}

# Check if the VM exists in the resource group
try {
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status
} catch {
    if ($_.Exception.Message -match 'ReasonPhrase: Not Found') {
        throw "The virtual machine '$VmName' does not exist in the resource group '$ResourceGroupName'."
    } else {
        throw $_
    }
}

#endregion

# Check the current power state of the VM
$powerState = ($vm.Statuses | Where-Object Code -Like "PowerState/*").DisplayStatus

if ($powerState -ne 'VM running') {
    throw "The VM [$VmName] is not running. A VM must be started to be restarted."
} else {
    $null = $vm | Restart-AzVM -Force
}

