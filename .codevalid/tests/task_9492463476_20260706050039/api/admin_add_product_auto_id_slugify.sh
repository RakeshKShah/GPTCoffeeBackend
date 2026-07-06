#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EXPECTED_ID="iced-caramel-macchiato"
LOGIN_FILE="/tmp/admin_add_product_auto_id_slugify_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/admin_add_product_auto_id_slugify_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_add_product_auto_id_slugify_status_${CASE_SUFFIX}.txt"
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

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data '{"name":"Iced Caramel Macchiato"}' > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -F '"id":"'"$EXPECTED_ID"'"' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"Iced Caramel Macchiato"' "$RESPONSE_FILE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:admin_add_product_auto_id_slugify"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/$EXPECTED_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
