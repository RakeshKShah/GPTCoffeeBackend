#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EMAIL="sarah.kim.${CASE_SUFFIX}@example.test"
PASSWORD="secret123"
ORDER_RESPONSE_FILE="/tmp/verify_customization_options_preserved_in_stored_order_${CASE_SUFFIX}.json"
ORDER_STATUS_FILE="/tmp/verify_customization_options_preserved_in_stored_order_${CASE_SUFFIX}.status"
LIST_RESPONSE_FILE="/tmp/verify_customization_options_preserved_in_stored_order_list_${CASE_SUFFIX}.json"
LOGIN_FILE="/tmp/verify_customization_options_preserved_in_stored_order_login_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$ORDER_RESPONSE_FILE" "$ORDER_STATUS_FILE" "$LIST_RESPONSE_FILE" "$LOGIN_FILE"
}
trap cleanup_files EXIT

# Given
curl -sS -o /dev/null -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"Sarah Kim\",\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"

curl -sS -o "$LOGIN_FILE" -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When
curl -sS -o "$ORDER_RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data '{"items":[{"productId":"prod-200","name":"Mocha","quantity":1,"total":6.5,"customizations":{"size":"venti","milk":"soy","sweetness":"caramel-2-pumps","whippedCream":true,"drizzle":"chocolate","temperature":"extra-hot","caffeine":"half-caf"}}]}' \
  > "$ORDER_STATUS_FILE"

curl -sS -o "$LIST_RESPONSE_FILE" -X GET "$BASE_URL/api/orders/my" \
  -H "Authorization: Bearer $TOKEN"

# Then
STATUS="$(cat "$ORDER_STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -F '"productId":"prod-200"' "$ORDER_RESPONSE_FILE" >/dev/null
grep -F '"size":"venti"' "$ORDER_RESPONSE_FILE" >/dev/null
grep -F '"milk":"soy"' "$ORDER_RESPONSE_FILE" >/dev/null
grep -F '"sweetness":"caramel-2-pumps"' "$ORDER_RESPONSE_FILE" >/dev/null
grep -F '"whippedCream":true' "$ORDER_RESPONSE_FILE" >/dev/null
grep -F '"drizzle":"chocolate"' "$ORDER_RESPONSE_FILE" >/dev/null
grep -F '"temperature":"extra-hot"' "$ORDER_RESPONSE_FILE" >/dev/null
grep -F '"caffeine":"half-caf"' "$ORDER_RESPONSE_FILE" >/dev/null
grep -F '"productId":"prod-200"' "$LIST_RESPONSE_FILE" >/dev/null
grep -F '"size":"venti"' "$LIST_RESPONSE_FILE" >/dev/null
grep -F '"milk":"soy"' "$LIST_RESPONSE_FILE" >/dev/null
grep -F '"sweetness":"caramel-2-pumps"' "$LIST_RESPONSE_FILE" >/dev/null
grep -F '"whippedCream":true' "$LIST_RESPONSE_FILE" >/dev/null
grep -F '"drizzle":"chocolate"' "$LIST_RESPONSE_FILE" >/dev/null
grep -F '"temperature":"extra-hot"' "$LIST_RESPONSE_FILE" >/dev/null
grep -F '"caffeine":"half-caf"' "$LIST_RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:verify_customization_options_preserved_in_stored_order"

# Cleanup
# No explicit cleanup endpoint exists; test uses an isolated buyer account and unique order payload.
