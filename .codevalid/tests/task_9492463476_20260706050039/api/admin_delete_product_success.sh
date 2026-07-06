#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="prod-caffee-mocha-42-${CASE_SUFFIX}"
PRODUCT_NAME="Caffe Mocha ${CASE_SUFFIX}"
SECONDARY_PRODUCT_ID="prod-support-${CASE_SUFFIX}"
SECONDARY_PRODUCT_NAME="Support Roast ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — authenticate as admin and create isolated products including the one to delete
curl -sS -o "$TMP_DIR/admin-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/login.status"
[ "$(cat "$TMP_DIR/login.status")" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$TMP_DIR/admin-login.json")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

curl -sS -o "$TMP_DIR/create-primary.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$PRODUCT_ID\",\"name\":\"$PRODUCT_NAME\",\"note\":\"Chocolate espresso\",\"description\":\"Rich mocha profile\",\"price\":6.9,\"strength\":\"Bold\"}" > "$TMP_DIR/create-primary.status"
[ "$(cat "$TMP_DIR/create-primary.status")" = "201" ]

curl -sS -o "$TMP_DIR/create-secondary.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$SECONDARY_PRODUCT_ID\",\"name\":\"$SECONDARY_PRODUCT_NAME\",\"note\":\"Backup product\",\"description\":\"Ensures multiple products exist\",\"price\":5.4,\"strength\":\"Balanced\"}" > "$TMP_DIR/create-secondary.status"
[ "$(cat "$TMP_DIR/create-secondary.status")" = "201" ]

# When — delete the target product as admin
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$TMP_DIR/delete.status"

# Then — response is 204 and the deleted product is absent from the catalog
[ "$(cat "$TMP_DIR/delete.status")" = "204" ]
curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu.json"
if jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu.json" >/dev/null; then
  echo "Deleted product still present in menu"
  exit 1
fi
jq -e --arg id "$SECONDARY_PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu.json" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:admin_delete_product_success"

# Cleanup — remove any test products left behind
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$SECONDARY_PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
