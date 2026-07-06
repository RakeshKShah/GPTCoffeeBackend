#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
RESPONSE_FILE="/tmp/reject_unauthenticated_order_creation_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/reject_unauthenticated_order_creation_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
# No valid authentication token is provided.

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  --data '{"items":[{"productId":"prod-101","name":"Latte","quantity":1,"total":5.75,"customizations":{"size":"large"}}]}' \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "401" ]
grep -E '"message":"(Missing or invalid session\.|Invalid session\.)"' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:reject_unauthenticated_order_creation"

# Cleanup
# Stateless negative test; no order is created.
