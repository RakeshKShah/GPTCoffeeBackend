#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EMAIL="carol.davis.${CASE_SUFFIX}@example.test"
PASSWORD="secret123"
RESPONSE_FILE="/tmp/create_order_single_item_success_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/create_order_single_item_success_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/create_order_single_item_success_login_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$LOGIN_FILE"
}
trap cleanup_files EXIT

# Given
curl -sS -o /dev/null -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"Carol Davis\",\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"

curl -sS -o "$LOGIN_FILE" -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data '{"items":[{"name":"Hazelnut Latte","size":"Medium","customizations":["Extra Shot","Oat Milk"],"total":5.25}]}' \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -Eq '"id":"ORD-[0-9]{6}"' "$RESPONSE_FILE"
grep -Eq '"buyerId":"[^"]+"' "$RESPONSE_FILE"
grep -F '"buyerName":"Carol Davis"' "$RESPONSE_FILE" >/dev/null
grep -F '"status":"Placed"' "$RESPONSE_FILE" >/dev/null
grep -F '"total":5.25' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"Hazelnut Latte"' "$RESPONSE_FILE" >/dev/null
grep -F '"customizations":["Extra Shot","Oat Milk"]' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:create_order_single_item_success"

# Cleanup
# No explicit cleanup endpoint exists; test uses an isolated buyer account and unique order payload.
