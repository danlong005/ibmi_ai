#!/usr/bin/env bash
# ---------------------------------------
# IBM i Database Member Upload Script
# Uses expect for keyboard-interactive password auth
# ---------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="$SCRIPT_DIR/.ibmi-config.json"

# Check for required tools
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
MEMBER=""
ENVIRONMENT=""
IBMI_HOST="" IBMI_USER="" IBMI_PASSWORD="" SSH_PORT=""
LIBRARY="" FILE="" LOCAL_DIR="."

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--environment) ENVIRONMENT="$2"; shift 2 ;;
        -h|--host)        IBMI_HOST="$2"; shift 2 ;;
        -u|--user)        IBMI_USER="$2"; shift 2 ;;
        -p|--password)    IBMI_PASSWORD="$2"; shift 2 ;;
        -P|--port)        SSH_PORT="$2"; shift 2 ;;
        -l|--library)     LIBRARY="$2"; shift 2 ;;
        -f|--file)        FILE="$2"; shift 2 ;;
        -d|--dir)         LOCAL_DIR="$2"; shift 2 ;;
        -*)               echo "Unknown option: $1"; exit 1 ;;
        *)                MEMBER="$1"; shift ;;
    esac
done

if [[ -z "$MEMBER" ]]; then
    echo "Usage: putsrc.sh <MEMBER> [-e environment] [-h host] [-u user] [-p password] [-P port] [-l library] [-f file] [-d localdir]"
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

# Apply config defaults, allow CLI overrides
[[ -z "$IBMI_HOST" ]] && IBMI_HOST=$(echo "$CONFIG" | jq -r '.IBMiHost')
[[ -z "$IBMI_USER" ]] && IBMI_USER=$(echo "$CONFIG" | jq -r '.IBMiUser')
[[ -z "$SSH_PORT" ]]  && SSH_PORT=$(echo "$CONFIG" | jq -r '.SSHPort // 22')
[[ -z "$LIBRARY" ]]   && LIBRARY=$(echo "$CONFIG" | jq -r '.Library')
[[ -z "$FILE" ]]      && FILE=$(echo "$CONFIG" | jq -r '.File')
HOME_DIR=$(echo "$CONFIG" | jq -r '.HomeDir')
UTIL_LIB=$(echo "$CONFIG" | jq -r '.UtilityLibrary')

# Resolve password: CLI > config (encrypted) > prompt
if [[ -z "$IBMI_PASSWORD" ]]; then
    ENCRYPTED=$(echo "$CONFIG" | jq -r '.IBMiPassword // ""')
    if [[ -n "$ENCRYPTED" ]]; then
        IBMI_PASSWORD=$(decrypt_password "$ENCRYPTED") || true
    fi
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
# remaining args are sftp commands
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

# Helper: run a remote command via ssh
run_remote() {
    local cmd="$1"
    "$EXPECT_SSH" "$IBMI_HOST" "$SSH_PORT" "$IBMI_USER" "$IBMI_PASSWORD" "$cmd" 2>&1 | while IFS= read -r line; do
        echo "LOG [ssh]: $line"
    done
}

# Helper: run a remote command and capture output
run_remote_capture() {
    local cmd="$1"
    "$EXPECT_SSH" "$IBMI_HOST" "$SSH_PORT" "$IBMI_USER" "$IBMI_PASSWORD" "$cmd" 2>/dev/null
}

# Cleanup temp files on exit
cleanup() {
    rm -f "$EXPECT_SSH" "$EXPECT_SFTP" 2>/dev/null
}
trap cleanup EXIT

# Find the file in the source directory by member name
MEMBER=$(echo "$MEMBER" | tr '[:lower:]' '[:upper:]')
SOURCE_DIR="$(cd "$LOCAL_DIR" && pwd)/source"

# Look for MEMBER.* in source dir
shopt -s nullglob
MATCHES=("$SOURCE_DIR"/${MEMBER}.*)
shopt -u nullglob

if [[ ${#MATCHES[@]} -eq 0 ]]; then
    echo "ERROR: No file found for member $MEMBER in $SOURCE_DIR"
    exit 1
fi
if [[ ${#MATCHES[@]} -gt 1 ]]; then
    echo "ERROR: Multiple files found for member $MEMBER in $SOURCE_DIR"
    for f in "${MATCHES[@]}"; do echo "  $f"; done
    exit 1
fi

LOCAL_PATH="${MATCHES[0]}"
FILENAME=$(basename "$LOCAL_PATH")
EXTENSION="${FILENAME##*.}"
EXTENSION_LOWER=$(echo "$EXTENSION" | tr '[:upper:]' '[:lower:]')
SOURCE_TYPE=$(echo "$EXTENSION" | tr '[:lower:]' '[:upper:]')

REMOTE_STREAM="${HOME_DIR}/source/${MEMBER}.${EXTENSION_LOWER}"

echo "=== Starting upload of member: $MEMBER ==="
echo "LOG Library=$LIBRARY, File=$FILE, Member=$MEMBER, SourceType=$SOURCE_TYPE"
echo "LOG Local path: $LOCAL_PATH"
echo "LOG Remote IFS path: $REMOTE_STREAM"

# Step 1: Ensure remote source directory exists
echo "LOG Step 1: Creating remote source directory..."
run_remote "mkdir -p ${HOME_DIR}/source"

# Step 2: Upload file via SFTP
echo "LOG Step 2: Uploading file via SFTP..."
"$EXPECT_SFTP" "$IBMI_HOST" "$SSH_PORT" "$IBMI_USER" "$IBMI_PASSWORD" \
    "put ${LOCAL_PATH} ${REMOTE_STREAM}" 2>&1 | while IFS= read -r line; do
    echo "LOG [sftp]: $line"
done

# Step 3: CPYFRMSTMF - copy IFS stream file back to source member
echo "LOG Step 3: Copying stream file to database member..."
run_remote "system \"CPYFRMSTMF FROMSTMF('${REMOTE_STREAM}') TOMBR('/QSYS.LIB/${LIBRARY}.LIB/${FILE}.FILE/${MEMBER}.MBR') MBROPT(*REPLACE) STMFCODPAG(1208)\""

# Step 4: Set the source type attribute on the member
echo "LOG Step 4: Setting source type attribute to $SOURCE_TYPE..."
run_remote "system \"CHGPFM FILE(${LIBRARY}/${FILE}) MBR(${MEMBER}) SRCTYPE(${SOURCE_TYPE})\""

# Step 5: Clean up remote IFS file
echo "LOG Step 5: Cleaning up remote file..."
run_remote "rm -f ${REMOTE_STREAM}"

echo "=== Upload complete: $MEMBER ($SOURCE_TYPE) ==="
