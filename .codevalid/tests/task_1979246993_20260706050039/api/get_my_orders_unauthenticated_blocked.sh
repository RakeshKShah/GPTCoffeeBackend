#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
RESPONSE_FILE="/tmp/get_my_orders_unauthenticated_blocked_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/get_my_orders_unauthenticated_blocked_${CASE_SUFFIX}.status"
trap 'rm -f "$RESPONSE_FILE" "$STATUS_FILE"' EXIT

# Given — no authenticated session is provided

# When — request my orders without Authorization header
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  "$BASE_URL/api/orders/my" > "$STATUS_FILE"

# Then — access is blocked
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "401" ]
grep -E 'Missing or invalid session|Invalid session' "$RESPONSE_FILE"
if grep -F '"orders":' "$RESPONSE_FILE" >/dev/null 2>&1; then
  echo 'orders should not be returned for unauthenticated request'
  exit 1
fi

# Cleanup — no state created

echo 'CODEVALID_TEST_ASSERTION_OK:get_my_orders_unauthenticated_blocked'
