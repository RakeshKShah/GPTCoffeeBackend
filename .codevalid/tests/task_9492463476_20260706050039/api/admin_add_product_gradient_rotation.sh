#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
LOGIN_FILE="/tmp/admin_add_product_gradient_rotation_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/admin_add_product_gradient_rotation_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_add_product_gradient_rotation_status_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
ADMIN_TOKEN="$(curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
[ -n "$ADMIN_TOKEN" ]
EXPECTED_GRADIENT='from-rose-200 via-orange-600 to-stone-950'

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data '{"name":"Mocha Delight"}' > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
PRODUCT_ID="$(sed -n 's/.*"product":{[^}]*"id":"\([^"]*\)".*/\1/p' "$RESPONSE_FILE" | head -n 1)"
[ "$PRODUCT_ID" = "mocha-delight" ]
grep -F '"gradient":"'"$EXPECTED_GRADIENT"'"' "$RESPONSE_FILE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:admin_add_product_gradient_rotation"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
