#!/usr/bin/env bash
# ---------------------------------------
# Compile an RPGUnit test program on IBM i
# Uses expect for keyboard-interactive password auth
#
# Conventions (all overridable):
#   Test source member : {TSTPGM}
#   Bound service pgm  : derived from {TSTPGM} by stripping trailing _T
#
# Usage:
#   compile-tst.sh <TSTPGM> [-e environment] [-l library] [-s srcmbr] [-b bndsrvpgm]
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
TSTPGM=""
ENVIRONMENT=""
LIBRARY=""
FILE=""
SRC_MBR=""
BND_SRVPGM=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--environment) ENVIRONMENT="$2"; shift 2 ;;
        -l|--library)     LIBRARY="$2"; shift 2 ;;
        -f|--file)        FILE="$2"; shift 2 ;;
        -s|--srcmbr)      SRC_MBR="$2"; shift 2 ;;
        -b|--bndsrvpgm)   BND_SRVPGM="$2"; shift 2 ;;
        -*)               echo "Unknown option: $1"; exit 1 ;;
        *)                TSTPGM="$1"; shift ;;
    esac
done

if [[ -z "$TSTPGM" ]]; then
    echo "Usage: compile-tst.sh <TSTPGM> [-e environment] [-l library] [-f file] [-s srcmbr] [-b bndsrvpgm]"
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
[[ -z "$FILE" ]]    && FILE=$(echo "$CONFIG" | jq -r '.File // "ILESRC"')

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

# Apply naming conventions
RESOLVED_SRC_MBR="${SRC_MBR:-$TSTPGM}"
RESOLVED_BND_SRVPGM="${BND_SRVPGM:-${TSTPGM%_T}}"

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

# Add any extra libraries your source needs on the *LIBL below (e.g. YAJL RPGUNIT). LIBRARY is set as *CURLIB.
LIB_LIST=()
LIB_LIST_CMDS="liblist -c $LIBRARY 2>/dev/null"
for lib in "${LIB_LIST[@]}"; do
    LIB_LIST_CMDS="$LIB_LIST_CMDS; liblist -a $lib 2>/dev/null"
done

run_remote() {
    local cmd="$1"
    echo "Executing: $cmd"
    local full_cmd="qsh -c \"$LIB_LIST_CMDS; $cmd\""
    local output status
    set +e
    output=$("$EXPECT_SSH" "$IBMI_HOST" "$SSH_PORT" "$IBMI_USER" "$IBMI_PASSWORD" "$full_cmd" 2>&1)
    status=$?
    set -e
    echo "$output"
    if [[ $status -ne 0 ]]; then
        echo "ERROR: Command failed with exit code $status"
        return 1
    fi
    return 0
}

echo "=== Compiling $TSTPGM Test Program ==="
echo "Environment: $ENV_NAME  Library: $LIBRARY"

# Step 1: Compile SQLRPGLE test source as a module
# Uses CRTSQLRPGI directly (same approach as service program modules) rather
# than RUCRTTST, which uses OPTION(*SYSVAL) and does not play well with **free
# source when RPGPPOPT(*LVL2) expands the iRPGUnit TESTCASE include.
echo ""
echo "--- Step 1: Creating $TSTPGM module ---"
STEP1_CMD="system 'CRTSQLRPGI OBJ($LIBRARY/$TSTPGM) SRCFILE($LIBRARY/$FILE) SRCMBR($RESOLVED_SRC_MBR) OBJTYPE(*MODULE) COMMIT(*NONE) DBGVIEW(*SOURCE)'"
if ! run_remote "$STEP1_CMD"; then
    exit 1
fi

# Step 2: Bind into a service program for RPGUnit
# EXPORT(*ALL) so RUCALLTST can discover SETUP/TEARDOWN/test_* procedures.
# BNDDIR(RPGUNIT/IRPGUNIT) pulls in the iRPGUnit assertion service programs.
# BNDSRVPGM adds the service program under test (omitted when *NONE).
echo ""
echo "--- Step 2: Creating $TSTPGM service program ---"
BND_SRVPGM_CLAUSE=""
[[ "$RESOLVED_BND_SRVPGM" != "*NONE" ]] && BND_SRVPGM_CLAUSE=" BNDSRVPGM($LIBRARY/$RESOLVED_BND_SRVPGM)"
STEP2_CMD="system 'CRTSRVPGM SRVPGM($LIBRARY/$TSTPGM) MODULE($LIBRARY/$TSTPGM) EXPORT(*ALL)$BND_SRVPGM_CLAUSE BNDDIR(RPGUNIT/IRPGUNIT) ACTGRP(*CALLER)'"
if ! run_remote "$STEP2_CMD"; then
    exit 1
fi

echo ""
echo "=== Compilation Complete ==="
echo ""
echo "To run tests, execute:"
echo "  bash bin/run-tests.sh $TSTPGM"
