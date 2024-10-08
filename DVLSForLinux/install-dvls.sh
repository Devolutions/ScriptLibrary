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
  echo
  echo "  --database-encrypted-connection          Enable encrypted connection to the database"
  echo "  --no-database-encrypted-connection       Disable encrypted connection to the database"
  echo
  echo "  --database-trust-server-certificate      Trust the database server certificate"
  echo "  --no-database-trust-server-certificate   Do not trust the database server certificate"
  echo
  echo "  --no-create-database                     Do not create the database even if it does not exist"
  echo
  echo "  --generate-self-signed-certificate       Generate a self-signed certificate"
  echo "  --no-generate-self-signed-certificate    Do not generate a self-signed certificate"
  echo
  echo "  --disable-telemetry                      Disable telemetry"
  echo
  echo "Example:"
  echo "  $0 --dvls-hostname mydvls --dvls-admin-email admin@example.com --database-host localhost --database-username sa --database-password pass --disable-telemetry"
  exit 1
}

VALID_ARGS=$(getopt --options hy --longoptions help,dvls-hostname:,dvls-admin-email:,database-host:,database-username:,database-password:,database-encrypted-connection,no-database-encrypted-connection,database-trust-server-certificate,no-database-trust-server-certificate,no-create-database,generate-self-signed-certificate,no-generate-self-signed-certificate,disable-telemetry,no-confirm -- "$@")

if [[ $? -ne 0 ]]; then
    exit 1;
fi

eval set -- "$VALID_ARGS"

args=()

CREATE_DATABASE='$True'
ENABLE_TELEMETRY='$True'
CONFIRM='$True'

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
      DATABASE_ENCRYPTED_CONNECTION='$True'
      shift
      ;;
    --no-database-encrypted-connection)
      DATABASE_ENCRYPTED_CONNECTION='$False'
      shift
      ;;
    --database-trust-server-certificate)
      DATABASE_TRUST_SERVER_CERTIFICATE='$True'
      shift
      ;;
    --no-database-trust-server-certificate)
      DATABASE_TRUST_SERVER_CERTIFICATE='$False'
      shift
      ;;
    --no-create-database)
      CREATE_DATABASE='$False'
      shift
      ;;
    --generate-self-signed-certificate)
      GENERATE_SELF_SIGNED_CERTIFICATE='$True'
      shift
      ;;
    --no-generate-self-signed-certificate)
      GENERATE_SELF_SIGNED_CERTIFICATE='$False'
      shift
      ;;
    --disable-telemetry)
      ENABLE_TELEMETRY='$False'
      shift
      ;;
    -y | --no-confirm)
      CONFIRM='$False'
      shift
      ;;
    --)
      shift; 
      break 
      ;;
  esac
done

args+=("-CreateDatabase:$CREATE_DATABASE" "-EnableTelemetry:$ENABLE_TELEMETRY" "-Confirm:$CONFIRM")

if [[ -n "${DATABASE_ENCRYPTED_CONNECTION+x}" ]]; then
  args+=("-DatabaseEncryptedConnection:$DATABASE_ENCRYPTED_CONNECTION")
fi

if [[ -n "${DATABASE_TRUST_SERVER_CERTIFICATE+x}" ]]; then
  args+=("-DatabaseTrustServerCertificate:$DATABASE_TRUST_SERVER_CERTIFICATE")
fi

if [[ -n "${GENERATE_SELF_SIGNED_CERTIFICATE+x}" ]]; then
  args+=("-GenerateSelfSignedCertificate:$GENERATE_SELF_SIGNED_CERTIFICATE")
fi

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
