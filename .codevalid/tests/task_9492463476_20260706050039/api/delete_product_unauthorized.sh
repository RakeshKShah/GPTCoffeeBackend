#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="prod-espresso-11-${CASE_SUFFIX}"
PRODUCT_NAME="Espresso ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — create a product via authenticated admin so an unauthenticated delete has a real target
curl -sS -o "$TMP_DIR/admin-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/login.status"
[ "$(cat "$TMP_DIR/login.status")" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$TMP_DIR/admin-login.json")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

curl -sS -o "$TMP_DIR/create.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$PRODUCT_ID\",\"name\":\"$PRODUCT_NAME\",\"note\":\"Sharp espresso\",\"description\":\"Unauthenticated delete target\",\"price\":4.2,\"strength\":\"Bold\"}" > "$TMP_DIR/create.status"
[ "$(cat "$TMP_DIR/create.status")" = "201" ]

# When — attempt product deletion without authentication
curl -sS -o "$TMP_DIR/delete-body.json" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" > "$TMP_DIR/delete.status"

# Then — request is rejected with 401 and the product remains present
[ "$(cat "$TMP_DIR/delete.status")" = "401" ]
grep -F 'Missing or invalid session.' "$TMP_DIR/delete-body.json" >/dev/null
curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu-after.json"
jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu-after.json" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:delete_product_unauthorized"

# Cleanup — remove the created product as admin
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
