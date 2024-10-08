#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

show_usage() {
  echo "Usage: $0 [OPTIONS/FLAGS]"
  echo
  echo "Options:"
  echo "  --dvls-hostname <DVLSHostName>           Specify the DVLS host name"
  echo "  --dvls-admin-email <DVLSAdminEmail>      Specify the DVLS admin email"
  echo "  --database-host <DatabaseHost>           Specify the database host"
  echo "  --database-username <DatabaseUsername>   Specify the database username"
  echo "  --database-password <DatabasePassword>   Specify the database password"
  echo
  echo "Flags:"
  echo "  -h, --help                               Show this help message and exit"
  echo "  -y, --no-confirm                         Do not confirm the action before proceeding"
  echo "  --database-encrypted-connection          Enable or disable encrypted connection to the database"
  echo "  --database-trust-server-certificate      Trust the database server certificate"
  echo "  --no-create-database                     Do not create the database even if it does not exist"
  echo "  --generate-self-signed-certificate       Generate a self-signed certificate"
  echo "  --disable-telemetry                      Disable telemetry"
  echo
  echo "Example:"
  echo "  $0 --dvls-hostname mydvls --dvls-admin-email admin@example.com --database-host localhost --database-username sa --database-password pass --disable-telemetry"
  exit 1
}

VALID_ARGS=$(getopt --options hy --longoptions help,dvls-hostname:,dvls-admin-email:,database-host:,database-username:,database-password:,database-encrypted-connection,database-trust-server-certificate,no-create-database,generate-self-signed-certificate,disable-telemetry,no-confirm -- "$@")

if [[ $? -ne 0 ]]; then
    exit 1;
fi

eval set -- "$VALID_ARGS"

args=()

DATABASE_ENCRYPTED_CONNECTION=false
DATABASE_TRUST_SERVER_CERTIFICATE=false
CREATE_DATABASE=true
GENERATE_SELF_SIGNED_CERTIFICATE=false
ENABLE_TELEMETRY=true
CONFIRM=true

while [ : ]; do
  case "$1" in
    -h | --help)
      show_usage
      ;;
    --dvls-hostname)
      args+=("-DVLSHostName:$2")
      shift 2
      ;;
    --dvls-admin-email)
      args+=("-DVLSAdminEmail:$2")
      shift 2
      ;;
    --database-host)
      args+=("-DatabaseHost:$2")
      shift 2
      ;;
    --database-username)
      args+=("-DatabaseUsername:$2")
      shift 2
      ;;
    --database-password)
      args+=("-DatabasePassword:$2")
      shift 2
      ;;
    --database-encrypted-connection)
      DATABASE_ENCRYPTED_CONNECTION=true
      shift
      ;;
    --database-trust-server-certificate)
      DATABASE_TRUST_SERVER_CERTIFICATE=true
      shift
      ;;
    --no-create-database)
      CREATE_DATABASE=false
      shift
      ;;
    --generate-self-signed-certificate)
      GENERATE_SELF_SIGNED_CERTIFICATE=true
      shift
      ;;
    --disable-telemetry)
      ENABLE_TELEMETRY=false
      shift
      ;;
    -y | --no-confirm)
      CONFIRM=false
      shift
      ;;
    --)
      shift; 
      break 
      ;;
  esac
done

args+=("-DatabaseEncryptedConnection:$DATABASE_ENCRYPTED_CONNECTION" "-DatabaseTrustServerCertificate:$DATABASE_TRUST_SERVER_CERTIFICATE" "-CreateDatabase:$CREATE_DATABASE" "-GenerateSelfSignedCertificate:$GENERATE_SELF_SIGNED_CERTIFICATE" "-EnableTelemetry:$ENABLE_TELEMETRY" "-Confirm:$CONFIRM")

if command -v pwsh 2>&1 >/dev/null; then
  PWSH_COMMAND="pwsh"
elif command -v pwsh-preview 2>&1 >/dev/null; then
  PWSH_COMMAND="pwsh-preview"
else
  echo "Installing PowerShell..."
  sudo apt-get update
  sudo apt-get install -y wget apt-transport-https software-properties-common
  source /etc/os-release
  wget -q https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  rm packages-microsoft-prod.deb
  sudo apt-get update
  sudo apt-get install -y powershell
  PWSH_COMMAND="pwsh"
fi

echo "Detected PowerShell executable: '$PWSH_COMMAND'"

if ! command -v curl 2>&1 >/dev/null; then
  echo "Installing curl..."
  sudo apt-get update
  sudo apt-get install -y curl
fi

# Find the path of the directory containing this script.
SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# The name of the PowerShell script for installating DVLS as found in the GitHub reposity.
PWSH_SCRIPT_NAME="install-dvls.ps1"

if test -f "$SCRIPT_DIR/$PWSH_SCRIPT_NAME"; then
  PWSH_SCRIPT_PATH="$SCRIPT_DIR/$PWSH_SCRIPT_NAME"
else
  PWSH_SCRIPT_PATH="/tmp/DevolutionsScriptLibrary-$PWSH_SCRIPT_NAME" # Prefix to avoid conflicts as much as possible.
  PWSH_SCRIPT_URL="https://raw.githubusercontent.com/Devolutions/ScriptLibrary/refs/heads/main/DVLSForLinux/$PWSH_SCRIPT_NAME"
  echo "Downloading $PWSH_SCRIPT_NAME from $PWSH_SCRIPT_URL"
  curl --fail "$PWSH_SCRIPT_URL" -o "$PWSH_SCRIPT_PATH"
fi

args=("-File" $PWSH_SCRIPT_PATH ${args[@]})

echo "Run $PWSH_SCRIPT_NAME at $PWSH_SCRIPT_PATH"
echo ">> $PWSH_COMMAND ${args[@]}"

"$PWSH_COMMAND" "${args[@]}"
