#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="/tmp/admin_sees_sales_performance_metrics-${CASE_SUFFIX}"
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

# Then — sales endpoint exposes metrics consistent with full order dataset
[ "$(cat "$TMP_DIR/orders.status")" = "200" ]
[ "$(cat "$TMP_DIR/sales.status")" = "200" ]
EXPECTED_TOTAL="$(jq -r '[.orders[].total] | add // 0' "$ORDERS_RESPONSE")"
EXPECTED_COUNT="$(jq -r '.orders | length' "$ORDERS_RESPONSE")"
ACTUAL_TOTAL="$(jq -r '.total' "$SALES_RESPONSE")"
ACTUAL_COUNT="$(jq -r '.orderCount' "$SALES_RESPONSE")"
[ "$ACTUAL_TOTAL" = "$EXPECTED_TOTAL" ]
[ "$ACTUAL_COUNT" = "$EXPECTED_COUNT" ]
jq -e '.daily | numbers and .monthly | numbers and .total | numbers and .orderCount | numbers' "$SALES_RESPONSE" >/dev/null
if [ "$ACTUAL_COUNT" -gt 0 ]; then
  AVG_VALUE="$(jq -n --arg total "$ACTUAL_TOTAL" --arg count "$ACTUAL_COUNT" '$total|tonumber / ($count|tonumber)')"
  [ "$AVG_VALUE" != "null" ]
fi

echo "CODEVALID_TEST_ASSERTION_OK:admin_sees_sales_performance_metrics"

# Cleanup — no persistent side effects created by this test
