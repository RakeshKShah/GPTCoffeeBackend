#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
LOGIN_FILE="/tmp/admin_create_product_defaults_applied_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/admin_create_product_defaults_applied_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_create_product_defaults_applied_status_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
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
  --data '{"name":"Minimal Coffee"}' > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
PRODUCT_ID_ACTUAL="$(jq -r '.product.id // empty' "$RESPONSE_FILE")"
GRADIENT_VALUE="$(jq -r '.product.gradient // empty' "$RESPONSE_FILE")"
[ -n "$PRODUCT_ID_ACTUAL" ]
[ -n "$GRADIENT_VALUE" ]
jq -e '.product.name == "Minimal Coffee"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.price == 0' "$RESPONSE_FILE" >/dev/null
jq -e '.product.strength == "Balanced"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.note == ""' "$RESPONSE_FILE" >/dev/null
jq -e '.product.description == ""' "$RESPONSE_FILE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:admin_create_product_defaults_applied"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID_ACTUAL" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
