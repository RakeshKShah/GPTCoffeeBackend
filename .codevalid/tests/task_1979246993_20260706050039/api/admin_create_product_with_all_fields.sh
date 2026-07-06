#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="full-spec-123-${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/admin_create_product_with_all_fields_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_create_product_with_all_fields_status_${CASE_SUFFIX}.txt"
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
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Colombian Supreme\",\"note\":\"Limited batch\",\"description\":\"Premium single-origin from Colombia\",\"price\":24.99,\"strength\":\"Strong\",\"gradient\":\"dark-roast\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
jq -e --arg id "$PRODUCT_ID" '.product.id == $id' "$RESPONSE_FILE" >/dev/null
jq -e '.product.name == "Colombian Supreme"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.note == "Limited batch"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.description == "Premium single-origin from Colombia"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.price == 24.99' "$RESPONSE_FILE" >/dev/null
jq -e '.product.strength == "Strong"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.gradient == "dark-roast"' "$RESPONSE_FILE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:admin_create_product_with_all_fields"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
