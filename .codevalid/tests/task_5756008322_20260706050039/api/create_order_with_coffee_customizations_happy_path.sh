#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EMAIL="jane.doe.${CASE_SUFFIX}@example.test"
PASSWORD="secret123"
RESPONSE_FILE="/tmp/create_order_with_coffee_customizations_happy_path_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/create_order_with_coffee_customizations_happy_path_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/create_order_with_coffee_customizations_happy_path_login_${CASE_SUFFIX}.json"
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
USER_ID="$(sed -n 's/.*"user":{[^}]*"id":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]
[ -n "$USER_ID" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data '{"items":[{"productId":"prod-101","name":"Latte","quantity":1,"total":5.75,"customizations":{"size":"large","milk":"oat","sweetness":"vanilla","extraShot":true}}]}' \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -E '"id":"ORD-[0-9]{6}"' "$RESPONSE_FILE" >/dev/null
grep -F '"buyerName":"Jane Doe"' "$RESPONSE_FILE" >/dev/null
grep -F "\"buyerId\":\"$USER_ID\"" "$RESPONSE_FILE" >/dev/null
grep -F '"status":"Placed"' "$RESPONSE_FILE" >/dev/null
grep -F '"total":5.75' "$RESPONSE_FILE" >/dev/null
grep -F '"productId":"prod-101"' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"Latte"' "$RESPONSE_FILE" >/dev/null
grep -F '"size":"large"' "$RESPONSE_FILE" >/dev/null
grep -F '"milk":"oat"' "$RESPONSE_FILE" >/dev/null
grep -F '"sweetness":"vanilla"' "$RESPONSE_FILE" >/dev/null
grep -F '"extraShot":true' "$RESPONSE_FILE" >/dev/null
CREATED_AT="$(sed -n 's/.*"createdAt":"\([^"]*\)".*/\1/p' "$RESPONSE_FILE")"
READY_AT="$(sed -n 's/.*"readyAt":"\([^"]*\)".*/\1/p' "$RESPONSE_FILE")"
[ -n "$CREATED_AT" ]
[ -n "$READY_AT" ]

echo "CODEVALID_TEST_ASSERTION_OK:create_order_with_coffee_customizations_happy_path"

# Cleanup
# No explicit cleanup endpoint exists; test uses an isolated buyer account and unique order payload.
