#!/usr/bin/env bash
# ---------------------------------------
# IBM i Zip File Download Script
# Downloads .zip files from the configured user's home directory (or a
# specified remote dir). Uses expect for keyboard-interactive password auth.
#
# Usage:
#   bash bin/get-zip.sh                       # List available zip files
#   bash bin/get-zip.sh report.zip            # Download a specific zip
#   bash bin/get-zip.sh report.zip -e qa -r /home/OTHERUSER -d .
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
FILE_NAME=""
REMOTE_DIR=""
LOCAL_DIR="."
ENVIRONMENT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--environment) ENVIRONMENT="$2"; shift 2 ;;
        -r|--remote-dir)  REMOTE_DIR="$2"; shift 2 ;;
        -d|--dir)         LOCAL_DIR="$2"; shift 2 ;;
        -*)               echo "Unknown option: $1"; exit 1 ;;
        *)                FILE_NAME="$1"; shift ;;
    esac
done

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
[[ -z "$REMOTE_DIR" ]] && REMOTE_DIR="/home/$IBMI_USER"

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

# Write expect helper scripts to temp files
EXPECT_SSH=$(mktemp)
cat > "$EXPECT_SSH" <<'EXPECTEOF'
#!/usr/bin/expect -f
set timeout 30
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

EXPECT_SFTP=$(mktemp)
cat > "$EXPECT_SFTP" <<'EXPECTEOF'
#!/usr/bin/expect -f
set timeout 60
set host [lindex $argv 0]
set port [lindex $argv 1]
set user [lindex $argv 2]
set pass [lindex $argv 3]
set sftp_cmds [lrange $argv 4 end]

log_user 1
spawn sftp -P $port -o StrictHostKeyChecking=no -o PubkeyAuthentication=no $user@$host
expect "assword:"
send "$pass\r"
expect "sftp>"
foreach cmd $sftp_cmds {
    send "$cmd\r"
    expect "sftp>"
}
send "quit\r"
expect eof
EXPECTEOF
chmod +x "$EXPECT_SFTP"

run_remote_capture() {
    local cmd="$1"
    "$EXPECT_SSH" "$IBMI_HOST" "$SSH_PORT" "$IBMI_USER" "$IBMI_PASSWORD" "$cmd" 2>/dev/null
}

cleanup() {
    rm -f "$EXPECT_SSH" "$EXPECT_SFTP" 2>/dev/null
}
trap cleanup EXIT

# --- List mode: no filename given ---
if [[ -z "$FILE_NAME" ]]; then
    echo "=== Zip files available in $REMOTE_DIR ==="
    LISTING=$(run_remote_capture "ls $REMOTE_DIR/*.zip 2>/dev/null" || true)
    if [[ -z "$(echo "$LISTING" | tr -d '[:space:]')" ]]; then
        echo "No .zip files found in $REMOTE_DIR"
    else
        echo "$LISTING"
    fi
    exit 0
fi

# --- Download mode ---
REMOTE_PATH="$REMOTE_DIR/$FILE_NAME"
LOCAL_DIR="$(cd "$LOCAL_DIR" && pwd)"
LOCAL_PATH="$LOCAL_DIR/$FILE_NAME"

echo "=== Downloading $FILE_NAME ==="
echo "LOG Remote path: $REMOTE_PATH"
echo "LOG Local path:  $LOCAL_PATH"

# Verify the remote file exists
echo "LOG Checking remote file..."
CHECK=$(run_remote_capture "ls $REMOTE_PATH 2>/dev/null" || true)
if [[ -z "$(echo "$CHECK" | tr -d '[:space:]')" ]]; then
    echo "ERROR: $REMOTE_PATH not found on IBM i."
    exit 1
fi

# Download via SFTP
echo "LOG Downloading via SFTP..."
"$EXPECT_SFTP" "$IBMI_HOST" "$SSH_PORT" "$IBMI_USER" "$IBMI_PASSWORD" \
    "get $REMOTE_PATH $LOCAL_PATH" 2>&1 | while IFS= read -r line; do
    echo "LOG [sftp]: $line"
done

if [[ -f "$LOCAL_PATH" ]]; then
    echo "=== Download complete: $LOCAL_PATH ==="
else
    echo "ERROR: Download failed — file not found at $LOCAL_PATH"
    exit 1
fi
