#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="coffee-latte-001-${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/admin_update_product_customization_success_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_update_product_customization_success_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/admin_update_product_customization_success_login_${CASE_SUFFIX}.json"
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

# Given — create a dedicated coffee product to update
curl -sS -o /dev/null -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Latte ${CASE_SUFFIX}\",\"note\":\"Seed latte\",\"description\":\"Product for customization update test\",\"price\":4.95,\"strength\":\"Balanced\",\"customizations\":{\"milk\":[\"whole\",\"oat\",\"almond\"],\"size\":[\"small\",\"medium\",\"large\"]}}" > "$STATUS_FILE"
[ "$(cat "$STATUS_FILE")" = "201" ]

# When — update customization options on the product
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X PATCH "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data '{"customizations":{"milk":["whole","oat","almond","soy"],"size":["small","medium","large","extra-large"],"syrup":["vanilla","caramel"]}}' > "$STATUS_FILE"

# Then — assert response status and updated body fields
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"id":"'"$PRODUCT_ID"'"' "$RESPONSE_FILE" >/dev/null
grep -F '"soy"' "$RESPONSE_FILE" >/dev/null
grep -F '"extra-large"' "$RESPONSE_FILE" >/dev/null
grep -F '"syrup"' "$RESPONSE_FILE" >/dev/null
grep -F '"vanilla"' "$RESPONSE_FILE" >/dev/null
grep -F '"caramel"' "$RESPONSE_FILE" >/dev/null

# Cleanup — delete the dedicated product
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$STATUS_FILE"
[ "$(cat "$STATUS_FILE")" = "204" ]

echo "CODEVALID_TEST_ASSERTION_OK:admin_update_product_customization_success"
