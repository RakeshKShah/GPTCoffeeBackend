#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_NAME="Unauthorized Coffee ${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/unauthenticated_user_cannot_create_product_${CASE_SUFFIX}.json"
MENU_FILE="/tmp/unauthenticated_user_cannot_create_product_menu_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$MENU_FILE"
}
trap cleanup_files EXIT

# Given
: "No authentication credentials are provided"

# When
STATUS="$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"${PRODUCT_NAME}\",\"price\":1.0}")"

# Then
[ "$STATUS" = "401" ]
jq -e '.message == "Missing or invalid session."' "$RESPONSE_FILE" >/dev/null
MENU_STATUS="$(curl -sS -o "$MENU_FILE" -w '%{http_code}' "$BASE_URL/api/menu")"
[ "$MENU_STATUS" = "200" ]
if jq -e --arg name "$PRODUCT_NAME" '.products[] | select(.name == $name)' "$MENU_FILE" >/dev/null; then
  echo "Unauthorized product should not have been created" >&2
  exit 1
fi

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_user_cannot_create_product"
