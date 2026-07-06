#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="/tmp/unauthenticated_user_blocked_from_orders-${CASE_SUFFIX}"
mkdir -p "$TMP_DIR"
RESPONSE_FILE="$TMP_DIR/unauthorized.json"
STATUS_FILE="$TMP_DIR/unauthorized.status"
cleanup_files() { rm -rf "$TMP_DIR"; }
trap cleanup_files EXIT

# Given — do not provide any authentication credentials
: > /dev/null

# When — request admin orders without a session
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X GET "$BASE_URL/api/admin/orders" > "$STATUS_FILE"

# Then — auth middleware rejects the request with 401 and no order payload
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "401" ]
grep -E 'Missing or invalid session|Invalid session' "$RESPONSE_FILE" >/dev/null
if grep -F '"orders"' "$RESPONSE_FILE" >/dev/null; then
  exit 1
fi

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_user_blocked_from_orders"

# Cleanup — no persistent side effects created by this test
