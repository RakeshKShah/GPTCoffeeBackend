#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
SIGNUP_FILE="/tmp/multiple_items_total_calculation_signup_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/multiple_items_total_calculation_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/multiple_items_total_calculation_status_${CASE_SUFFIX}.txt"
MY_ORDERS_FILE="/tmp/multiple_items_total_calculation_my_orders_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$SIGNUP_FILE" "$RESPONSE_FILE" "$STATUS_FILE" "$MY_ORDERS_FILE"
}
trap cleanup_files EXIT

# Given
EMAIL="multi-items-${CASE_SUFFIX}@example.test"
SIGNUP_STATUS="$(curl -sS -o "$SIGNUP_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"Charlie Buyer ${CASE_SUFFIX}\",\"email\":\"$EMAIL\",\"password\":\"secret1\"}")"
[ "$SIGNUP_STATUS" = "201" ]
TOKEN="$(jq -r '.token' "$SIGNUP_FILE")"
USER_ID="$(jq -r '.user.id' "$SIGNUP_FILE")"
USER_NAME="$(jq -r '.user.name' "$SIGNUP_FILE")"
[ -n "$TOKEN" ]
[ "$TOKEN" != "null" ]
FIRST_ITEM_ID="prod-111-${CASE_SUFFIX}"
SECOND_ITEM_ID="prod-222-${CASE_SUFFIX}"

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data "{\"items\":[{\"id\":\"$FIRST_ITEM_ID\",\"productId\":\"prod-111\",\"quantity\":2,\"total\":12.5},{\"id\":\"$SECOND_ITEM_ID\",\"productId\":\"prod-222\",\"quantity\":1,\"total\":7.25}]}" \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
jq -e --arg user_id "$USER_ID" '.order.buyerId == $user_id' "$RESPONSE_FILE" >/dev/null
jq -e --arg user_name "$USER_NAME" '.order.buyerName == $user_name' "$RESPONSE_FILE" >/dev/null
jq -e '.order.status == "Placed"' "$RESPONSE_FILE" >/dev/null
jq -e '.order.total == 19.75' "$RESPONSE_FILE" >/dev/null
jq -e '.order.items | length == 2' "$RESPONSE_FILE" >/dev/null
jq -e --arg first_item_id "$FIRST_ITEM_ID" --arg second_item_id "$SECOND_ITEM_ID" '.order.items[0].id == $first_item_id and .order.items[1].id == $second_item_id' "$RESPONSE_FILE" >/dev/null
ORDER_ID="$(jq -r '.order.id' "$RESPONSE_FILE")"
[ -n "$ORDER_ID" ]
[ "$ORDER_ID" != "null" ]
MY_STATUS="$(curl -sS -o "$MY_ORDERS_FILE" -w '%{http_code}' \
  -X GET "$BASE_URL/api/orders/my" \
  -H "Authorization: Bearer $TOKEN")"
[ "$MY_STATUS" = "200" ]
jq -e --arg order_id "$ORDER_ID" '.orders | map(select(.id == $order_id and .total == 19.75 and (.items | length == 2))) | length >= 1' "$MY_ORDERS_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:multiple_items_total_calculation"

# Cleanup
# No public user/order deletion endpoints exist; created data is isolated by unique email and item ids.
