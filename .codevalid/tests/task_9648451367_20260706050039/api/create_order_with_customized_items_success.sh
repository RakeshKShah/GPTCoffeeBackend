#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EMAIL="jane.doe.${CASE_SUFFIX}@example.test"
PASSWORD="secret123"
RESPONSE_FILE="/tmp/create_order_with_customized_items_success_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/create_order_with_customized_items_success_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/create_order_with_customized_items_success_login_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$LOGIN_FILE"
}
trap cleanup_files EXIT

# Given
curl -sS -o /dev/null -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"Jane Doe\",\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"

curl -sS -o "$LOGIN_FILE" -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]
START_TS="$(date -u +%s)"

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data '{"items":[{"name":"Caramel Latte","size":"Large","total":5.5},{"name":"Dark Roast Americano","size":"Medium","total":4.25},{"name":"Vanilla Cappuccino","size":"Large","total":6.75}]}' \
  > "$STATUS_FILE"
END_TS="$(date -u +%s)"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -Eq '"id":"ORD-[0-9]{6}"' "$RESPONSE_FILE"
grep -Eq '"buyerId":"[^"]+"' "$RESPONSE_FILE"
grep -F '"buyerName":"Jane Doe"' "$RESPONSE_FILE" >/dev/null
grep -F '"status":"Placed"' "$RESPONSE_FILE" >/dev/null
grep -F '"total":16.5' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"Caramel Latte"' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"Dark Roast Americano"' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"Vanilla Cappuccino"' "$RESPONSE_FILE" >/dev/null
grep -F '"size":"Large"' "$RESPONSE_FILE" >/dev/null
grep -F '"size":"Medium"' "$RESPONSE_FILE" >/dev/null
CREATED_AT="$(sed -n 's/.*\"createdAt\":\"\([^\"]*\)\".*/\1/p' "$RESPONSE_FILE")"
READY_AT="$(sed -n 's/.*\"readyAt\":\"\([^\"]*\)\".*/\1/p' "$RESPONSE_FILE")"
[ -n "$CREATED_AT" ]
[ -n "$READY_AT" ]
CREATED_EPOCH="$(date -u -d "$CREATED_AT" +%s)"
READY_EPOCH="$(date -u -d "$READY_AT" +%s)"
[ "$CREATED_EPOCH" -ge "$START_TS" ]
[ "$CREATED_EPOCH" -le $((END_TS + 1)) ]
[ $((READY_EPOCH - CREATED_EPOCH)) -eq 900 ]

echo "CODEVALID_TEST_ASSERTION_OK:create_order_with_customized_items_success"

# Cleanup
# No explicit cleanup endpoint exists; test uses an isolated buyer account and unique order payload.
