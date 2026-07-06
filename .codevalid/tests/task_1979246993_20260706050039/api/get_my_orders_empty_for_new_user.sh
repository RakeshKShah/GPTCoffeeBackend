#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EMAIL="new-user-${CASE_SUFFIX}@example.test"
PASSWORD="secret${CASE_SUFFIX}"
SIGNUP_FILE="/tmp/get_my_orders_empty_for_new_user_${CASE_SUFFIX}_signup.json"
SIGNUP_STATUS_FILE="/tmp/get_my_orders_empty_for_new_user_${CASE_SUFFIX}_signup.status"
TOKEN_FILE="/tmp/get_my_orders_empty_for_new_user_${CASE_SUFFIX}.token"
ORDERS_FILE="/tmp/get_my_orders_empty_for_new_user_${CASE_SUFFIX}_orders.json"
ORDERS_STATUS_FILE="/tmp/get_my_orders_empty_for_new_user_${CASE_SUFFIX}_orders.status"
cleanup_files() {
  rm -f "$SIGNUP_FILE" "$SIGNUP_STATUS_FILE" "$TOKEN_FILE" "$ORDERS_FILE" "$ORDERS_STATUS_FILE"
}
trap cleanup_files EXIT

# Given — create a brand new buyer account through the public signup API
curl -sS -o "$SIGNUP_FILE" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"name\":\"New User ${CASE_SUFFIX}\",\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}" \
  "$BASE_URL/api/auth/signup" > "$SIGNUP_STATUS_FILE"
[ "$(cat "$SIGNUP_STATUS_FILE")" = "201" ]
node -e "const fs=require('fs');const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));if(!data.token) process.exit(1);process.stdout.write(data.token)" "$SIGNUP_FILE" > "$TOKEN_FILE"

# When — retrieve orders for the newly created user
curl -sS -o "$ORDERS_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer $(cat "$TOKEN_FILE")" \
  "$BASE_URL/api/orders/my" > "$ORDERS_STATUS_FILE"

# Then — the new user sees an empty orders array
[ "$(cat "$ORDERS_STATUS_FILE")" = "200" ]
grep -F '"user":{"role":"buyer"' "$SIGNUP_FILE"
grep -F '"orders":[]' "$ORDERS_FILE"

# Cleanup — no cleanup API exists for users; created account is uniquely namespaced to this test

echo 'CODEVALID_TEST_ASSERTION_OK:get_my_orders_empty_for_new_user'
