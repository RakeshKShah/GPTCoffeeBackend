#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="anonymous-coffee-${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/admin_add_product_unauthenticated_rejected_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_add_product_unauthenticated_rejected_status_${CASE_SUFFIX}.txt"
MENU_FILE="/tmp/admin_add_product_unauthenticated_rejected_menu_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$MENU_FILE"
}
trap cleanup_files EXIT

# Given
: "No authentication credentials are provided"

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Anonymous Coffee\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "401" ]
grep -E 'Missing or invalid session|Invalid session' "$RESPONSE_FILE" >/dev/null
curl -sS "$BASE_URL/api/menu" > "$MENU_FILE"
if grep -F '"id":"'"$PRODUCT_ID"'"' "$MENU_FILE" >/dev/null; then
  exit 1
fi
echo "CODEVALID_TEST_ASSERTION_OK:admin_add_product_unauthenticated_rejected"

# Cleanup
# No persistent side effects expected because authentication blocks creation.
