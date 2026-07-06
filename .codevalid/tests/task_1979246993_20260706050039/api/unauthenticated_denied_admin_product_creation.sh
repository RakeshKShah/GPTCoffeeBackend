#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
RESPONSE_FILE="/tmp/unauthenticated_denied_admin_product_creation_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/unauthenticated_denied_admin_product_creation_status_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
PRODUCT_NAME="Anonymous Product ${CASE_SUFFIX}"

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"${PRODUCT_NAME}\",\"price\":15}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "401" ]
echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_denied_admin_product_creation"

# Cleanup
# No persistent side effects expected because the request is rejected.
