#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
RESPONSE_FILE="/tmp/sample_buyer_account_login_denied_admin_access_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/sample_buyer_account_login_denied_admin_access_status_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

login_with() {
  email="$1"
  password="$2"
  token="$(curl -sS -X POST "$BASE_URL/api/auth/login" \
    -H 'Content-Type: application/json' \
    --data "{\"email\":\"${email}\",\"password\":\"${password}\"}" | jq -r '.token // empty')"
  [ -n "$token" ] || return 1
  printf '%s' "$token"
}

# Given
BUYER_TOKEN=""
for CRED in \
  'buyer@sample.com|BuyerPass!' \
  'buyer@example.com|buyer123' \
  'buyer@gptcoffee.test|buyer123'
do
  EMAIL="${CRED%%|*}"
  PASSWORD="${CRED##*|}"
  if TOKEN_TRY="$(login_with "$EMAIL" "$PASSWORD" 2>/dev/null)"; then
    BUYER_TOKEN="$TOKEN_TRY"
    break
  fi
done
[ -n "$BUYER_TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $BUYER_TOKEN" \
  --data "{\"name\":\"Buyer Attempt Product ${CASE_SUFFIX}\",\"price\":8}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "403" ] || [ "$STATUS" = "401" ]
echo "CODEVALID_TEST_ASSERTION_OK:sample_buyer_account_login_denied_admin_access"

# Cleanup
# No persistent side effects expected because the request is rejected.
