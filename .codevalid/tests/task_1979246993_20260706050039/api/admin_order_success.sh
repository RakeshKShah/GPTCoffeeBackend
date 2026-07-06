#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
LOGIN_FILE="/tmp/admin_order_success_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/admin_order_success_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_order_success_status_${CASE_SUFFIX}.txt"
MY_ORDERS_FILE="/tmp/admin_order_success_my_orders_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE" "$MY_ORDERS_FILE"
}
trap cleanup_files EXIT

# Given
LOGIN_STATUS="$(curl -sS -o "$LOGIN_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}')"
[ "$LOGIN_STATUS" = "200" ]
TOKEN="$(jq -r '.token' "$LOGIN_FILE")"
[ -n "$TOKEN" ]
[ "$TOKEN" != "null" ]
ITEM_ID="prod-456-${CASE_SUFFIX}"

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data "{\"items\":[{\"id\":\"$ITEM_ID\",\"productId\":\"prod-456\",\"quantity\":1,\"total\":19.5}]}" \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
jq -e '.order.buyerId == "admin-sample"' "$RESPONSE_FILE" >/dev/null
jq -e '.order.buyerName == "Ari Admin"' "$RESPONSE_FILE" >/dev/null
jq -e '.order.status == "Placed"' "$RESPONSE_FILE" >/dev/null
jq -e '.order.total == 19.5' "$RESPONSE_FILE" >/dev/null
jq -e --arg item_id "$ITEM_ID" '.order.items[0].id == $item_id' "$RESPONSE_FILE" >/dev/null
ORDER_ID="$(jq -r '.order.id' "$RESPONSE_FILE")"
[ -n "$ORDER_ID" ]
[ "$ORDER_ID" != "null" ]
MY_STATUS="$(curl -sS -o "$MY_ORDERS_FILE" -w '%{http_code}' \
  -X GET "$BASE_URL/api/orders/my" \
  -H "Authorization: Bearer $TOKEN")"
[ "$MY_STATUS" = "200" ]
jq -e --arg order_id "$ORDER_ID" '.orders | map(select(.id == $order_id and .buyerId == "admin-sample" and .buyerName == "Ari Admin" and .status == "Placed" and .total == 19.5)) | length >= 1' "$MY_ORDERS_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:admin_order_success"

# Cleanup
# No public order deletion endpoint exists; this test uses unique item/order identifiers for isolation.
