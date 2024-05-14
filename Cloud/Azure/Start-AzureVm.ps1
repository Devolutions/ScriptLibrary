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
    $null = $vm | Start-AzVM
}