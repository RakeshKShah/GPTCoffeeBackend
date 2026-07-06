#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="prod-latte-vanilla-99-${CASE_SUFFIX}"
PRODUCT_NAME="Vanilla Latte ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — authenticate as admin and create a product visible in the customer catalog
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
  --data "{\"id\":\"$PRODUCT_ID\",\"name\":\"$PRODUCT_NAME\",\"note\":\"Sweet vanilla\",\"description\":\"Creamy vanilla latte\",\"price\":6.5,\"strength\":\"Mellow\"}" > "$TMP_DIR/create.status"
[ "$(cat "$TMP_DIR/create.status")" = "201" ]

curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu-before.json"
jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu-before.json" >/dev/null

# When — admin deletes the product
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$TMP_DIR/delete.status"

# Then — delete succeeds and the product disappears from the customer menu
[ "$(cat "$TMP_DIR/delete.status")" = "204" ]
curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu-after.json"
if jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu-after.json" >/dev/null; then
  echo "Deleted product still visible in customer catalog"
  exit 1
fi
if grep -F "$PRODUCT_NAME" "$TMP_DIR/menu-after.json" >/dev/null; then
  echo "Deleted product name still visible in customer catalog"
  exit 1
fi

echo "CODEVALID_TEST_ASSERTION_OK:admin_delete_product_reflected_in_catalog"

# Cleanup — ensure isolated test product is absent
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
