#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="persian-coffee-${CASE_SUFFIX}"
LOGIN_FILE="/tmp/admin_add_product_persisted_to_database_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/admin_add_product_persisted_to_database_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_add_product_persisted_to_database_status_${CASE_SUFFIX}.txt"
MENU_ONE_FILE="/tmp/admin_add_product_persisted_to_database_menu_one_${CASE_SUFFIX}.json"
MENU_TWO_FILE="/tmp/admin_add_product_persisted_to_database_menu_two_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE" "$MENU_ONE_FILE" "$MENU_TWO_FILE"
}
trap cleanup_files EXIT

# Given
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
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Persian Coffee\",\"price\":5.5}" > "$STATUS_FILE"
curl -sS "$BASE_URL/api/menu" > "$MENU_ONE_FILE"
sleep 1
curl -sS "$BASE_URL/api/menu" > "$MENU_TWO_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -F '"id":"'"$PRODUCT_ID"'"' "$RESPONSE_FILE" >/dev/null
grep -F '"price":5.5' "$RESPONSE_FILE" >/dev/null
grep -F '"id":"'"$PRODUCT_ID"'"' "$MENU_ONE_FILE" >/dev/null
grep -F '"name":"Persian Coffee"' "$MENU_ONE_FILE" >/dev/null
grep -F '"id":"'"$PRODUCT_ID"'"' "$MENU_TWO_FILE" >/dev/null
grep -F '"name":"Persian Coffee"' "$MENU_TWO_FILE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:admin_add_product_persisted_to_database"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
