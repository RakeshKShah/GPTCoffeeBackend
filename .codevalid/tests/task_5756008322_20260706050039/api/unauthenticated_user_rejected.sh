#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_DIR="/app/src/data"
DB_FILE="$DB_DIR/db.json"
BACKUP_FILE="/tmp/unauthenticated_user_rejected_${CASE_SUFFIX}_db.json"
RESPONSE_FILE="/tmp/unauthenticated_user_rejected_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/unauthenticated_user_rejected_${CASE_SUFFIX}.status"
PAYLOAD_FILE="/tmp/unauthenticated_user_rejected_${CASE_SUFFIX}_payload.json"
cleanup() {
  if [ -f "$BACKUP_FILE" ]; then cp "$BACKUP_FILE" "$DB_FILE"; else rm -f "$DB_FILE"; fi
  rm -f "$BACKUP_FILE" "$RESPONSE_FILE" "$STATUS_FILE" "$PAYLOAD_FILE"
}
trap cleanup EXIT

# Given
mkdir -p "$DB_DIR"
if [ -f "$DB_FILE" ]; then cp "$DB_FILE" "$BACKUP_FILE"; fi
cat > "$DB_FILE" <<'JSON'
{
  "users": [
    {"id":"admin-sample","name":"Ari Admin","email":"admin@gptcoffee.test","password":"admin123","role":"admin"}
  ],
  "products": [],
  "customizations": [
    {"id":"existing-001","name":"Existing","options":["Keep"]}
  ],
  "orders": []
}
JSON
cat > "$PAYLOAD_FILE" <<'JSON'
{"customizations":[{"id":"cust-001","name":"Test","options":["A"]}]}
JSON

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X PUT "$BASE_URL/api/admin/customizations" \
  -H 'Content-Type: application/json' \
  --data @"$PAYLOAD_FILE" > "$STATUS_FILE"

# Then
[ "$(cat "$STATUS_FILE")" = "401" ]
grep -Eq 'Missing or invalid session|Invalid session' "$RESPONSE_FILE"
jq -e '.customizations == [{"id":"existing-001","name":"Existing","options":["Keep"]}]' "$DB_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_user_rejected"

# Cleanup
:
