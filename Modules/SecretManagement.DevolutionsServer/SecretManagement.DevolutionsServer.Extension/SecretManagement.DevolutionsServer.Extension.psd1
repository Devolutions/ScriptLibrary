# SecretManagement extension manifest.
#
# Microsoft.PowerShell.SecretManagement loads this nested module when the DVLS
# vault is registered. The exported function names are the contract required by
# SecretManagement extension vaults.
@{
    ModuleVersion     = '1.0.0'
    GUID              = '41a4e09c-ba9f-43bb-99ad-af48e6c1657c'
    Author            = 'Devolutions'
    CompanyName       = 'Devolutions'
    Copyright         = '(c) 2026 Devolutions. All rights reserved.'
    Description       = 'Read-only SecretManagement.DevolutionsServer extension implementation'
    PowerShellVersion = '7.0'
    RequiredModules   = @('Microsoft.PowerShell.SecretManagement')

    RootModule        = 'SecretManagement.DevolutionsServer.Extension.psm1'

    FunctionsToExport = @(
        'Get-Secret'
        'Get-SecretInfo'
        'Set-Secret'
        'Remove-Secret'
        'Test-SecretVault'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
