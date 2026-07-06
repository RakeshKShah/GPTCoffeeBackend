#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="nonexistent-product-999-${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/admin_update_product_not_found_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_update_product_not_found_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/admin_update_product_not_found_login_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$LOGIN_FILE"
}
trap cleanup_files EXIT

admin_login() {
  curl -sS -o "$LOGIN_FILE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/auth/login" \
    -H 'Content-Type: application/json' \
    --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$STATUS_FILE"
  [ "$(cat "$STATUS_FILE")" = "200" ]
  node -e 'const fs=require("fs");const data=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));if(!data.token)process.exit(1);process.stdout.write(data.token);' "$LOGIN_FILE"
}

ADMIN_TOKEN="$(admin_login)"

# Given — use a unique product id that does not exist
:

# When — attempt to update a non-existent product
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X PATCH "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data '{"customizations":{"milk":["whole"]}}' > "$STATUS_FILE"

# Then — assert 404 and product-not-found message
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "404" ]
grep -F '"message":"Product not found."' "$RESPONSE_FILE" >/dev/null

# Cleanup — no persistent side effects expected for 404 update attempt

echo "CODEVALID_TEST_ASSERTION_OK:admin_update_product_not_found"
