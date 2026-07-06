#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="custom-cappuccino-${CASE_SUFFIX}"
LOGIN_FILE="/tmp/admin_add_product_all_fields_success_login_${CASE_SUFFIX}.json"
MENU_BEFORE_FILE="/tmp/admin_add_product_all_fields_success_menu_before_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/admin_add_product_all_fields_success_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_add_product_all_fields_success_status_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$LOGIN_FILE" "$MENU_BEFORE_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
curl -sS "$BASE_URL/api/menu" > "$MENU_BEFORE_FILE"
ADMIN_TOKEN="$(curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
[ -n "$ADMIN_TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Cappuccino Supreme\",\"note\":\"Seasonal favorite\",\"description\":\"Rich espresso with steamed milk foam\",\"price\":4.5,\"strength\":\"Strong\",\"gradient\":\"from-amber-500 to-orange-600\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -F '"id":"'"$PRODUCT_ID"'"' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"Cappuccino Supreme"' "$RESPONSE_FILE" >/dev/null
grep -F '"note":"Seasonal favorite"' "$RESPONSE_FILE" >/dev/null
grep -F '"description":"Rich espresso with steamed milk foam"' "$RESPONSE_FILE" >/dev/null
grep -F '"price":4.5' "$RESPONSE_FILE" >/dev/null
grep -F '"strength":"Strong"' "$RESPONSE_FILE" >/dev/null
grep -F '"gradient":"from-amber-500 to-orange-600"' "$RESPONSE_FILE" >/dev/null
MENU_AFTER="$(curl -sS "$BASE_URL/api/menu")"
printf '%s' "$MENU_AFTER" | grep -F '"id":"'"$PRODUCT_ID"'"' >/dev/null
FIRST_ID_AFTER="$(printf '%s' "$MENU_AFTER" | sed -n 's/.*"products":\[{"id":"\([^"]*\)".*/\1/p' | head -n 1)"
[ "$FIRST_ID_AFTER" = "$PRODUCT_ID" ]
echo "CODEVALID_TEST_ASSERTION_OK:admin_add_product_all_fields_success"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
