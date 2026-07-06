#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EMAIL="emma.wilson.${CASE_SUFFIX}@example.test"
PASSWORD="secret123"
RESPONSE_FILE="/tmp/create_order_with_items_missing_total_field_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/create_order_with_items_missing_total_field_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/create_order_with_items_missing_total_field_login_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$LOGIN_FILE"
}
trap cleanup_files EXIT

# Given
curl -sS -o /dev/null -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"Emma Wilson\",\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"

curl -sS -o "$LOGIN_FILE" -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data '{"items":[{"productId":"prod-105","name":"Water","quantity":1,"customizations":{"temperature":"room"}},{"productId":"prod-106","name":"Espresso","quantity":1,"total":0,"customizations":{"size":"double"}}]}' \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -F '"status":"Placed"' "$RESPONSE_FILE" >/dev/null
grep -F '"total":0' "$RESPONSE_FILE" >/dev/null
grep -F '"productId":"prod-105"' "$RESPONSE_FILE" >/dev/null
grep -F '"temperature":"room"' "$RESPONSE_FILE" >/dev/null
grep -F '"productId":"prod-106"' "$RESPONSE_FILE" >/dev/null
grep -F '"size":"double"' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:create_order_with_items_missing_total_field"

# Cleanup
# No explicit cleanup endpoint exists; test uses an isolated buyer account and unique order payload.
