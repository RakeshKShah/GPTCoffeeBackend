#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_DIR="/app/src/data"
DB_FILE="$DB_DIR/db.json"
BACKUP_FILE="/tmp/admin_edit_existing_customization_${CASE_SUFFIX}_db.json"
RESPONSE_FILE="/tmp/admin_edit_existing_customization_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_edit_existing_customization_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/admin_edit_existing_customization_${CASE_SUFFIX}_login.json"
PAYLOAD_FILE="/tmp/admin_edit_existing_customization_${CASE_SUFFIX}_payload.json"
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
    {"id":"admin-003","name":"Admin 003","email":"admin-003@gptcoffee.test","password":"adminpass123","role":"admin"}
  ],
  "products": [],
  "customizations": [
    {"id":"cust-001","name":"Sugar Level","options":["None","Light","Normal","Extra"]}
  ],
  "orders": []
}
JSON
curl -sS -o "$LOGIN_FILE" -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' --data '{"email":"admin-003@gptcoffee.test","password":"adminpass123"}'
TOKEN="$(jq -r '.token' "$LOGIN_FILE")"
[ "$TOKEN" != "null" ]

# When
cat > "$PAYLOAD_FILE" <<'JSON'
{"customizations":[{"id":"cust-001","name":"Sweetness Level","options":["None","Low","Medium","High"]}]}
JSON
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X PUT "$BASE_URL/api/admin/customizations" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  --data @"$PAYLOAD_FILE" > "$STATUS_FILE"

# Then
[ "$(cat "$STATUS_FILE")" = "200" ]
jq -e '.customizations == [{"id":"cust-001","name":"Sweetness Level","options":["None","Low","Medium","High"]}]' "$RESPONSE_FILE" >/dev/null
jq -e '.customizations == [{"id":"cust-001","name":"Sweetness Level","options":["None","Low","Medium","High"]}]' "$DB_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:admin_edit_existing_customization"

# Cleanup
:
