#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="prod-101-${CASE_SUFFIX}"
PRODUCT_NAME="Delete Me ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — authenticate as admin and create an isolated product that exists before deletion
curl -sS -o "$TMP_DIR/admin-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/admin-login.status"
[ "$(cat "$TMP_DIR/admin-login.status")" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$TMP_DIR/admin-login.json")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

curl -sS -o "$TMP_DIR/create-product.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$PRODUCT_ID\",\"name\":\"$PRODUCT_NAME\",\"note\":\"Temporary product for delete test\",\"description\":\"Created by seed test\",\"price\":4.25,\"strength\":\"Balanced\"}" > "$TMP_DIR/create-product.status"
[ "$(cat "$TMP_DIR/create-product.status")" = "201" ]
jq -e --arg id "$PRODUCT_ID" '.product.id == $id' "$TMP_DIR/create-product.json" >/dev/null

# When — delete the existing product as an authenticated admin
curl -sS -o "$TMP_DIR/delete-body.txt" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$TMP_DIR/delete.status"

# Then — response is 204 with an empty body and the product is no longer visible in the catalog
[ "$(cat "$TMP_DIR/delete.status")" = "204" ]
[ ! -s "$TMP_DIR/delete-body.txt" ]
curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu.json"
if jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu.json" >/dev/null; then
  echo "Deleted product still present in menu"
  exit 1
fi

echo "CODEVALID_TEST_ASSERTION_OK:admin_deletes_existing_product_successfully"

# Cleanup — idempotently remove the test product if it still exists
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
