# DVLS Scripted Installation For Linux

You can use `install-dvls.ps1` or `install-dvls.sh` at your convenience.
`install-dvls.sh` will install PowerShell for you if it is not yet installed.
It will then proceed to run `install-dvls.ps1` for you, downloading it from this repository if necessary.

This script assumes an accessible Microsoft SQL Server, either located on the same system or externally available.

You have two ways to run the script, either interactive with prompts, or non-interactive:

- Interactive:

  ```pwsh
  ./install-dvls.ps1
  ```

  ```bash
  ./install-dvls.sh
  ```

- Non-interactive:

  ```pwsh
  ./install-dvls.ps1 -DVLSHostName "MYHOST" -DVLSAdminEmail "admin@replaceme.com" -DatabaseHost "MYDBHOST" -DatabaseUsername "MYDBUSERNAME" -DatabasePassword "MYSTRONGPASSWORD" -GenerateSelfSignedCertificate -Confirm:$False
  ```

  ```bash
  ./install-dvls.sh --dvls-hostname "MYHOST" --dvls-admin-email "admin@replaceme.com" --database-host "MYDBHOST" --database-username "MYDBUSERNAME" --database-password "MYSTRONGPASSWORD" --generate-self-signed-certificate --no-confirm
  ```

## Quick Start One-liner

Copy and run this bash one-liner in a terminal:

```bash
curl --proto '=https' --tlsv1.2 -sSf "https://raw.githubusercontent.com/Devolutions/ScriptLibrary/refs/heads/main/DVLSForLinux/install-dvls.sh" | bash
```
