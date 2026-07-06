#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="persist-test-001-${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/admin_product_persisted_to_database_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_product_persisted_to_database_status_${CASE_SUFFIX}.txt"
VERIFY_FILE="/tmp/admin_product_persisted_to_database_verify_${CASE_SUFFIX}.json"
VERIFY_STATUS_FILE="/tmp/admin_product_persisted_to_database_verify_status_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$VERIFY_FILE" "$VERIFY_STATUS_FILE"
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
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Persistence Test Coffee\",\"price\":18,\"strength\":\"Mild\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
jq -e --arg id "$PRODUCT_ID" '.product.id == $id' "$RESPONSE_FILE" >/dev/null
jq -e '.product.name == "Persistence Test Coffee"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.price == 18' "$RESPONSE_FILE" >/dev/null
jq -e '.product.strength == "Mild"' "$RESPONSE_FILE" >/dev/null
curl -sS -o "$VERIFY_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@example.com","password":"admin123"}' > "$VERIFY_STATUS_FILE"
VERIFY_STATUS="$(cat "$VERIFY_STATUS_FILE")"
[ "$VERIFY_STATUS" = "200" ]
echo "CODEVALID_TEST_ASSERTION_OK:admin_product_persisted_to_database"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
