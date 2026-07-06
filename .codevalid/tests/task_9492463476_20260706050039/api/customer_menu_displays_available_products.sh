#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="coffee-001-${CASE_SUFFIX}"
PRODUCT_NAME="Caramel Macchiato ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — authenticate as admin and create an isolated coffee product visible in the menu
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
  --data "{\"id\":\"$PRODUCT_ID\",\"name\":\"$PRODUCT_NAME\",\"note\":\"Buttery caramel\",\"description\":\"Espresso with caramel and steamed milk\",\"price\":4.5,\"strength\":\"Balanced\"}" > "$TMP_DIR/create.status"
[ "$(cat "$TMP_DIR/create.status")" = "201" ]
jq -e --arg id "$PRODUCT_ID" '.product.id == $id' "$TMP_DIR/create.json" >/dev/null

# When — customer browses the public menu endpoint
curl -sS -o "$TMP_DIR/menu.json" -w '%{http_code}' \
  "$BASE_URL/api/menu" > "$TMP_DIR/menu.status"

# Then — response contains products plus customizations and includes the created product
[ "$(cat "$TMP_DIR/menu.status")" = "200" ]
jq -e '.products | type == "array"' "$TMP_DIR/menu.json" >/dev/null
jq -e '.customizations | type == "object"' "$TMP_DIR/menu.json" >/dev/null
jq -e --arg id "$PRODUCT_ID" --arg name "$PRODUCT_NAME" '.products[] | select(.id == $id and .name == $name and .price == 4.5)' "$TMP_DIR/menu.json" >/dev/null
grep -F '"customizations"' "$TMP_DIR/menu.json" >/dev/null
grep -F '"sizes"' "$TMP_DIR/menu.json" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:customer_menu_displays_available_products"

# Cleanup — remove the product created for this test
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
