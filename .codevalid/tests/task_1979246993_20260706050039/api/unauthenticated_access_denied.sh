#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_PATH="/app/src/data/db.json"
BACKUP_FILE="/tmp/unauthenticated_access_denied_${CASE_SUFFIX}_db.json"
RESPONSE_FILE="/tmp/unauthenticated_access_denied_${CASE_SUFFIX}_response.json"
STATUS_FILE="/tmp/unauthenticated_access_denied_${CASE_SUFFIX}.status"
ORIGINAL_CUSTOMIZATIONS=""

cleanup() {
  if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" "$DB_PATH"
  else
    rm -f "$DB_PATH"
  fi
  rm -f "$BACKUP_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup EXIT

# Given
if [ -f "$DB_PATH" ]; then
  cp "$DB_PATH" "$BACKUP_FILE"
fi
rm -f "$DB_PATH"
ORIGINAL_CUSTOMIZATIONS="$(curl -sS "$BASE_URL/api/menu" | jq -c '.customizations')"

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X PUT "$BASE_URL/api/admin/customizations" \
  -H 'Content-Type: application/json' \
  --data '{"customizations":{"theme":"dark"}}' > "$STATUS_FILE"

# Then
[ "$(cat "$STATUS_FILE")" = "401" ]
grep -F 'Missing or invalid session.' "$RESPONSE_FILE" >/dev/null
[ "$(jq -c '.customizations' "$DB_PATH")" = "$ORIGINAL_CUSTOMIZATIONS" ]

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_access_denied"

# Cleanup
:
