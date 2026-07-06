#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="americano-${CASE_SUFFIX}"
PRODUCT_NAME="Americano ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — admin creates an isolated product while built-in customization groups remain available
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
  --data "{\"id\":\"$PRODUCT_ID\",\"name\":\"$PRODUCT_NAME\",\"note\":\"Clean and classic\",\"description\":\"Espresso diluted with hot water\",\"price\":3.8,\"strength\":\"Smooth\"}" > "$TMP_DIR/create.status"
[ "$(cat "$TMP_DIR/create.status")" = "201" ]

# When — customer loads the menu response
curl -sS -o "$TMP_DIR/menu.json" -w '%{http_code}' \
  "$BASE_URL/api/menu" > "$TMP_DIR/menu.status"

# Then — response includes both products and customization option groups
[ "$(cat "$TMP_DIR/menu.status")" = "200" ]
jq -e 'has("products") and has("customizations")' "$TMP_DIR/menu.json" >/dev/null
jq -e '.products | type == "array"' "$TMP_DIR/menu.json" >/dev/null
jq -e '.customizations | type == "object"' "$TMP_DIR/menu.json" >/dev/null
jq -e --arg id "$PRODUCT_ID" --arg name "$PRODUCT_NAME" '.products[] | select(.id == $id and .name == $name)' "$TMP_DIR/menu.json" >/dev/null
jq -e '.customizations.sizes | type == "array" and length >= 1' "$TMP_DIR/menu.json" >/dev/null
jq -e '.customizations.milks | type == "array" and length >= 1' "$TMP_DIR/menu.json" >/dev/null
jq -e '.customizations.extras | type == "array" and length >= 1' "$TMP_DIR/menu.json" >/dev/null
grep -F '"sizes"' "$TMP_DIR/menu.json" >/dev/null
grep -F '"milks"' "$TMP_DIR/menu.json" >/dev/null
grep -F '"extras"' "$TMP_DIR/menu.json" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:response_structure_includes_customizations"

# Cleanup — remove the isolated product
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
