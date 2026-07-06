#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_NAME="Kenya AA Reserve ${CASE_SUFFIX}"
EXPECTED_ID="kenya-aa-reserve-${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/admin_product_id_slugify_fallback_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_product_id_slugify_fallback_status_${CASE_SUFFIX}.txt"
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
  --data "{\"name\":\"${PRODUCT_NAME}\",\"price\":22}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
jq -e --arg id "$EXPECTED_ID" '.product.id == $id' "$RESPONSE_FILE" >/dev/null
jq -e --arg name "$PRODUCT_NAME" '.product.name == $name' "$RESPONSE_FILE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:admin_product_id_slugify_fallback"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/$EXPECTED_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
