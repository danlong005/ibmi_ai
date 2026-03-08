#!/usr/bin/env bash
# ---------------------------------------
# IBM i Database Member Download Script
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
    echo "Usage: cpysrc.sh <MEMBER> [-e environment] [-h host] [-u user] [-p password] [-P port] [-l library] [-f file] [-d localdir]"
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
TEMP_FILE=""
cleanup() {
    rm -f "$EXPECT_SSH" "$EXPECT_SFTP" "$TEMP_FILE" 2>/dev/null
}
trap cleanup EXIT

echo "=== Starting download of member: $MEMBER ==="
echo "LOG Library=$LIBRARY, File=$FILE, Member=$MEMBER"

# Step 1: Call CPYSRC to get the source type attribute
echo "LOG Step 1: Retrieving source member attribute..."
run_remote "system \"CALL ${UTIL_LIB}/CPYSRC PARM('${LIBRARY}' '${FILE}' '${MEMBER}')\""

# Step 1b: Export SRCEXT file to .source_ext stream file
echo "LOG Step 1b: Exporting source type to .source_ext..."
run_remote "system \"CPYTOIMPF FROMFILE(${UTIL_LIB}/SRCEXT) TOSTMF('${HOME_DIR}/.source_ext') MBROPT(*REPLACE) STMFCCSID(1208) RCDDLM(*CRLF) DTAFMT(*FIXED)\""

# Step 2: Read the attribute from .source_ext
echo "LOG Step 2: Reading .source_ext..."
ATTR_RESULT=$(run_remote_capture "cat ${HOME_DIR}/.source_ext 2>/dev/null | tr -d '[:space:]'")
if [[ -n "$ATTR_RESULT" ]]; then
    EXTENSION=$(echo "$ATTR_RESULT" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    echo "LOG Source type: $EXTENSION"
else
    EXTENSION="txt"
    echo "LOG Could not determine source type, defaulting to .txt"
fi

# Step 3: Ensure remote source directory exists
echo "LOG Step 3: Creating remote source directory..."
run_remote "mkdir -p ${HOME_DIR}/source"
REMOTE_STREAM="${HOME_DIR}/source/${MEMBER}.${EXTENSION}"
echo "LOG Remote IFS path: $REMOTE_STREAM"

# Step 4: Build local path
SOURCE_DIR="$(cd "$LOCAL_DIR" && pwd)/source"
mkdir -p "$SOURCE_DIR"
LOCAL_PATH="${SOURCE_DIR}/${MEMBER}.${EXTENSION}"
echo "LOG Local path: $LOCAL_PATH"

# Step 5: CPYTOSTMF - copy source member to IFS stream file
echo "LOG Step 5: Converting database member to stream file..."
run_remote "system \"CPYTOSTMF FROMMBR('/QSYS.LIB/${LIBRARY}.LIB/${FILE}.FILE/${MEMBER}.MBR') TOSTMF('${REMOTE_STREAM}') STMFCODPAG(1208) STMFOPT(*REPLACE)\""

# Step 6: Download via SFTP
echo "LOG Step 6: Downloading file via SFTP..."
"$EXPECT_SFTP" "$IBMI_HOST" "$SSH_PORT" "$IBMI_USER" "$IBMI_PASSWORD" \
    "get ${REMOTE_STREAM} ${LOCAL_PATH}" \
    "rm ${REMOTE_STREAM}" 2>&1 | while IFS= read -r line; do
    echo "LOG [sftp]: $line"
done

echo "=== Download complete: $LOCAL_PATH ==="
