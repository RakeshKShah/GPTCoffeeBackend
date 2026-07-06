#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="type-test-coffee-${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/admin_product_price_numeric_conversion_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_product_price_numeric_conversion_status_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
ADMIN_TOKEN="$(curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@example.com","password":"admin123"}' | jq -r '.token // empty')"
[ -n "$ADMIN_TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Type Test Coffee\",\"price\":\"19.99\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
jq -e --arg id "$PRODUCT_ID" '.product.id == $id' "$RESPONSE_FILE" >/dev/null
jq -e '.product.name == "Type Test Coffee"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.price == 19.99' "$RESPONSE_FILE" >/dev/null
jq -e '(.product.price | type) == "number"' "$RESPONSE_FILE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:admin_product_price_numeric_conversion"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
