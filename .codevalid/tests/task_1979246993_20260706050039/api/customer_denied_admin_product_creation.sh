#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
RESPONSE_FILE="/tmp/customer_denied_admin_product_creation_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/customer_denied_admin_product_creation_status_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

login_try() {
  EMAIL="$1"
  PASSWORD="$2"
  curl -sS -X POST "$BASE_URL/api/auth/login" \
    -H 'Content-Type: application/json' \
    --data "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}" | jq -r '.token // empty'
}

# Given
BUYER_TOKEN="$(login_try 'buyer@example.com' 'buyer123')"
if [ -z "$BUYER_TOKEN" ]; then
  BUYER_TOKEN="$(login_try 'buyer@gptcoffee.test' 'buyer123')"
fi
[ -n "$BUYER_TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $BUYER_TOKEN" \
  --data "{\"name\":\"Unauthorized Product ${CASE_SUFFIX}\",\"price\":10}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "403" ] || [ "$STATUS" = "401" ]
echo "CODEVALID_TEST_ASSERTION_OK:customer_denied_admin_product_creation"

# Cleanup
# No persistent side effects expected because the request is rejected.
