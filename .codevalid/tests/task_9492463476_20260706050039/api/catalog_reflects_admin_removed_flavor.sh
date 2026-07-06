#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="coffee-discontinued-${CASE_SUFFIX}"
PRODUCT_NAME="Seasonal Blend ${CASE_SUFFIX}"
CONTROL_ID="coffee-still-listed-${CASE_SUFFIX}"
CONTROL_NAME="House Roast ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — admin creates one product to be removed and another that should remain visible
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
  --data "{\"id\":\"$PRODUCT_ID\",\"name\":\"$PRODUCT_NAME\",\"note\":\"Limited roast\",\"description\":\"Seasonal beans with spice notes\",\"price\":5.25,\"strength\":\"Bold\"}" > "$TMP_DIR/create-removed.status"
[ "$(cat "$TMP_DIR/create-removed.status")" = "201" ]

curl -sS -o /dev/null -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$CONTROL_ID\",\"name\":\"$CONTROL_NAME\",\"note\":\"Always available\",\"description\":\"Core menu coffee for control assertions\",\"price\":4.15,\"strength\":\"Balanced\"}" > "$TMP_DIR/create-control.status"
[ "$(cat "$TMP_DIR/create-control.status")" = "201" ]

curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu-before.json"
jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu-before.json" >/dev/null
jq -e --arg id "$CONTROL_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu-before.json" >/dev/null

curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$TMP_DIR/delete.status"
[ "$(cat "$TMP_DIR/delete.status")" = "204" ]

# When — customer fetches the menu after the admin removal
curl -sS -o "$TMP_DIR/menu-after.json" -w '%{http_code}' \
  "$BASE_URL/api/menu" > "$TMP_DIR/menu.status"

# Then — removed flavor is absent while the other existing product remains present
[ "$(cat "$TMP_DIR/menu.status")" = "200" ]
if jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu-after.json" >/dev/null; then
  echo "Removed product still visible in menu"
  exit 1
fi
jq -e --arg id "$CONTROL_ID" --arg name "$CONTROL_NAME" '.products[] | select(.id == $id and .name == $name)' "$TMP_DIR/menu-after.json" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:catalog_reflects_admin_removed_flavor"

# Cleanup — ensure both test products are absent
curl -sS -o /dev/null -w '%{http_code}' -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
curl -sS -o /dev/null -w '%{http_code}' -X DELETE "$BASE_URL/api/admin/products/$CONTROL_ID" -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
