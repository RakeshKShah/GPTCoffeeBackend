#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="flat-white-${CASE_SUFFIX}"
LOGIN_FILE="/tmp/admin_add_product_appears_first_in_catalog_login_${CASE_SUFFIX}.json"
MENU_BEFORE_FILE="/tmp/admin_add_product_appears_first_in_catalog_menu_before_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/admin_add_product_appears_first_in_catalog_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_add_product_appears_first_in_catalog_status_${CASE_SUFFIX}.txt"
MENU_AFTER_FILE="/tmp/admin_add_product_appears_first_in_catalog_menu_after_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$LOGIN_FILE" "$MENU_BEFORE_FILE" "$RESPONSE_FILE" "$STATUS_FILE" "$MENU_AFTER_FILE"
}
trap cleanup_files EXIT

# Given
curl -sS "$BASE_URL/api/menu" > "$MENU_BEFORE_FILE"
FIRST_BEFORE="$(sed -n 's/.*"products":\[{"id":"\([^"]*\)".*/\1/p' "$MENU_BEFORE_FILE" | head -n 1)"
SECOND_BEFORE="$(sed -n 's/.*"products":\[{"id":"[^"]*"[^]]*},{"id":"\([^"]*\)".*/\1/p' "$MENU_BEFORE_FILE" | head -n 1)"
THIRD_BEFORE="$(sed -n 's/.*"products":\[{"id":"[^"]*"[^]]*},{"id":"[^"]*"[^]]*},{"id":"\([^"]*\)".*/\1/p' "$MENU_BEFORE_FILE" | head -n 1)"
ADMIN_TOKEN="$(curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
[ -n "$ADMIN_TOKEN" ]
[ -n "$FIRST_BEFORE" ]
[ -n "$SECOND_BEFORE" ]
[ -n "$THIRD_BEFORE" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Flat White\",\"price\":4}" > "$STATUS_FILE"
curl -sS "$BASE_URL/api/menu" > "$MENU_AFTER_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
FIRST_AFTER="$(sed -n 's/.*"products":\[{"id":"\([^"]*\)".*/\1/p' "$MENU_AFTER_FILE" | head -n 1)"
SECOND_AFTER="$(sed -n 's/.*"products":\[{"id":"[^"]*"[^]]*},{"id":"\([^"]*\)".*/\1/p' "$MENU_AFTER_FILE" | head -n 1)"
THIRD_AFTER="$(sed -n 's/.*"products":\[{"id":"[^"]*"[^]]*},{"id":"[^"]*"[^]]*},{"id":"\([^"]*\)".*/\1/p' "$MENU_AFTER_FILE" | head -n 1)"
FOURTH_AFTER="$(sed -n 's/.*"products":\[{"id":"[^"]*"[^]]*},{"id":"[^"]*"[^]]*},{"id":"[^"]*"[^]]*},{"id":"\([^"]*\)".*/\1/p' "$MENU_AFTER_FILE" | head -n 1)"
[ "$FIRST_AFTER" = "$PRODUCT_ID" ]
[ "$SECOND_AFTER" = "$FIRST_BEFORE" ]
[ "$THIRD_AFTER" = "$SECOND_BEFORE" ]
[ "$FOURTH_AFTER" = "$THIRD_BEFORE" ]
echo "CODEVALID_TEST_ASSERTION_OK:admin_add_product_appears_first_in_catalog"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
