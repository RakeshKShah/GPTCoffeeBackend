#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EMAIL="david.lee.${CASE_SUFFIX}@example.test"
PASSWORD="secret123"
RESPONSE_FILE="/tmp/create_order_missing_item_total_handling_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/create_order_missing_item_total_handling_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/create_order_missing_item_total_handling_login_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$LOGIN_FILE"
}
trap cleanup_files EXIT

# Given
curl -sS -o /dev/null -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"David Lee\",\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"

curl -sS -o "$LOGIN_FILE" -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data '{"items":[{"name":"Black Coffee","size":"Small"},{"name":"Green Tea","size":"Large","total":3.5}]}' \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -Eq '"buyerId":"[^"]+"' "$RESPONSE_FILE"
grep -F '"buyerName":"David Lee"' "$RESPONSE_FILE" >/dev/null
grep -F '"status":"Placed"' "$RESPONSE_FILE" >/dev/null
grep -F '"total":3.5' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"Black Coffee"' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"Green Tea"' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:create_order_missing_item_total_handling"

# Cleanup
# No explicit cleanup endpoint exists; test uses an isolated buyer account and unique order payload.
