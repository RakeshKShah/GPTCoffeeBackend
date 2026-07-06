#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="sample-admin-product-${CASE_SUFFIX}"
LOGIN_FILE="/tmp/sample_admin_account_login_and_access_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/sample_admin_account_login_and_access_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/sample_admin_account_login_and_access_status_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
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
ADMIN_TOKEN=""
for CRED in \
  'admin@sample.com|AdminPass!' \
  'admin@example.com|admin123' \
  'admin@gptcoffee.test|admin123'
do
  EMAIL="${CRED%%|*}"
  PASSWORD="${CRED##*|}"
  if TOKEN_TRY="$(login_with "$EMAIL" "$PASSWORD" 2>/dev/null)"; then
    ADMIN_TOKEN="$TOKEN_TRY"
    break
  fi
done
[ -n "$ADMIN_TOKEN" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Sample Admin Product\",\"price\":20}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
jq -e --arg id "$PRODUCT_ID" '.product.id == $id' "$RESPONSE_FILE" >/dev/null
jq -e '.product.name == "Sample Admin Product"' "$RESPONSE_FILE" >/dev/null
jq -e '.product.price == 20' "$RESPONSE_FILE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:sample_admin_account_login_and_access"

# Cleanup
curl -sS -o /dev/null -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
