#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="/tmp/admin_retrieves_order_history_successfully-${CASE_SUFFIX}"
mkdir -p "$TMP_DIR"
LOGIN_RESPONSE="$TMP_DIR/login.json"
RESPONSE_FILE="$TMP_DIR/orders.json"
STATUS_FILE="$TMP_DIR/orders.status"
cleanup_files() { rm -rf "$TMP_DIR"; }
trap cleanup_files EXIT

# Given — authenticate as the built-in admin user
curl -sS -o "$LOGIN_RESPONSE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/login.status"
[ "$(cat "$TMP_DIR/login.status")" = "200" ]
TOKEN="$(jq -r '.token' "$LOGIN_RESPONSE")"
[ -n "$TOKEN" ]
[ "$TOKEN" != "null" ]

# When — request admin order history
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X GET "$BASE_URL/api/admin/orders" \
  -H "Authorization: Bearer $TOKEN" > "$STATUS_FILE"

# Then — response returns order history with expected structure
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
jq -e '.orders | type == "array"' "$RESPONSE_FILE" >/dev/null
jq -e '.orders | length >= 1' "$RESPONSE_FILE" >/dev/null
jq -e 'all(.orders[]; has("id") and has("items") and has("total") and has("status") and has("createdAt"))' "$RESPONSE_FILE" >/dev/null
grep -F '"orders"' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:admin_retrieves_order_history_successfully"

# Cleanup — no persistent side effects created by this test
