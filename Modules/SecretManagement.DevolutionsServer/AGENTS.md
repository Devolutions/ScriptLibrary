# AGENTS.md

## Purpose

This repository contains a read-only PowerShell SecretManagement extension vault for Devolutions Server. It is primarily intended for PowerShell Universal credential retrieval.

## Architecture

- `SecretManagement.DevolutionsServer.psd1` is the parent module manifest used by SecretManagement registration.
- `SecretManagement.DevolutionsServer.Extension/SecretManagement.DevolutionsServer.Extension.psd1` is the nested extension manifest.
- `SecretManagement.DevolutionsServer.Extension/SecretManagement.DevolutionsServer.Extension.psm1` contains the consolidated implementation.
- `Tests/SecretManagement.DevolutionsServer.Tests.ps1` contains the Pester test suite.

Keep the implementation consolidated unless read-only behavior grows enough that the `.psm1` becomes difficult to audit.

## SecretManagement Constraints

The nested extension module exports the required SecretManagement functions:

- `Get-Secret`
- `Get-SecretInfo`
- `Set-Secret`
- `Remove-Secret`
- `Test-SecretVault`

`Set-Secret` and `Remove-Secret` must remain unsupported and must throw read-only errors. Do not add write behavior without a design update and tests.

## PowerShell Universal Deployment

Document PSU deployment around the repository module path:

```text
%ProgramData%\UniversalAutomation\Repository\Modules
```

Startup vault registration belongs in:

```text
%ProgramData%\UniversalAutomation\Repository\.universal\vaults.ps1
```

Do not document PSU secret variables as the bootstrap source for the DVLS `AppKey` and `AppSecret`. PSU runs `.universal\vaults.ps1` before variables are registered, so `$Secret:` values are not reliable for registering the DVLS vault itself. Inline credentials in `.universal\vaults.ps1` are allowed as the simple deployment mode, but the docs must call out ACL, Git-sync, least-privilege, and rotation precautions.

Document PSU environment selection as part of validation and production use. The PSU integrated environment cannot use Run As credentials, so validation scripts and credential-backed jobs/APIs should use a non-integrated PowerShell 7.x environment configured under Settings > Environments.

Document DVLS entry permissions as part of PSU setup. The application identity needs more than metadata visibility: `View password` is required for `Get-Secret`, and `View sensitive information` may be required depending on the credential fields. If `Get-SecretInfo` succeeds but `Get-Secret` reports a missing secret, lead troubleshooting toward DVLS entry permissions.

## Security Rules

Do not log app secrets, token IDs, passwords, SecureString contents, or raw DVLS sensitive payloads.

Do not add verbose, debug, warning, output, or error messages that include secret material.

Prefer `VaultId` in examples and production guidance. Cross-vault enumeration must remain explicit through `AllowVaultEnumeration`.

Prefer granting `View password` only on the specific DVLS Credential entries PSU needs.

## Future Mutable Operations

The provider is read-only. Do not add DVLS write/delete behavior casually. If `Set-Secret` or `Remove-Secret` become mutable later, require a design update, `SupportsShouldProcess`, `-WhatIf`/`-Confirm` tests, explicit DVLS write-permission documentation, failure-mode coverage, and a fresh security review. Remove read-only PSScriptAnalyzer suppressions when those functions begin changing state.

## Development Commands

Run the full test suite:

```powershell
Invoke-Pester -Path .\Tests\SecretManagement.DevolutionsServer.Tests.ps1 -Output Detailed
```

Validate module manifests:

```powershell
Test-ModuleManifest .\SecretManagement.DevolutionsServer.psd1
Test-ModuleManifest .\SecretManagement.DevolutionsServer.Extension\SecretManagement.DevolutionsServer.Extension.psd1
```

Import the module from the repository:

```powershell
Import-Module .\SecretManagement.DevolutionsServer.psd1 -Force
```

## Code Style

- Target PowerShell 7.0 or later. Do not add newer 7.x-only syntax without raising the manifest requirement and tests.
- Keep `Set-StrictMode -Version Latest`.
- Keep exported functions compatible with Microsoft.PowerShell.SecretManagement signatures.
- Use structured helpers for REST calls and object property access.
- Use safe, specific errors. Avoid dumping response bodies.
- Add or update Pester tests before behavior changes.

## Documentation

When behavior changes, update:

- `README.md`
- `AGENTS.md`
