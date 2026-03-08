#!/usr/bin/env bash
# ---------------------------------------
# IBM i Configuration Setup Wizard
# Creates .ibmi-config.json with AES-256 encrypted password
# Password is encrypted using a key derived from machine + user identity,
# so only the same user on the same machine can decrypt (similar to DPAPI).
# Supports multiple named environments (dev, qa, prod, etc.)
# Re-runnable: loads existing values as defaults
#
# Usage:
#   setup-ibmi.sh                    # Add/edit an environment (prompts for name)
#   setup-ibmi.sh -e dev             # Add/edit the "dev" environment
#   setup-ibmi.sh -l                 # List all configured environments
#   setup-ibmi.sh -r qa              # Remove an environment
#
# Requires: jq, openssl
# ---------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="$SCRIPT_DIR/.ibmi-config.json"

# Check for required tools
for cmd in jq openssl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd is required."
        exit 1
    fi
done

# --- Encryption helpers ---
# Derive a machine+user-specific key (analogous to Windows DPAPI)
get_encryption_key() {
    local machine_id
    if [[ "$(uname)" == "Darwin" ]]; then
        machine_id=$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformUUID/{print $4}')
    elif [[ -f /etc/machine-id ]]; then
        machine_id=$(cat /etc/machine-id)
    else
        machine_id=$(hostname)
    fi
    echo -n "${machine_id}-$(id -u)-$(whoami)" | openssl dgst -sha256 -binary | base64
}

encrypt_password() {
    local password="$1"
    local key
    key=$(get_encryption_key)
    echo -n "$password" | openssl enc -aes-256-cbc -a -A -salt -pbkdf2 -pass "pass:${key}" 2>/dev/null
}

decrypt_password() {
    local encrypted="$1"
    local key
    key=$(get_encryption_key)
    echo "$encrypted" | openssl enc -aes-256-cbc -a -A -d -salt -pbkdf2 -pass "pass:${key}" 2>/dev/null
}

# Parse arguments
ENVIRONMENT=""
LIST=false
REMOVE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--environment) ENVIRONMENT="$2"; shift 2 ;;
        -l|--list)        LIST=true; shift ;;
        -r|--remove)      REMOVE="$2"; shift 2 ;;
        *)                echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Load existing config or initialize empty structure
if [[ -f "$CONFIG_PATH" ]]; then
    ROOT_CONFIG=$(cat "$CONFIG_PATH")
else
    ROOT_CONFIG='{"DefaultEnvironment":"","Environments":{}}'
fi

# Migrate flat (pre-environment) config to new structure
if echo "$ROOT_CONFIG" | jq -e '.Environments' &>/dev/null; then
    : # already has Environments
else
    echo "Migrating existing config to multi-environment format..."
    ROOT_CONFIG=$(echo "$ROOT_CONFIG" | jq '{
        DefaultEnvironment: "dev",
        Environments: {
            dev: {
                IBMiHost: .IBMiHost,
                IBMiUser: .IBMiUser,
                IBMiPassword: .IBMiPassword,
                SSHPort: .SSHPort,
                Library: .Library,
                File: .File,
                HomeDir: .HomeDir,
                UtilityLibrary: .UtilityLibrary
            }
        }
    }')
    echo "$ROOT_CONFIG" | jq '.' > "$CONFIG_PATH"
    echo "Migrated to multi-environment format with existing settings under 'dev'."
fi

# --- List mode ---
if $LIST; then
    ENV_COUNT=$(echo "$ROOT_CONFIG" | jq '.Environments | length')
    if [[ "$ENV_COUNT" -eq 0 ]]; then
        echo "No environments configured. Run setup-ibmi.sh to add one."
    else
        DEFAULT_ENV=$(echo "$ROOT_CONFIG" | jq -r '.DefaultEnvironment')
        echo "Configured environments:"
        echo "$ROOT_CONFIG" | jq -r --arg def "$DEFAULT_ENV" '
            .Environments | to_entries[] |
            "  \(.key)\(if .key == $def then " (default)" else "" end) — \(.value.IBMiUser)@\(.value.IBMiHost) lib=\(.value.Library)"
        '
    fi
    exit 0
fi

# --- Remove mode ---
if [[ -n "$REMOVE" ]]; then
    if ! echo "$ROOT_CONFIG" | jq -e ".Environments[\"$REMOVE\"]" &>/dev/null; then
        echo "ERROR: Environment '$REMOVE' not found."
        exit 1
    fi
    ROOT_CONFIG=$(echo "$ROOT_CONFIG" | jq "del(.Environments[\"$REMOVE\"])")
    CUR_DEFAULT=$(echo "$ROOT_CONFIG" | jq -r '.DefaultEnvironment')
    if [[ "$CUR_DEFAULT" == "$REMOVE" ]]; then
        ROOT_CONFIG=$(echo "$ROOT_CONFIG" | jq '.DefaultEnvironment = ""')
        echo "Warning: Removed default environment. Run setup again to set a new default."
    fi
    echo "$ROOT_CONFIG" | jq '.' > "$CONFIG_PATH"
    echo "Removed environment '$REMOVE'."
    exit 0
fi

# --- Add/Edit mode ---
prompt_value() {
    local prompt="$1"
    local default="$2"
    local display_default=""
    if [[ -n "$default" ]]; then
        display_default=" [$default]"
    fi
    read -rp "${prompt}${display_default}: " val
    if [[ -z "$val" ]]; then
        echo "$default"
    else
        echo "$val"
    fi
}

# Determine environment name
if [[ -z "$ENVIRONMENT" ]]; then
    ENVIRONMENT=$(prompt_value "Environment name (e.g., dev, qa, prod)" "")
fi
if [[ -z "$ENVIRONMENT" ]]; then
    echo "ERROR: Environment name is required."
    exit 1
fi

# Load existing environment values as defaults
EXISTING_HOST="" EXISTING_USER="" EXISTING_PASS="" EXISTING_PORT=""
EXISTING_LIB="" EXISTING_FILE="" EXISTING_HOME="" EXISTING_UTILLIB=""

if echo "$ROOT_CONFIG" | jq -e ".Environments[\"$ENVIRONMENT\"]" &>/dev/null; then
    echo "Editing existing environment '$ENVIRONMENT' — press Enter to keep current values."
    EXISTING_HOST=$(echo "$ROOT_CONFIG" | jq -r ".Environments[\"$ENVIRONMENT\"].IBMiHost // \"\"")
    EXISTING_USER=$(echo "$ROOT_CONFIG" | jq -r ".Environments[\"$ENVIRONMENT\"].IBMiUser // \"\"")
    EXISTING_PASS=$(echo "$ROOT_CONFIG" | jq -r ".Environments[\"$ENVIRONMENT\"].IBMiPassword // \"\"")
    EXISTING_PORT=$(echo "$ROOT_CONFIG" | jq -r ".Environments[\"$ENVIRONMENT\"].SSHPort // \"22\"")
    EXISTING_LIB=$(echo "$ROOT_CONFIG" | jq -r ".Environments[\"$ENVIRONMENT\"].Library // \"\"")
    EXISTING_FILE=$(echo "$ROOT_CONFIG" | jq -r ".Environments[\"$ENVIRONMENT\"].File // \"\"")
    EXISTING_HOME=$(echo "$ROOT_CONFIG" | jq -r ".Environments[\"$ENVIRONMENT\"].HomeDir // \"\"")
    EXISTING_UTILLIB=$(echo "$ROOT_CONFIG" | jq -r ".Environments[\"$ENVIRONMENT\"].UtilityLibrary // \"\"")
else
    echo "Creating new environment '$ENVIRONMENT'."
fi

echo ""
echo "--- Environment: $ENVIRONMENT ---"

IBMI_HOST=$(prompt_value "IBM i Host" "${EXISTING_HOST:-as400e.pplsi.com}")
IBMI_USER=$(prompt_value "IBM i User" "$EXISTING_USER")

if [[ -z "$IBMI_USER" ]]; then
    echo "ERROR: IBMiUser is required."
    exit 1
fi

# Password input
HAS_EXISTING=false
if [[ -n "$EXISTING_PASS" ]]; then
    HAS_EXISTING=true
fi

ENCRYPTED_PASSWORD=""
while [[ -z "$ENCRYPTED_PASSWORD" ]]; do
    if $HAS_EXISTING; then
        echo "IBM i Password (press Enter to keep existing, or type new password):"
    else
        echo "IBM i Password (input hidden):"
    fi
    read -rs password
    echo ""

    if [[ -z "$password" ]] && $HAS_EXISTING; then
        ENCRYPTED_PASSWORD="$EXISTING_PASS"
        echo "  (keeping existing password)"
    elif [[ -z "$password" ]]; then
        echo "ERROR: Password is required. Try again."
    else
        echo "Confirm password:"
        read -rs password_confirm
        echo ""
        if [[ "$password" == "$password_confirm" ]]; then
            ENCRYPTED_PASSWORD=$(encrypt_password "$password")
        else
            echo "Passwords do not match. Try again."
        fi
    fi
done

SSH_PORT=$(prompt_value "SSH Port" "${EXISTING_PORT:-22}")
IBMI_USER_UPPER=$(echo "$IBMI_USER" | tr '[:lower:]' '[:upper:]')
LIBRARY=$(prompt_value "Library" "${EXISTING_LIB:-$IBMI_USER_UPPER}")
LIBRARY=$(echo "$LIBRARY" | tr '[:lower:]' '[:upper:]')
SOURCE_FILE=$(prompt_value "Source File" "${EXISTING_FILE:-ILESRC}")
SOURCE_FILE=$(echo "$SOURCE_FILE" | tr '[:lower:]' '[:upper:]')
HOME_DIR=$(prompt_value "Home Directory" "${EXISTING_HOME:-/home/$IBMI_USER_UPPER}")
UTILITY_LIBRARY=$(prompt_value "Utility Library (for CPYSRC etc.)" "${EXISTING_UTILLIB:-$IBMI_USER_UPPER}")
UTILITY_LIBRARY=$(echo "$UTILITY_LIBRARY" | tr '[:lower:]' '[:upper:]')

# Build and save environment entry
ROOT_CONFIG=$(echo "$ROOT_CONFIG" | jq \
    --arg env "$ENVIRONMENT" \
    --arg host "$IBMI_HOST" \
    --arg user "$IBMI_USER" \
    --arg pass "$ENCRYPTED_PASSWORD" \
    --argjson port "$SSH_PORT" \
    --arg lib "$LIBRARY" \
    --arg file "$SOURCE_FILE" \
    --arg home "$HOME_DIR" \
    --arg utillib "$UTILITY_LIBRARY" \
    '.Environments[$env] = {
        IBMiHost: $host,
        IBMiUser: $user,
        IBMiPassword: $pass,
        SSHPort: $port,
        Library: $lib,
        File: $file,
        HomeDir: $home,
        UtilityLibrary: $utillib
    }')

# Set as default if it's the only one, or ask
ENV_COUNT=$(echo "$ROOT_CONFIG" | jq '.Environments | length')
CUR_DEFAULT=$(echo "$ROOT_CONFIG" | jq -r '.DefaultEnvironment')

if [[ "$ENV_COUNT" -eq 1 ]] || [[ -z "$CUR_DEFAULT" ]]; then
    ROOT_CONFIG=$(echo "$ROOT_CONFIG" | jq --arg env "$ENVIRONMENT" '.DefaultEnvironment = $env')
    echo "Set '$ENVIRONMENT' as the default environment."
else
    SET_DEFAULT=$(prompt_value "Set '$ENVIRONMENT' as default? (y/n)" "n")
    if [[ "$SET_DEFAULT" == "y" ]]; then
        ROOT_CONFIG=$(echo "$ROOT_CONFIG" | jq --arg env "$ENVIRONMENT" '.DefaultEnvironment = $env')
    fi
fi

echo "$ROOT_CONFIG" | jq '.' > "$CONFIG_PATH"

echo ""
echo "Environment '$ENVIRONMENT' saved to $CONFIG_PATH"
echo "Password is AES-256 encrypted (only decryptable by your user account on this machine)."
