#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="coffee-cappuccino-002-${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/admin_partial_update_customization_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_partial_update_customization_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/admin_partial_update_customization_login_${CASE_SUFFIX}.json"
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

# Given — create a product with baseline fields that should be preserved
curl -sS -o /dev/null -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Cappuccino\",\"note\":\"Classic foam\",\"description\":\"Partial update preservation test\",\"price\":4.5,\"strength\":\"Balanced\",\"customizations\":{\"milk\":[\"whole\",\"skim\"],\"size\":[\"small\",\"medium\"]}}" > "$STATUS_FILE"
[ "$(cat "$STATUS_FILE")" = "201" ]

# When — patch only customization options
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X PATCH "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data '{"customizations":{"milk":["whole","skim","oat"],"size":["small","medium"]}}' > "$STATUS_FILE"

# Then — assert name and price remain unchanged while milk gains oat
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"id":"'"$PRODUCT_ID"'"' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"Cappuccino"' "$RESPONSE_FILE" >/dev/null
grep -F '"price":4.5' "$RESPONSE_FILE" >/dev/null
grep -F '"oat"' "$RESPONSE_FILE" >/dev/null

# Cleanup — delete the dedicated product
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$STATUS_FILE"
[ "$(cat "$STATUS_FILE")" = "204" ]

echo "CODEVALID_TEST_ASSERTION_OK:admin_partial_update_customization"
