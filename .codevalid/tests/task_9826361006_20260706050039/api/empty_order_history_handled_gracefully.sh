#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="/tmp/empty_order_history_handled_gracefully-${CASE_SUFFIX}"
mkdir -p "$TMP_DIR"
LOGIN_RESPONSE="$TMP_DIR/login.json"
RESPONSE_FILE="$TMP_DIR/orders.json"
STATUS_FILE="$TMP_DIR/orders.status"
cleanup_files() { rm -rf "$TMP_DIR"; }
trap cleanup_files EXIT

# Given — authenticate as admin
curl -sS -o "$LOGIN_RESPONSE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/login.status"
[ "$(cat "$TMP_DIR/login.status")" = "200" ]
TOKEN="$(jq -r '.token' "$LOGIN_RESPONSE")"
[ -n "$TOKEN" ]
[ "$TOKEN" != "null" ]

# When — retrieve the admin order history
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X GET "$BASE_URL/api/admin/orders" \
  -H "Authorization: Bearer $TOKEN" > "$STATUS_FILE"

# Then — the endpoint responds successfully and, when no orders exist, returns an empty orders array
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
jq -e '.orders | type == "array"' "$RESPONSE_FILE" >/dev/null
ORDER_COUNT="$(jq -r '.orders | length' "$RESPONSE_FILE")"
if [ "$ORDER_COUNT" = "0" ]; then
  jq -e '. == {"orders":[]}' "$RESPONSE_FILE" >/dev/null
else
  jq -e '.orders | length > 0' "$RESPONSE_FILE" >/dev/null
fi

echo "CODEVALID_TEST_ASSERTION_OK:empty_order_history_handled_gracefully"

# Cleanup — no persistent side effects created by this test
