#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EMAIL="frank.miller.${CASE_SUFFIX}@example.test"
PASSWORD="secret123"
RESPONSE_FILE_ONE="/tmp/verify_order_id_format_one_${CASE_SUFFIX}.json"
STATUS_FILE_ONE="/tmp/verify_order_id_format_one_${CASE_SUFFIX}.status"
RESPONSE_FILE_TWO="/tmp/verify_order_id_format_two_${CASE_SUFFIX}.json"
STATUS_FILE_TWO="/tmp/verify_order_id_format_two_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/verify_order_id_format_login_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$RESPONSE_FILE_ONE" "$STATUS_FILE_ONE" "$RESPONSE_FILE_TWO" "$STATUS_FILE_TWO" "$LOGIN_FILE"
}
trap cleanup_files EXIT

# Given
curl -sS -o /dev/null -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"Frank Miller\",\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"

curl -sS -o "$LOGIN_FILE" -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE_ONE" -w '%{http_code}' -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data '{"items":[{"name":"Iced Coffee","total":4.5}]}' \
  > "$STATUS_FILE_ONE"
sleep 1
curl -sS -o "$RESPONSE_FILE_TWO" -w '%{http_code}' -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data '{"items":[{"name":"Cold Brew","total":5.25}]}' \
  > "$STATUS_FILE_TWO"

# Then
STATUS_ONE="$(cat "$STATUS_FILE_ONE")"
STATUS_TWO="$(cat "$STATUS_FILE_TWO")"
[ "$STATUS_ONE" = "201" ]
[ "$STATUS_TWO" = "201" ]
ORDER_ID_ONE="$(sed -n 's/.*\"id\":\"\(ORD-[0-9][0-9][0-9][0-9][0-9][0-9]\)\".*/\1/p' "$RESPONSE_FILE_ONE")"
ORDER_ID_TWO="$(sed -n 's/.*\"id\":\"\(ORD-[0-9][0-9][0-9][0-9][0-9][0-9]\)\".*/\1/p' "$RESPONSE_FILE_TWO")"
[ -n "$ORDER_ID_ONE" ]
[ -n "$ORDER_ID_TWO" ]
[ "$ORDER_ID_ONE" != "$ORDER_ID_TWO" ]
grep -Eq '"buyerId":"[^"]+"' "$RESPONSE_FILE_ONE"
grep -Eq '"buyerId":"[^"]+"' "$RESPONSE_FILE_TWO"
grep -F '"buyerName":"Frank Miller"' "$RESPONSE_FILE_ONE" >/dev/null
grep -F '"buyerName":"Frank Miller"' "$RESPONSE_FILE_TWO" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:verify_order_id_format"

# Cleanup
# No explicit cleanup endpoint exists; test uses an isolated buyer account and unique order payload.
