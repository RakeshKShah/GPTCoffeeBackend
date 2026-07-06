#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_NAME="Forbidden Coffee ${CASE_SUFFIX}"
LOGIN_FILE="/tmp/non_admin_user_cannot_create_product_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/non_admin_user_cannot_create_product_${CASE_SUFFIX}.json"
MENU_FILE="/tmp/non_admin_user_cannot_create_product_menu_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$MENU_FILE"
}
trap cleanup_files EXIT

# Given
STATUS="$(curl -sS -o "$LOGIN_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' --data '{"email":"buyer@gptcoffee.test","password":"buyer123"}')"
[ "$STATUS" = "200" ]
BUYER_TOKEN="$(jq -r '.token' "$LOGIN_FILE")"
[ "$BUYER_TOKEN" != "null" ]

# When
STATUS="$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $BUYER_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"${PRODUCT_NAME}\",\"price\":10.0}")"

# Then
[ "$STATUS" = "403" ]
jq -e '.message == "Admin access required."' "$RESPONSE_FILE" >/dev/null
MENU_STATUS="$(curl -sS -o "$MENU_FILE" -w '%{http_code}' "$BASE_URL/api/menu")"
[ "$MENU_STATUS" = "200" ]
if jq -e --arg name "$PRODUCT_NAME" '.products[] | select(.name == $name)' "$MENU_FILE" >/dev/null; then
  echo "Non-admin product should not have been created" >&2
  exit 1
fi

echo "CODEVALID_TEST_ASSERTION_OK:non_admin_user_cannot_create_product"
