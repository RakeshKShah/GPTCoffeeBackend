#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
SIGNUP_FILE="/tmp/order_validation_missing_items_field_signup_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/order_validation_missing_items_field_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/order_validation_missing_items_field_status_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$SIGNUP_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
EMAIL="missing-items-${CASE_SUFFIX}@example.test"
SIGNUP_STATUS="$(curl -sS -o "$SIGNUP_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"Missing Items ${CASE_SUFFIX}\",\"email\":\"$EMAIL\",\"password\":\"secret1\"}")"
[ "$SIGNUP_STATUS" = "201" ]
TOKEN="$(jq -r '.token' "$SIGNUP_FILE")"
[ -n "$TOKEN" ]
[ "$TOKEN" != "null" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  --data '{}' \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "400" ]
jq -e '.message == "Order must include at least one item."' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:order_validation_missing_items_field"

# Cleanup
# No public user deletion endpoint exists; the created account is isolated by unique email.
