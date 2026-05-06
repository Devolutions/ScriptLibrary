# SecretManagement.DevolutionsServer

Read-only Microsoft.PowerShell.SecretManagement extension vault for Devolutions Server (DVLS), intended primarily for PowerShell Universal (PSU) credential retrieval.

This provider returns DVLS Credential entries as `PSCredential` objects. It does not create, update, delete, or modify DVLS entries.

## PowerShell Universal Quick Start

### 1. Install Into Universal Modules

Install the module into the PowerShell Universal repository module folder rather than a user profile or broad Windows module path. The default repository is `%ProgramData%\UniversalAutomation\Repository`, and PSU loads modules from `Repository\Modules`.

Use this versioned layout:

```text
%ProgramData%\UniversalAutomation\Repository\
  Modules\
    SecretManagement.DevolutionsServer\
      1.0.0\
        SecretManagement.DevolutionsServer.psd1
        SecretManagement.DevolutionsServer.Extension\
          SecretManagement.DevolutionsServer.Extension.psd1
          SecretManagement.DevolutionsServer.Extension.psm1
```

Install from this repository:

```powershell
$repoModules = Join-Path $env:ProgramData 'UniversalAutomation\Repository\Modules'
$moduleRoot = Join-Path $repoModules 'SecretManagement.DevolutionsServer\1.0.0'

New-Item -ItemType Directory -Force -Path $moduleRoot | Out-Null
Copy-Item .\SecretManagement.DevolutionsServer.psd1 -Destination $moduleRoot -Force
Copy-Item .\SecretManagement.DevolutionsServer.Extension -Destination $moduleRoot -Recurse -Force
```

This assumes `Microsoft.PowerShell.SecretManagement` is already available to the PSU PowerShell environment. If PSU cannot import SecretManagement, install it separately using your normal module-management process.

After copying the module, restart the PowerShell Universal service or reload modules from Platform > Modules. The module should appear in Universal Modules because it is installed in the repository module path.

### 2. Register The Vault At Startup

Use PSU's startup vault file:

```text
%ProgramData%\UniversalAutomation\Repository\.universal\vaults.ps1
```

PSU runs `.universal\vaults.ps1` during system startup before variables are registered and vaults are located. Keep the registration idempotent so startup can run repeatedly.

Example `.universal\vaults.ps1` using inline credentials:

```powershell
Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
Import-Module SecretManagement.DevolutionsServer -RequiredVersion 1.0.0 -ErrorAction Stop

$vaultName = 'DVLS'
$existingVault = Get-SecretVault -Name $vaultName -ErrorAction SilentlyContinue

if ($existingVault) {
    Unregister-SecretVault -Name $vaultName
}

Register-SecretVault `
    -Name $vaultName `
    -ModuleName 'SecretManagement.DevolutionsServer' `
    -VaultParameters @{
        ServerUrl = 'https://dvls.example.com'
        AppKey    = 'paste-application-key-here'
        AppSecret = 'paste-application-secret-here'
        VaultId   = '00000000-0000-0000-0000-000000000000'
    } `
    -AllowClobber
```

Inline credentials are the simplest bootstrap option. Treat `.universal\vaults.ps1` as sensitive:

- Do not Git-sync `.universal\vaults.ps1` unless the remote repository is approved to hold secrets.
- Restrict NTFS permissions on `.universal\vaults.ps1` and the repository folder to the PSU service account and administrators.
- Use a dedicated DVLS application key with access only to the required vault.
- Rotate the DVLS application secret when staff or repository access changes.

The DVLS identity behind the application key must also have entry-level permission to retrieve credential values. Listing a Credential entry is not enough. For each credential that PSU needs, grant the identity:

- `View`
- `View password`
- `View sensitive information`, when the credential or endpoint requires sensitive fields beyond the password

In DVLS, check the Credential entry's Security > Permissions page. `Get-SecretInfo` can succeed when only metadata is visible, while `Get-Secret` can still fail if `View password` is denied.

### 3. Restart PSU

Restart the PowerShell Universal service so PSU reloads repository modules and runs `.universal\vaults.ps1`.

### 4. Validate From PSU

Create a PSU test script so validation runs inside the same environment PSU will use.

In the PSU admin console:

1. Go to Automation > Scripts.
2. Create a new script, for example `Test-DVLSSecretVault.ps1`.
3. Select the PowerShell 7.x environment that your jobs/APIs will use.
4. Add this script body:

```powershell
Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
Import-Module SecretManagement.DevolutionsServer -RequiredVersion 1.0.0 -ErrorAction Stop

Get-Module SecretManagement.DevolutionsServer* -ListAvailable |
    Select-Object Name, Version, Path

Get-SecretVault -Name 'DVLS'
Test-SecretVault -Name 'DVLS'
Get-SecretInfo -Vault 'DVLS'
```

5. Run the script from PSU and review the job output.

Do not use the PSU integrated environment for this validation or for production scripts that need Run As credentials. Integrated environments cannot use Run As credentials, so a script assigned to that environment will not behave like a credential-backed PSU workload. Create or select a non-integrated PowerShell 7.x environment under Settings > Environments, then use that environment for the validation script and for the jobs/APIs that consume the vault.

`Test-SecretVault -Name 'DVLS'` should return `True`. `Get-SecretInfo` should list readable DVLS Credential entries.

Also validate an actual credential retrieval:

```powershell
Get-Secret -Name 'DomainAdmin' -Vault 'DVLS'
```

If `Get-SecretInfo` lists the secret but `Get-Secret` reports that the secret was not found, check the DVLS entry permissions. The application identity likely has metadata access but does not have `View password` on that Credential entry.

### 5. Use In PSU Variables

After the vault validates, use Platform > Variables > Import Secret to import existing DVLS secrets. PSU will resolve those secrets through SecretManagement when scripts, APIs, or jobs use them.

## Requirements

- PowerShell 7.0 or later.
- Microsoft.PowerShell.SecretManagement available in the PSU environment.
- A Devolutions Server URL reachable from the PSU host.
- A DVLS application key and application secret with least-privilege access to the target vault.
- DVLS Credential entries. Other entry types are ignored.
- DVLS entry permissions that allow `View password` and, when required, `View sensitive information`.

## Bootstrap Credentials

Do not use PSU secret variables for the DVLS `AppKey` and `AppSecret` that register this same vault. PSU runs `.universal\vaults.ps1` before variables are registered, so `$Secret:` values are not a reliable bootstrap source for vault registration.

Practical options, from safest to simplest:

- Use protected machine or service environment variables such as `DVLS_APP_KEY` and `DVLS_APP_SECRET`.
- Use a protected local bootstrap file outside the repository ACLed to the PSU service account.
- Register the DVLS vault once as the PSU service account and omit startup re-registration.
- Use inline credentials in `.universal\vaults.ps1` and treat that file as sensitive.

For this project, inline credentials are documented because they are operationally simple and avoid a vault-to-vault bootstrap chain.

## Vault Parameters

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `ServerUrl` | Yes | None | HTTPS DVLS base URL. Query strings and fragments are rejected. |
| `AppKey` | Yes | None | DVLS application key. |
| `AppSecret` | Yes | None | DVLS application secret. |
| `VaultId` | Recommended | None | DVLS vault ID. Required unless `AllowVaultEnumeration` is true. |
| `AllowVaultEnumeration` | No | `false` | Allows searching all accessible vaults when `VaultId` is not supplied. Prefer `VaultId` in production. |
| `RequestTimeoutSeconds` | No | `30` | REST timeout. Valid range: 1-300. |
| `PageSize` | No | `100` | Entry list page size. Valid range: 1-1000. |

## Usage

Retrieve a DVLS Credential entry:

```powershell
$credential = Get-Secret -Name 'SqlProd' -Vault 'DVLS'
$credential.UserName
```

List available credential names:

```powershell
Get-SecretInfo -Vault 'DVLS'
Get-SecretInfo -Vault 'DVLS' -Name '*Prod*'
```

Unsupported operations fail with read-only errors:

```powershell
Set-Secret -Name 'SqlProd' -Vault 'DVLS' -Secret $credential
Remove-Secret -Name 'SqlProd' -Vault 'DVLS'
```

## Local Development

Register from this repository for local testing:

```powershell
Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop

Register-SecretVault `
    -Name 'DVLS-Dev' `
    -ModuleName (Resolve-Path .\SecretManagement.DevolutionsServer.psd1).Path `
    -VaultParameters @{
        ServerUrl = 'https://dvls.example.com'
        AppKey    = 'your-application-key'
        AppSecret = 'your-application-secret'
        VaultId   = '00000000-0000-0000-0000-000000000000'
    } `
    -AllowClobber
```

## Security

- HTTPS is required.
- The module never writes app secrets, token IDs, passwords, or returned credential payloads to verbose, warning, debug, output, or error streams.
- Use `VaultId` in production to avoid broad cross-vault searches.
- Rotate DVLS application secrets regularly.
- Use least privilege: the DVLS application identity should only access the vault and entries required by PSU.
- Grant `View password` only on the specific DVLS Credential entries PSU needs.
- Treat SecretManagement vault registration data as sensitive operational configuration.

## Future Mutable Operations

This module is intentionally read-only. If `Set-Secret` or `Remove-Secret` are implemented later, treat that as a new design and security review:

- Add `SupportsShouldProcess` and tests for `-WhatIf` and `-Confirm`.
- Replace the current read-only implementations and analyzer suppressions with explicit DVLS write/delete logic.
- Document the required DVLS create, edit, delete, and password-management permissions separately from read permissions.
- Add tests for create, update, delete, API failure, partial failure, and secret-redaction behavior.
- Keep DVLS as the source of truth for audit and lifecycle policy unless the architecture is explicitly changed.

## Troubleshooting

`Test-SecretVault -Name DVLS` returns false:

- Confirm the test ran inside PSU, not only in an administrator shell.
- Confirm the PSU script uses the same PowerShell 7 environment as the workload.
- Confirm `ServerUrl` is HTTPS and reachable from the PSU host.
- Confirm the DVLS application key and secret are valid.
- Confirm the application identity can read the configured `VaultId`.

`Get-Secret` returns nothing:

- Confirm the DVLS entry is type Credential.
- Confirm the SecretManagement name exactly matches the DVLS entry name, or pass the entry GUID.
- Confirm the application identity has `View password` for the entry.
- Confirm the application identity has `View sensitive information` if the entry requires sensitive fields beyond the password.
- If `Get-SecretInfo` can see the entry but `Get-Secret` cannot retrieve it, treat that as a DVLS credential-value permission problem first.

PowerShell Universal cannot see the vault:

- Confirm `.universal\vaults.ps1` ran at service startup.
- Confirm the module appears in Universal Modules.
- Confirm `Microsoft.PowerShell.SecretManagement` is available to the PSU environment.
- Confirm the script is assigned to a non-integrated PowerShell 7.x environment from Settings > Environments when Run As credentials are required.
- Restart the PSU service after module installation or vault registration changes.

## Development

Run tests:

```powershell
Invoke-Pester -Path .\Tests\SecretManagement.DevolutionsServer.Tests.ps1 -Output Detailed
```

Validate manifests:

```powershell
Test-ModuleManifest .\SecretManagement.DevolutionsServer.psd1
Test-ModuleManifest .\SecretManagement.DevolutionsServer.Extension\SecretManagement.DevolutionsServer.Extension.psd1
```

Import from the repository:

```powershell
Import-Module .\SecretManagement.DevolutionsServer.psd1 -Force
```
