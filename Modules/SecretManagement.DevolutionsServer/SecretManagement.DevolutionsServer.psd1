# Public module manifest for SecretManagement.DevolutionsServer.
#
# PowerShell Universal and administrators import this manifest. It keeps the
# top-level module surface intentionally empty and loads the SecretManagement
# extension implementation through NestedModules.
@{
    ModuleVersion     = '1.0.0'
    GUID              = 'c875a3af-688e-4341-a328-38afa6831c81'
    Author            = 'Devolutions'
    CompanyName       = 'Devolutions'
    Copyright         = '(c) 2026 Devolutions. All rights reserved.'
    Description       = 'Read-only SecretManagement extension vault for Devolutions Server (DVLS). Retrieves DVLS Credential entries as PSCredential objects for PowerShell SecretManagement, including PowerShell Universal.'
    PowerShellVersion = '7.0'
    RequiredModules   = @('Microsoft.PowerShell.SecretManagement')

    NestedModules     = @('SecretManagement.DevolutionsServer.Extension\SecretManagement.DevolutionsServer.Extension.psd1')

    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('SecretManagement', 'DevolutionsServer', 'DVLS', 'Vault', 'Credentials')
            ReleaseNotes = 'Read-only DVLS Credential retrieval provider for Microsoft.PowerShell.SecretManagement.'
        }
    }
}
