#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_PATH="/app/src/data/db.json"
BACKUP_FILE="/tmp/admin_customizations_empty_body_${CASE_SUFFIX}_db.json"
LOGIN_RESPONSE="/tmp/admin_customizations_empty_body_${CASE_SUFFIX}_login.json"
LOGIN_STATUS_FILE="/tmp/admin_customizations_empty_body_${CASE_SUFFIX}_login.status"
RESPONSE_FILE="/tmp/admin_customizations_empty_body_${CASE_SUFFIX}_response.json"
STATUS_FILE="/tmp/admin_customizations_empty_body_${CASE_SUFFIX}.status"
TOKEN=""

cleanup() {
  if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" "$DB_PATH"
  else
    rm -f "$DB_PATH"
  fi
  rm -f "$BACKUP_FILE" "$LOGIN_RESPONSE" "$LOGIN_STATUS_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup EXIT

# Given
if [ -f "$DB_PATH" ]; then
  cp "$DB_PATH" "$BACKUP_FILE"
fi
rm -f "$DB_PATH"

curl -sS -o "$LOGIN_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$LOGIN_STATUS_FILE"
[ "$(cat "$LOGIN_STATUS_FILE")" = "200" ]
TOKEN="$(jq -r '.token' "$LOGIN_RESPONSE")"
[ -n "$TOKEN" ]
[ "$TOKEN" != "null" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X PUT "$BASE_URL/api/admin/customizations" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data '{}' > "$STATUS_FILE"

# Then
[ "$(cat "$STATUS_FILE")" = "200" ]
jq -e 'has("customizations") and (.customizations == null)' "$RESPONSE_FILE" >/dev/null
jq -e 'has("customizations") | not' "$DB_PATH" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:admin_customizations_empty_body"

# Cleanup
:
