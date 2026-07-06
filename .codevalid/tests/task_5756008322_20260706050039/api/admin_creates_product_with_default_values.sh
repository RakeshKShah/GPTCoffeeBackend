#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_NAME="Espresso Shot ${CASE_SUFFIX}"
EXPECTED_ID="espresso-shot-${CASE_SUFFIX}"
LOGIN_FILE="/tmp/admin_creates_product_with_default_values_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/admin_creates_product_with_default_values_${CASE_SUFFIX}.json"
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
  --data "{\"name\":\"${PRODUCT_NAME}\",\"price\":2.5}")"

# Then
[ "$STATUS" = "201" ]
jq -e --arg id "$EXPECTED_ID" '.product.id == $id' "$RESPONSE_FILE" >/dev/null
jq -e '.product.note == ""' "$RESPONSE_FILE" >/dev/null
jq -e '.product.description == ""' "$RESPONSE_FILE" >/dev/null
jq -e '.product.strength == "Balanced"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.price == 2.5' "$RESPONSE_FILE" >/dev/null
GRADIENT="$(jq -r '.product.gradient' "$RESPONSE_FILE")"
[ -n "$GRADIENT" ]
[ "$GRADIENT" != "null" ]
CREATED_ID="$(jq -r '.product.id' "$RESPONSE_FILE")"

echo "CODEVALID_TEST_ASSERTION_OK:admin_creates_product_with_default_values"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/${CREATED_ID}" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
