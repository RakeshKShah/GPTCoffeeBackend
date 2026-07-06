#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="$(mktemp -d)"
LOGIN_BODY="$TMP_DIR/admin_login_${CASE_SUFFIX}.json"
ORDERS_BODY="$TMP_DIR/admin_orders_${CASE_SUFFIX}.json"
LOGIN_STATUS="$TMP_DIR/admin_login_${CASE_SUFFIX}.status"
ORDERS_STATUS="$TMP_DIR/admin_orders_${CASE_SUFFIX}.status"
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
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$LOGIN_STATUS"

LOGIN_CODE="$(cat "$LOGIN_STATUS")"
[ "$LOGIN_CODE" = "200" ]
ADMIN_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(data.token || '');" "$LOGIN_BODY")"
[ -n "$ADMIN_TOKEN" ]
grep -F '"role":"admin"' "$LOGIN_BODY" >/dev/null

# When
curl -sS \
  -o "$ORDERS_BODY" \
  -w '%{http_code}' \
  -X GET "$BASE_URL/api/admin/orders" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$ORDERS_STATUS"

# Then
ORDERS_CODE="$(cat "$ORDERS_STATUS")"
[ "$ORDERS_CODE" = "200" ]
grep -F '"orders":[' "$ORDERS_BODY" >/dev/null
grep -F '"id":"ORD-1001"' "$ORDERS_BODY" >/dev/null
grep -F '"id":"ORD-1000"' "$ORDERS_BODY" >/dev/null
ORDER_COUNT="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(String(Array.isArray(data.orders) ? data.orders.length : -1));" "$ORDERS_BODY")"
[ "$ORDER_COUNT" -ge 2 ]

echo "CODEVALID_TEST_ASSERTION_OK:admin_access_orders_success"

# Cleanup
# No persistent side effects; login and admin read are stateless.
