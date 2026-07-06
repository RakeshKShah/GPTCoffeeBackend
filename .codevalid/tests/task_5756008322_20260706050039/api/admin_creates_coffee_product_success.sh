#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="cappuccino-001-${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/admin_creates_coffee_product_success_${CASE_SUFFIX}.json"
STATUS="$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' --data '{"email":"admin@gptcoffee.test","password":"admin123"}')"
LOGIN_FILE="/tmp/admin_creates_coffee_product_success_login_${CASE_SUFFIX}.json"
mv "$RESPONSE_FILE" "$LOGIN_FILE"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$LOGIN_FILE"
}
trap cleanup_files EXIT

# Given
[ "$STATUS" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$LOGIN_FILE")"
[ "$ADMIN_TOKEN" != "null" ]

# When
STATUS="$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Classic Cappuccino\",\"note\":\"House favorite\",\"description\":\"Rich espresso with steamed milk foam\",\"price\":4.5,\"strength\":\"Strong\",\"gradient\":\"coffee-gradient-warm\"}")"

# Then
[ "$STATUS" = "201" ]
jq -e --arg id "$PRODUCT_ID" '.product.id == $id' "$RESPONSE_FILE" >/dev/null
jq -e '.product.name == "Classic Cappuccino"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.note == "House favorite"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.description == "Rich espresso with steamed milk foam"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.price == 4.5' "$RESPONSE_FILE" >/dev/null
jq -e '.product.strength == "Strong"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.gradient == "coffee-gradient-warm"' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:admin_creates_coffee_product_success"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/${PRODUCT_ID}" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
