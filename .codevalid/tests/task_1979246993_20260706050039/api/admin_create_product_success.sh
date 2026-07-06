#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="ethiopian-roast-${CASE_SUFFIX}"
LOGIN_FILE="/tmp/admin_create_product_success_login_${CASE_SUFFIX}.json"
LOGIN_STATUS_FILE="/tmp/admin_create_product_success_login_status_${CASE_SUFFIX}.txt"
RESPONSE_FILE="/tmp/admin_create_product_success_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_create_product_success_status_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$LOGIN_FILE" "$LOGIN_STATUS_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
curl -sS -o "$LOGIN_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@example.com","password":"admin123"}' > "$LOGIN_STATUS_FILE"
LOGIN_STATUS="$(cat "$LOGIN_STATUS_FILE")"
[ "$LOGIN_STATUS" = "200" ]
ADMIN_TOKEN="$(jq -r '.token // empty' "$LOGIN_FILE")"
[ -n "$ADMIN_TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Ethiopian Roast\",\"description\":\"Rich single-origin coffee\",\"price\":14.99,\"strength\":\"Strong\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
jq -e --arg id "$PRODUCT_ID" '.product.id == $id' "$RESPONSE_FILE" >/dev/null
jq -e '.product.name == "Ethiopian Roast"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.description == "Rich single-origin coffee"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.price == 14.99' "$RESPONSE_FILE" >/dev/null
jq -e '.product.strength == "Strong"' "$RESPONSE_FILE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:admin_create_product_success"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
