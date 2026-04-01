#!/bin/bash
# Post-build script: Inserts Screen Recording TCC permission for EchoLog
# Uses the signing identity requirement (survives rebuilds) instead of CDHash

BUNDLE_ID="com.felixbeckert.EchoLog"
APP_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
TCC_DB="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
CSREQ_BIN="/tmp/echoLog_csreq.bin"

# Generate code requirement blob from the built app
REQ=$(codesign -dr - "$APP_PATH" 2>&1 | grep "designated =>" | sed 's/designated => //')
if [ -z "$REQ" ]; then
    echo "warning: Could not read code requirement from $APP_PATH"
    exit 0
fi

echo "$REQ" | csreq -r- -b "$CSREQ_BIN" 2>/dev/null
if [ ! -f "$CSREQ_BIN" ]; then
    echo "warning: Could not generate csreq binary"
    exit 0
fi

CSREQ_HEX=$(xxd -p "$CSREQ_BIN" | tr -d '\n')

# Insert or replace Screen Recording permission
sqlite3 "$TCC_DB" \
    "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, policy_id, indirect_object_identifier_type, indirect_object_identifier, indirect_object_code_identity, flags, last_modified, pid, pid_version, boot_uuid, last_reminded) VALUES ('kTCCServiceScreenCapture', '$BUNDLE_ID', 0, 2, 3, 1, X'$CSREQ_HEX', NULL, 0, 'UNUSED', NULL, 0, $(date +%s), 0, 0, 'UNUSED', 0);" 2>/dev/null

rm -f "$CSREQ_BIN"
echo "Screen Recording permission updated for $BUNDLE_ID"
