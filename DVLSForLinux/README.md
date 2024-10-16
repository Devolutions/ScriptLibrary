# DVLS Scripted Installation For Linux

You can use `install-dvls.ps1` or `install-dvls.sh` at your convenience. `install-dvls.sh` will install PowerShell for you if it is not yet installed. It will then proceed to run `install-dvls.ps1` for you, downloading it from this repository if necessary.

This script assumes an accessible Microsoft SQL Server, either located on the same system or externally available. In addition, at this time only SQL authentication is supported.

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

## Non-Interactive Install Parameters

**Bash**

| Parameter                                | Description                                          |
| ---------------------------------------- | ---------------------------------------------------- |
| `--dvls-hostname`                        | Specify the DVLS host name                           |
| `--dvls-admin-email`                     | Specify the DVLS admin email                         |
| `--database-host`                        | Specify the database host (defaults to `dvls`)       |
| `--database-username`                    | Specify the database username                        |
| `--database-password`                    | Specify the database password                        |
| `--database-name`                        | Specify the database name                            |
| `--zip-file`                             | Specify a zip file for the DVLS installation file    |
| `--help`                                 | Show a help message and exit                         |
| `--no-confirm`                           | Do not confirm the action before proceeding          |
| `--database-encrypted-connection`        | Enable encrypted connection to the database          |
| `--no-database-encrypted-connection`     | Disable encrypted connection to the database         |
| `--database-trust-server-certificate`    | Trust the database server certificate                |
| `--no-database-trust-server-certificate` | Do not trust the database server certificate         |
| `--no-create-database`                   | Do not create the database even if it does not exist |
| `--generate-self-signed-certificate`     | Generate a self-signed certificate                   |
| `--no-generate-self-signed-certificate`  | Do not generate a self-signed certificate            |
| `--disable-telemetry`                    | Disable telemetry                                    |
| `--keep-installation-file`               | Keep the installation file after extraction          |
| `--no-keep-installation-file`            | Delete the installation file after extraction        |

**PowerShell**

| Parameter                         | Description                                                                |
| --------------------------------- | -------------------------------------------------------------------------- |
| `-DVLSHostName`                   | Specify the DVLS host name                                                 |
| `-DVLSAdminEmail`                 | Specify the DVLS admin email                                               |
| `-DatabaseHost`                   | Specify the database host (defaults to `dvls`)                             |
| `-DatabaseUsername`               | Specify the database username                                              |
| `-DatabasePassword`               | Specify the database password                                              |
| `-DatabaseName`                   | Specify the database name                                                  |
| `-CreateDatabase`                 | Do not create the database even if it does not exist (defaults to `$True`) |
| `-EnableTelemetry`                | Enable or disable telemetry (defaults to `$True`)                          |
| `-Confirm`                        | Confirm the action before proceeding (defaults to `$True`)                 |
| `-DatabaseEncryptedConnection`    | Enable or disable encrypted connection to the database                     |
| `-DatabaseTrustServerCertificate` | Trust the database server certificate                                      |
| `-GenerateSelfSignedCertificate`  | Generate a self-signed certificate                                         |
| `-ZipFile`                        | Specify a zip file for the DVLS installation file                          |
| `-KeepInstallationFile`           | Specify whether the installation file should be removed after extraction   |
