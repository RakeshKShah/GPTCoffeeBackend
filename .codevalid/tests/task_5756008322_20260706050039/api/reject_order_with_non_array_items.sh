#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EMAIL="john.rivera.${CASE_SUFFIX}@example.test"
PASSWORD="secret123"
RESPONSE_FILE="/tmp/reject_order_with_non_array_items_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/reject_order_with_non_array_items_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/reject_order_with_non_array_items_login_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$LOGIN_FILE"
}
trap cleanup_files EXIT

# Given
curl -sS -o /dev/null -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"John Rivera\",\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"

curl -sS -o "$LOGIN_FILE" -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data '{"items":{"productId":"prod-101","name":"Latte","total":5.0}}' \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "400" ]
grep -F '"message":"Order must include at least one item."' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:reject_order_with_non_array_items"

# Cleanup
# Stateless negative test; no order is created.
