#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="/tmp/admin_sees_daily_sales_aggregation-${CASE_SUFFIX}"
mkdir -p "$TMP_DIR"
LOGIN_RESPONSE="$TMP_DIR/login.json"
ORDERS_RESPONSE="$TMP_DIR/orders.json"
SALES_RESPONSE="$TMP_DIR/sales.json"
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

# When — retrieve order history and sales metrics
curl -sS -o "$ORDERS_RESPONSE" -w '%{http_code}' \
  -X GET "$BASE_URL/api/admin/orders" \
  -H "Authorization: Bearer $TOKEN" > "$TMP_DIR/orders.status"
curl -sS -o "$SALES_RESPONSE" -w '%{http_code}' \
  -X GET "$BASE_URL/api/admin/sales" \
  -H "Authorization: Bearer $TOKEN" > "$TMP_DIR/sales.status"

# Then — daily sales from /api/admin/sales matches aggregation derived from order history for today
[ "$(cat "$TMP_DIR/orders.status")" = "200" ]
[ "$(cat "$TMP_DIR/sales.status")" = "200" ]
jq -e '.orders | type == "array"' "$ORDERS_RESPONSE" >/dev/null
jq -e '.daily | numbers' "$SALES_RESPONSE" >/dev/null
EXPECTED_DAILY="$(jq -r '[.orders[] | select(((.createdAt | fromdateiso8601 | strftime("%Y-%m-%d")) == (now | strftime("%Y-%m-%d")))) | .total] | add // 0' "$ORDERS_RESPONSE")"
ACTUAL_DAILY="$(jq -r '.daily' "$SALES_RESPONSE")"
[ "$ACTUAL_DAILY" = "$EXPECTED_DAILY" ]

echo "CODEVALID_TEST_ASSERTION_OK:admin_sees_daily_sales_aggregation"

# Cleanup — no persistent side effects created by this test
