#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EMAIL="emma.garcia.${CASE_SUFFIX}@example.test"
PASSWORD="secret123"
RESPONSE_FILE="/tmp/verify_order_timestamp_calculations_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/verify_order_timestamp_calculations_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/verify_order_timestamp_calculations_login_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$LOGIN_FILE"
}
trap cleanup_files EXIT

# Given
curl -sS -o /dev/null -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"Emma Garcia\",\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"

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
  --data '{"items":[{"name":"Mocha Frappe","total":6}]}' \
  > "$STATUS_FILE"
END_TS="$(date -u +%s)"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -Eq '"buyerId":"[^"]+"' "$RESPONSE_FILE"
grep -F '"buyerName":"Emma Garcia"' "$RESPONSE_FILE" >/dev/null
CREATED_AT="$(sed -n 's/.*\"createdAt\":\"\([^\"]*\)\".*/\1/p' "$RESPONSE_FILE")"
READY_AT="$(sed -n 's/.*\"readyAt\":\"\([^\"]*\)\".*/\1/p' "$RESPONSE_FILE")"
[ -n "$CREATED_AT" ]
[ -n "$READY_AT" ]
CREATED_EPOCH="$(date -u -d "$CREATED_AT" +%s)"
READY_EPOCH="$(date -u -d "$READY_AT" +%s)"
[ "$CREATED_EPOCH" -ge "$START_TS" ]
[ "$CREATED_EPOCH" -le $((END_TS + 1)) ]
[ $((READY_EPOCH - CREATED_EPOCH)) -eq 900 ]

echo "CODEVALID_TEST_ASSERTION_OK:verify_order_timestamp_calculations"

# Cleanup
# No explicit cleanup endpoint exists; test uses an isolated buyer account and unique order payload.
