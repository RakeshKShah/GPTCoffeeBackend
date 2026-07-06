#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EMAIL="mike.johnson.${CASE_SUFFIX}@example.test"
PASSWORD="secret123"
RESPONSE_FILE="/tmp/verify_order_timestamps_and_status_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/verify_order_timestamps_and_status_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/verify_order_timestamps_and_status_login_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$LOGIN_FILE"
}
trap cleanup_files EXIT

# Given
START_EPOCH="$(date +%s)"
curl -sS -o /dev/null -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"Mike Johnson\",\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"

curl -sS -o "$LOGIN_FILE" -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data '{"items":[{"productId":"prod-111","name":"Cold Brew","quantity":1,"total":4.5,"customizations":{"size":"grande"}}]}' \
  > "$STATUS_FILE"
END_EPOCH="$(date +%s)"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -F '"status":"Placed"' "$RESPONSE_FILE" >/dev/null
CREATED_AT="$(sed -n 's/.*"createdAt":"\([^"]*\)".*/\1/p' "$RESPONSE_FILE")"
READY_AT="$(sed -n 's/.*"readyAt":"\([^"]*\)".*/\1/p' "$RESPONSE_FILE")"
[ -n "$CREATED_AT" ]
[ -n "$READY_AT" ]
CREATED_EPOCH="$(date -u -d "$CREATED_AT" +%s)"
READY_EPOCH="$(date -u -d "$READY_AT" +%s)"
[ "$CREATED_EPOCH" -ge "$START_EPOCH" ]
[ "$CREATED_EPOCH" -le $((END_EPOCH + 5)) ]
[ $((READY_EPOCH - CREATED_EPOCH)) -eq 900 ]

echo "CODEVALID_TEST_ASSERTION_OK:verify_order_timestamps_and_status"

# Cleanup
# No explicit cleanup endpoint exists; test uses an isolated buyer account and unique order payload.
