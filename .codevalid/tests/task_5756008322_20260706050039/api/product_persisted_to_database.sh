#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="test-latte-123-${CASE_SUFFIX}"
LOGIN_FILE="/tmp/product_persisted_to_database_login_${CASE_SUFFIX}.json"
CREATE_FILE="/tmp/product_persisted_to_database_create_${CASE_SUFFIX}.json"
MENU_FILE="/tmp/product_persisted_to_database_menu_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$LOGIN_FILE" "$CREATE_FILE" "$MENU_FILE"
}
trap cleanup_files EXIT

# Given
STATUS="$(curl -sS -o "$LOGIN_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' --data '{"email":"admin@gptcoffee.test","password":"admin123"}')"
[ "$STATUS" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$LOGIN_FILE")"
[ "$ADMIN_TOKEN" != "null" ]

# When
STATUS="$(curl -sS -o "$CREATE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Test Latte\",\"price\":4.0,\"strength\":\"Mild\"}")"
MENU_STATUS="$(curl -sS -o "$MENU_FILE" -w '%{http_code}' "$BASE_URL/api/menu")"

# Then
[ "$STATUS" = "201" ]
[ "$MENU_STATUS" = "200" ]
jq -e --arg id "$PRODUCT_ID" '.product.id == $id' "$CREATE_FILE" >/dev/null
jq -e --arg id "$PRODUCT_ID" '.products[0].id == $id' "$MENU_FILE" >/dev/null
jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id and .name == "Test Latte" and .price == 4 and .strength == "Mild")' "$MENU_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:product_persisted_to_database"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/${PRODUCT_ID}" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
