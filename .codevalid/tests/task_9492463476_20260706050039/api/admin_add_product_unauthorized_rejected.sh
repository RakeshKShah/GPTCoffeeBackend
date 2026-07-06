#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="unauthorized-coffee-${CASE_SUFFIX}"
LOGIN_FILE="/tmp/admin_add_product_unauthorized_rejected_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/admin_add_product_unauthorized_rejected_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_add_product_unauthorized_rejected_status_${CASE_SUFFIX}.txt"
MENU_FILE="/tmp/admin_add_product_unauthorized_rejected_menu_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE" "$MENU_FILE"
}
trap cleanup_files EXIT

# Given
BUYER_TOKEN="$(curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"buyer@gptcoffee.test","password":"buyer123"}' \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
[ -n "$BUYER_TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $BUYER_TOKEN" \
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Unauthorized Coffee\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "403" ]
grep -F 'Admin access required.' "$RESPONSE_FILE" >/dev/null
curl -sS "$BASE_URL/api/menu" > "$MENU_FILE"
if grep -F '"id":"'"$PRODUCT_ID"'"' "$MENU_FILE" >/dev/null; then
  exit 1
fi
echo "CODEVALID_TEST_ASSERTION_OK:admin_add_product_unauthorized_rejected"

# Cleanup
# No persistent side effects expected because authorization blocks creation.
