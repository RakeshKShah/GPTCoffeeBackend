#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="coffee-espresso-003-${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/admin_update_product_price_conversion_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_update_product_price_conversion_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/admin_update_product_price_conversion_login_${CASE_SUFFIX}.json"
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

# Given — create a product with an initial numeric price
curl -sS -o /dev/null -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Espresso ${CASE_SUFFIX}\",\"note\":\"Double shot\",\"description\":\"Price conversion test\",\"price\":3,\"strength\":\"Bold\"}" > "$STATUS_FILE"
[ "$(cat "$STATUS_FILE")" = "201" ]

# When — update price using a string payload value
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X PATCH "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data '{"price":"3.75","customizations":{"size":["single","double"]}}' > "$STATUS_FILE"

# Then — assert the response stores price as numeric 3.75 and includes customization updates
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"id":"'"$PRODUCT_ID"'"' "$RESPONSE_FILE" >/dev/null
grep -F '"price":3.75' "$RESPONSE_FILE" >/dev/null
if grep -F '"price":"3.75"' "$RESPONSE_FILE" >/dev/null; then
  echo 'expected numeric price but found string value'
  exit 1
fi
grep -F '"single"' "$RESPONSE_FILE" >/dev/null
grep -F '"double"' "$RESPONSE_FILE" >/dev/null

# Cleanup — delete the dedicated product
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$STATUS_FILE"
[ "$(cat "$STATUS_FILE")" = "204" ]

echo "CODEVALID_TEST_ASSERTION_OK:admin_update_product_price_conversion"
