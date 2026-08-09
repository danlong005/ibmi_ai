#!/usr/bin/env bash
# ---------------------------------------
# Run a CL program on IBM i by name (no parameters supported)
# Uses expect for keyboard-interactive password auth
#
# Usage:
#   run-cl.sh <PGM> [-e environment] [-l library]
#
# Requires: jq, openssl, expect
# ---------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="$SCRIPT_DIR/.ibmi-config.json"

for cmd in jq openssl expect; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd is required. Install with: brew install $cmd (macOS) or apt install $cmd (Linux)"
        exit 1
    fi
done

# --- Encryption helpers ---
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

decrypt_password() {
    local encrypted="$1"
    local key
    key=$(get_encryption_key)
    echo "$encrypted" | openssl enc -aes-256-cbc -a -A -d -salt -pbkdf2 -pass "pass:${key}" 2>/dev/null
}

# Parse arguments
PGM=""
ENVIRONMENT=""
LIBRARY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--environment) ENVIRONMENT="$2"; shift 2 ;;
        -l|--library)     LIBRARY="$2"; shift 2 ;;
        -*)               echo "Unknown option: $1"; exit 1 ;;
        *)                PGM="$1"; shift ;;
    esac
done

if [[ -z "$PGM" ]]; then
    echo "Usage: run-cl.sh <PGM> [-e environment] [-l library]"
    exit 1
fi

# Load config
if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "ERROR: Config file not found. Run setup-ibmi.sh first."
    exit 1
fi
ROOT_CONFIG=$(cat "$CONFIG_PATH")
ENV_NAME="${ENVIRONMENT:-$(echo "$ROOT_CONFIG" | jq -r '.DefaultEnvironment')}"

if ! echo "$ROOT_CONFIG" | jq -e ".Environments[\"$ENV_NAME\"]" &>/dev/null; then
    echo "ERROR: Environment '$ENV_NAME' not found in config."
    exit 1
fi

CONFIG=$(echo "$ROOT_CONFIG" | jq ".Environments[\"$ENV_NAME\"]")

IBMI_HOST=$(echo "$CONFIG" | jq -r '.IBMiHost')
IBMI_USER=$(echo "$CONFIG" | jq -r '.IBMiUser')
SSH_PORT=$(echo "$CONFIG" | jq -r '.SSHPort // 22')
[[ -z "$LIBRARY" ]] && LIBRARY=$(echo "$CONFIG" | jq -r '.Library')

# Resolve password: config (encrypted) > prompt
IBMI_PASSWORD=""
ENCRYPTED=$(echo "$CONFIG" | jq -r '.IBMiPassword // ""')
if [[ -n "$ENCRYPTED" ]]; then
    IBMI_PASSWORD=$(decrypt_password "$ENCRYPTED") || true
fi
if [[ -z "$IBMI_PASSWORD" ]]; then
    echo -n "IBM i Password for $IBMI_USER@$IBMI_HOST: "
    read -rs IBMI_PASSWORD
    echo ""
fi

# Write expect helper script for remote command execution
EXPECT_SSH=$(mktemp)
cat > "$EXPECT_SSH" <<'EXPECTEOF'
#!/usr/bin/expect -f
set timeout 300
set host [lindex $argv 0]
set port [lindex $argv 1]
set user [lindex $argv 2]
set pass [lindex $argv 3]
set cmd [lindex $argv 4]

log_user 1
spawn ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p $port $user@$host $cmd
expect "assword:"
send "$pass\r"
expect eof
catch wait result
exit [lindex $result 3]
EXPECTEOF
chmod +x "$EXPECT_SSH"

cleanup() {
    rm -f "$EXPECT_SSH" 2>/dev/null
}
trap cleanup EXIT

LIB_LIST=(YAJL XMLILIB LIBHTTP PRODLIB RPGUNIT QDEVTOOLS)
LIB_LIST_CMDS="liblist -c $LIBRARY 2>/dev/null"
for lib in "${LIB_LIST[@]}"; do
    LIB_LIST_CMDS="$LIB_LIST_CMDS; liblist -a $lib 2>/dev/null"
done

echo "=== Calling CL: $LIBRARY/$PGM ==="
echo "Environment: $ENV_NAME"

FULL_CMD="qsh -c \"$LIB_LIST_CMDS; system 'CALL PGM($LIBRARY/$PGM)'\""
set +e
OUTPUT=$("$EXPECT_SSH" "$IBMI_HOST" "$SSH_PORT" "$IBMI_USER" "$IBMI_PASSWORD" "$FULL_CMD" 2>&1)
STATUS=$?
set -e
echo "$OUTPUT"

if [[ $STATUS -ne 0 ]]; then
    echo ""
    echo "ERROR: CL run failed with exit code $STATUS"
    exit 1
fi

echo ""
echo "=== CL Complete: $PGM ==="
