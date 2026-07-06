#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EMAIL="bob.smith.${CASE_SUFFIX}@example.test"
PASSWORD="secret123"
RESPONSE_FILE="/tmp/create_order_with_multiple_customized_items_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/create_order_with_multiple_customized_items_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/create_order_with_multiple_customized_items_login_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$LOGIN_FILE"
}
trap cleanup_files EXIT

# Given
curl -sS -o /dev/null -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"Bob Smith\",\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"

curl -sS -o "$LOGIN_FILE" -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data '{"items":[{"productId":"prod-201","name":"Espresso","quantity":1,"total":3.5,"customizations":{"size":"single","extraShot":false}},{"productId":"prod-102","name":"Cappuccino","quantity":2,"total":9.0,"customizations":{"size":"medium","milk":"almond","foam":"extra"}},{"productId":"prod-103","name":"Americano","quantity":1,"total":4.25,"customizations":{"size":"large","strength":"strong"}}]}' \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -F '"status":"Placed"' "$RESPONSE_FILE" >/dev/null
grep -F '"total":16.75' "$RESPONSE_FILE" >/dev/null
grep -F '"productId":"prod-201"' "$RESPONSE_FILE" >/dev/null
grep -F '"productId":"prod-102"' "$RESPONSE_FILE" >/dev/null
grep -F '"productId":"prod-103"' "$RESPONSE_FILE" >/dev/null
grep -F '"size":"single"' "$RESPONSE_FILE" >/dev/null
grep -F '"extraShot":false' "$RESPONSE_FILE" >/dev/null
grep -F '"size":"medium"' "$RESPONSE_FILE" >/dev/null
grep -F '"milk":"almond"' "$RESPONSE_FILE" >/dev/null
grep -F '"foam":"extra"' "$RESPONSE_FILE" >/dev/null
grep -F '"size":"large"' "$RESPONSE_FILE" >/dev/null
grep -F '"strength":"strong"' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:create_order_with_multiple_customized_items"

# Cleanup
# No explicit cleanup endpoint exists; test uses an isolated buyer account and unique order payload.
