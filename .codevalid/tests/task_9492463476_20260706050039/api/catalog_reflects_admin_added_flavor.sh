#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="coffee-new-${CASE_SUFFIX}"
PRODUCT_NAME="Hazelnut Delight ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — admin logs in and adds a new coffee flavor that did not previously exist
curl -sS -o "$TMP_DIR/admin-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/login.status"
[ "$(cat "$TMP_DIR/login.status")" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$TMP_DIR/admin-login.json")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu-before.json"
if jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu-before.json" >/dev/null; then
  echo "Test product already existed before creation"
  exit 1
fi

curl -sS -o "$TMP_DIR/create.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$PRODUCT_ID\",\"name\":\"$PRODUCT_NAME\",\"note\":\"Toasted hazelnut\",\"description\":\"Nutty espresso with sweet hazelnut crema\",\"price\":4.75,\"strength\":\"Balanced\"}" > "$TMP_DIR/create.status"
[ "$(cat "$TMP_DIR/create.status")" = "201" ]
jq -e --arg id "$PRODUCT_ID" '.product.id == $id' "$TMP_DIR/create.json" >/dev/null

# When — customer fetches the menu after the admin addition
curl -sS -o "$TMP_DIR/menu-after.json" -w '%{http_code}' \
  "$BASE_URL/api/menu" > "$TMP_DIR/menu.status"

# Then — the new flavor is immediately visible in the product catalog
[ "$(cat "$TMP_DIR/menu.status")" = "200" ]
jq -e --arg id "$PRODUCT_ID" --arg name "$PRODUCT_NAME" '.products[] | select(.id == $id and .name == $name and .price == 4.75)' "$TMP_DIR/menu-after.json" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:catalog_reflects_admin_added_flavor"

# Cleanup — delete the added flavor
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
