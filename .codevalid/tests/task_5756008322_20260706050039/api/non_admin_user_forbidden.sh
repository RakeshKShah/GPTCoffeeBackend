#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_DIR="/app/src/data"
DB_FILE="$DB_DIR/db.json"
BACKUP_FILE="/tmp/non_admin_user_forbidden_${CASE_SUFFIX}_db.json"
RESPONSE_FILE="/tmp/non_admin_user_forbidden_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/non_admin_user_forbidden_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/non_admin_user_forbidden_${CASE_SUFFIX}_login.json"
PAYLOAD_FILE="/tmp/non_admin_user_forbidden_${CASE_SUFFIX}_payload.json"
cleanup() {
  if [ -f "$BACKUP_FILE" ]; then cp "$BACKUP_FILE" "$DB_FILE"; else rm -f "$DB_FILE"; fi
  rm -f "$BACKUP_FILE" "$RESPONSE_FILE" "$STATUS_FILE" "$LOGIN_FILE" "$PAYLOAD_FILE"
}
trap cleanup EXIT

# Given
mkdir -p "$DB_DIR"
if [ -f "$DB_FILE" ]; then cp "$DB_FILE" "$BACKUP_FILE"; fi
cat > "$DB_FILE" <<'JSON'
{
  "users": [
    {"id":"user-001","name":"User 001","email":"user-001@gptcoffee.test","password":"buyerpass123","role":"buyer"}
  ],
  "products": [],
  "customizations": [
    {"id":"existing-001","name":"Existing","options":["Keep"]}
  ],
  "orders": []
}
JSON
curl -sS -o "$LOGIN_FILE" -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' --data '{"email":"user-001@gptcoffee.test","password":"buyerpass123"}'
TOKEN="$(jq -r '.token' "$LOGIN_FILE")"
[ "$TOKEN" != "null" ]
cat > "$PAYLOAD_FILE" <<'JSON'
{"customizations":[{"id":"cust-001","name":"Test","options":["A"]}]}
JSON

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X PUT "$BASE_URL/api/admin/customizations" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data @"$PAYLOAD_FILE" > "$STATUS_FILE"

# Then
[ "$(cat "$STATUS_FILE")" = "403" ]
grep -F 'Admin access required.' "$RESPONSE_FILE" >/dev/null
jq -e '.customizations == [{"id":"existing-001","name":"Existing","options":["Keep"]}]' "$DB_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:non_admin_user_forbidden"

# Cleanup
:
