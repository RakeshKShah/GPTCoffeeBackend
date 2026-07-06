#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="coffee-americano-005-${CASE_SUFFIX}"
MALICIOUS_ID="malicious-different-id-${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/admin_update_preserves_product_id_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/admin_update_preserves_product_id_${CASE_SUFFIX}.status"
LOGIN_FILE="/tmp/admin_update_preserves_product_id_login_${CASE_SUFFIX}.json"
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

# Given — create a product with a stable original id
curl -sS -o /dev/null -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Americano ${CASE_SUFFIX}\",\"note\":\"Long black\",\"description\":\"ID preservation test\",\"price\":4.1,\"strength\":\"Smooth\"}" > "$STATUS_FILE"
[ "$(cat "$STATUS_FILE")" = "201" ]

# When — attempt to overwrite the product id in the request body
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X PATCH "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"${MALICIOUS_ID}\",\"customizations\":{\"size\":[\"small\",\"large\"]}}" > "$STATUS_FILE"

# Then — assert the response preserves the URL param id and does not expose the malicious id
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"id":"'"$PRODUCT_ID"'"' "$RESPONSE_FILE" >/dev/null
if grep -F '"id":"'"$MALICIOUS_ID"'"' "$RESPONSE_FILE" >/dev/null; then
  echo 'product id was overwritten by request body'
  exit 1
fi
grep -F '"small"' "$RESPONSE_FILE" >/dev/null
grep -F '"large"' "$RESPONSE_FILE" >/dev/null

# Cleanup — delete the original product id and verify malicious id was not created
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$STATUS_FILE"
[ "$(cat "$STATUS_FILE")" = "204" ]

curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$MALICIOUS_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$STATUS_FILE"
[ "$(cat "$STATUS_FILE")" = "204" ]

echo "CODEVALID_TEST_ASSERTION_OK:admin_update_preserves_product_id"
