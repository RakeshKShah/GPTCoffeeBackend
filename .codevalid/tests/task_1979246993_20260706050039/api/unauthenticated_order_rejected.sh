#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
RESPONSE_FILE="/tmp/unauthenticated_order_rejected_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/unauthenticated_order_rejected_status_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
ITEM_ID="prod-789-${CASE_SUFFIX}"

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  --data "{\"items\":[{\"id\":\"$ITEM_ID\",\"productId\":\"prod-789\",\"quantity\":3,\"total\":44.97}]}" \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "401" ]
jq -e '.message == "Missing or invalid session."' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_order_rejected"

# Cleanup
# Stateless negative test; no cleanup required.
