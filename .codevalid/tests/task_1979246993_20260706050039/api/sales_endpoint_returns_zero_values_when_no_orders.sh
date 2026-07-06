#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
BUYER_EMAIL="zero-orders-${CASE_SUFFIX}@example.test"
BUYER_NAME="Zero Orders ${CASE_SUFFIX}"
BUYER_PASSWORD="buyer12345"
TMP_DIR="/tmp/sales_endpoint_returns_zero_values_when_no_orders-${CASE_SUFFIX}"
mkdir -p "$TMP_DIR"
SIGNUP_BODY="$TMP_DIR/signup.json"
ORDERS_BODY="$TMP_DIR/orders.json"
ORDERS_STATUS="$TMP_DIR/orders.status"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
SIGNUP_PAYLOAD=$(printf '{"name":"%s","email":"%s","password":"%s"}' "$BUYER_NAME" "$BUYER_EMAIL" "$BUYER_PASSWORD")
SIGNUP_STATUS="$(curl -sS -o "$SIGNUP_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "$SIGNUP_PAYLOAD")"
[ "$SIGNUP_STATUS" = "201" ]
BUYER_TOKEN="$(jq -r '.token' "$SIGNUP_BODY")"
[ -n "$BUYER_TOKEN" ]
[ "$BUYER_TOKEN" != "null" ]
grep -F '"role":"buyer"' "$SIGNUP_BODY" >/dev/null

# When
curl -sS -o "$ORDERS_BODY" -w '%{http_code}' -X GET "$BASE_URL/api/orders/my" \
  -H "Authorization: Bearer $BUYER_TOKEN" > "$ORDERS_STATUS"

# Then
STATUS="$(cat "$ORDERS_STATUS")"
[ "$STATUS" = "200" ]
grep -F '"orders":[]' "$ORDERS_BODY" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:sales_endpoint_returns_zero_values_when_no_orders"

# Cleanup
# No cleanup endpoint exists for users created via signup in this service.
