# Devolutions Server Scripted Installation For Linux (Beta)

Starting with the Devolutions Server release 2024.3.2.0, Devolutions Server is now available for Linux as a beta. Using Microsoft Kestrel as the built-in web server and Microsoft PowerShell 7 for command-line installation, there is no need for the GUI installation through Devolutions Console.

> [!WARNING]
> Devolutions Server for Linux is currently only in beta, and not yet suitable for production use.

## Prerequisites

- **Docker** - Currently tested with the Docker engine on Windows through WSL2, but nothing specific to that environment is used.

## Quick Start
> [!NOTE]  
> The first time that you launch the containers it may take several minutes to pull the necessary images and build the containers.

1. Create a directory containing the repository files, `docker-compose.yml` and `Dockerfile`.
1. With the Docker engine running, launch a terminal in the DVLS for Linux Docker directory, and run the command: `docker-compose up -d`.
1. Access the DVLS for Linux instance at either `https://127.0.0.1:5000` or `https://localhost:5000`.

### Troublshooting Tips
- To remove all volumes and rebuild the containers in the event of an issue, run the following:
    - `docker-compose down -v; docker-compose build --no-cache; docker-compose up -d --force-recreate`
- To troubleshoot issues from within the running DVLS Docker container, run the following to open up a command-line:
    - `docker exec -it dvls`
- To re-run the `init.ps1` onetime script, once within the DVLS Docker container, run the following:
    - `s6-rc -a change init-dvls`
- To start and stop the DVLS for Linux Devolutions.Server process, run the following respectively:
    - `s6-svc -u /var/run/s6-rc/servicedirs/svc-dvls`
    - `s6-svc -d /var/run/s6-rc/servicedirs/svc-dvls`

## Docker Options
To modify any of the following, add the parameter and the corresponding value to the `dvls.environment` section of the `docker-compose.yml` file.

> [!WARNING]
> If you choose not to generate an SSL certificate, `GENERATE_SELFSIGNEDCERTIFICATE` set to `false`, then you will need to modify the healthcheck.
> Set `dvls.healthcheck.test` to `curl -f http://127.0.0.1:5000`
> If you modify the MSSQL `sa` password, make sure to modify the password within the MSSQL healthcheck.
> Modify `mssql.healthcheck.test` to use the new password.

| Parameter                                | Description                                                                            |
| ---------------------------------------- | -------------------------------------------------------------------------------------- |
| `DVLS_HOSTNAME`                          | Set responding DVLS hostname (defaults to `127.0.0.1`, `localhost`, `IP of container`) |
| `DVLS_ADMIN_EMAIL`                       | Set the associated DVLS admin email (defaults to `admin@replaceme.com`)                |
| `DVLS_ADMIN_USERNAME`                    | Set the DVLS admin username (defaults to `dvls-admin`)                                 |
| `DVLS_ADMIN_PASSWORD`                    | Set the DVLS admin password (defaults to `dvls-admin`)                                 |
| `ENABLE_TELEMETRY`                       | Whether to send anonymized usage telemetry (defaults to `true`)                        | 
| `GENERATE_SELFSIGNEDCERTIFICATE`         | Whether to generate a selfsigned SSL certificate (defaults to `true`)                  |
| `S6_OVERLAY_VERSION`                     | Set the s6-overlay version (defaults to `3.2.0.2`)                                     |
| `POWERSHELL_VERSION`                     | Set the installed PowerShell 7 version (defaults to `7.4.6`)                           |
| `DEVOLUTIONS_MODULE_VERSION`             | Set the installed Devolutions.PowerShell module version (defaults to `2024.3.5`)       |
| `DVLS_VERSION`                           | Set the installed DVLS for Linxu version, such as `2024.3.8` (defaults to `latest`)    |
| `DVLS_PATH`                              | Set the DVLS installation path (defaults to `/opt/devolutions/dvls`)                   |

## FAQ

- **Why not Alpine for the DVLS container?**
    - Currently Alpine uses musl instead of glibc and DVLS does not currently work under that environment.
- **Why the extra dvls-healthcheck container?**
    - To ensure that the dvls container is "healthy" before opening. A separate container that depended on the DVLS container healthcheck to complete is require, otherwise, the container starts, but does not wait to show healthy.
- **Why do the healthchecks not include the database password variables?**
    - Unfortunately, I was unable to find a way to include the YAML aliases within to include a variable.
- **How much space does all of this take up?**
    - According to Docker, about 3.3 gb between all of the images.