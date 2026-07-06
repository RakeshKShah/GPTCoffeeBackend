#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="$(mktemp -d)"
LOGIN_BODY="$TMP_DIR/buyer_login_${CASE_SUFFIX}.json"
FORBIDDEN_BODY="$TMP_DIR/forbidden_${CASE_SUFFIX}.json"
LOGIN_STATUS="$TMP_DIR/buyer_login_${CASE_SUFFIX}.status"
FORBIDDEN_STATUS="$TMP_DIR/forbidden_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
curl -sS \
  -o "$LOGIN_BODY" \
  -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"buyer@gptcoffee.test","password":"buyer123"}' > "$LOGIN_STATUS"

LOGIN_CODE="$(cat "$LOGIN_STATUS")"
[ "$LOGIN_CODE" = "200" ]
BUYER_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(data.token || '');" "$LOGIN_BODY")"
[ -n "$BUYER_TOKEN" ]
grep -F '"role":"buyer"' "$LOGIN_BODY" >/dev/null

# When
curl -sS \
  -o "$FORBIDDEN_BODY" \
  -w '%{http_code}' \
  -X GET "$BASE_URL/api/admin/orders" \
  -H "Authorization: Bearer $BUYER_TOKEN" > "$FORBIDDEN_STATUS"

# Then
FORBIDDEN_CODE="$(cat "$FORBIDDEN_STATUS")"
[ "$FORBIDDEN_CODE" = "403" ]
grep -F 'Admin access required.' "$FORBIDDEN_BODY" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:customer_denied_admin_orders_access"

# Cleanup
# No persistent side effects; login and rejected admin read are stateless.
