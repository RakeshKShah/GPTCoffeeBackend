#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_NAME="Extra Strong Brew ${CASE_SUFFIX}"
LOGIN_FILE="/tmp/admin_creates_product_with_custom_strength_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/admin_creates_product_with_custom_strength_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE"
}
trap cleanup_files EXIT

# Given
STATUS="$(curl -sS -o "$LOGIN_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' --data '{"email":"admin@gptcoffee.test","password":"admin123"}')"
[ "$STATUS" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$LOGIN_FILE")"
[ "$ADMIN_TOKEN" != "null" ]

# When
STATUS="$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"${PRODUCT_NAME}\",\"price\":5.5,\"strength\":\"Extra Strong\"}")"

# Then
[ "$STATUS" = "201" ]
jq -e '.product.strength == "Extra Strong"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.price == 5.5' "$RESPONSE_FILE" >/dev/null
CREATED_ID="$(jq -r '.product.id' "$RESPONSE_FILE")"

echo "CODEVALID_TEST_ASSERTION_OK:admin_creates_product_with_custom_strength"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/${CREATED_ID}" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
