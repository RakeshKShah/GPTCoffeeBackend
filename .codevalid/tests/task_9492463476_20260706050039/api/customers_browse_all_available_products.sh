#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID_1="browse-espresso-${CASE_SUFFIX}"
PRODUCT_ID_2="browse-latte-${CASE_SUFFIX}"
PRODUCT_ID_3="browse-cappuccino-${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — admin creates three isolated products and no customer auth is prepared or required
curl -sS -o "$TMP_DIR/admin-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/login.status"
[ "$(cat "$TMP_DIR/login.status")" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$TMP_DIR/admin-login.json")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

curl -sS -o /dev/null -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$PRODUCT_ID_1\",\"name\":\"Espresso ${CASE_SUFFIX}\",\"note\":\"Short and bold\",\"description\":\"Single espresso shot\",\"price\":3.0,\"strength\":\"Bold\"}" > "$TMP_DIR/create1.status"
[ "$(cat "$TMP_DIR/create1.status")" = "201" ]

curl -sS -o /dev/null -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$PRODUCT_ID_2\",\"name\":\"Latte ${CASE_SUFFIX}\",\"note\":\"Smooth milk foam\",\"description\":\"Espresso with steamed milk\",\"price\":4.0,\"strength\":\"Mellow\"}" > "$TMP_DIR/create2.status"
[ "$(cat "$TMP_DIR/create2.status")" = "201" ]

curl -sS -o /dev/null -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$PRODUCT_ID_3\",\"name\":\"Cappuccino ${CASE_SUFFIX}\",\"note\":\"Velvety foam\",\"description\":\"Espresso with foamed milk\",\"price\":3.5,\"strength\":\"Balanced\"}" > "$TMP_DIR/create3.status"
[ "$(cat "$TMP_DIR/create3.status")" = "201" ]

# When — customer browses all available products without authentication
curl -sS -o "$TMP_DIR/menu.json" -w '%{http_code}' \
  "$BASE_URL/api/menu" > "$TMP_DIR/menu.status"

# Then — response is public and includes each created product with expected fields
[ "$(cat "$TMP_DIR/menu.status")" = "200" ]
jq -e --arg id "$PRODUCT_ID_1" --arg name "Espresso ${CASE_SUFFIX}" '.products[] | select(.id == $id and .name == $name and .price == 3)' "$TMP_DIR/menu.json" >/dev/null
jq -e --arg id "$PRODUCT_ID_2" --arg name "Latte ${CASE_SUFFIX}" '.products[] | select(.id == $id and .name == $name and .price == 4)' "$TMP_DIR/menu.json" >/dev/null
jq -e --arg id "$PRODUCT_ID_3" --arg name "Cappuccino ${CASE_SUFFIX}" '.products[] | select(.id == $id and .name == $name and .price == 3.5)' "$TMP_DIR/menu.json" >/dev/null
jq -e --arg id "$PRODUCT_ID_1" '.products[] | select(.id == $id) | has("id") and has("name") and has("price")' "$TMP_DIR/menu.json" >/dev/null
jq -e --arg id "$PRODUCT_ID_2" '.products[] | select(.id == $id) | has("id") and has("name") and has("price")' "$TMP_DIR/menu.json" >/dev/null
jq -e --arg id "$PRODUCT_ID_3" '.products[] | select(.id == $id) | has("id") and has("name") and has("price")' "$TMP_DIR/menu.json" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:customers_browse_all_available_products"

# Cleanup — remove the products created for this test
curl -sS -o /dev/null -w '%{http_code}' -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID_1" -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
curl -sS -o /dev/null -w '%{http_code}' -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID_2" -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
curl -sS -o /dev/null -w '%{http_code}' -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID_3" -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
