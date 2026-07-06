#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="prod-cappuccino-55-${CASE_SUFFIX}"
PRODUCT_NAME="Cappuccino ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — create a product as admin and obtain a non-admin buyer token
curl -sS -o "$TMP_DIR/admin-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/admin-login.status"
[ "$(cat "$TMP_DIR/admin-login.status")" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$TMP_DIR/admin-login.json")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

curl -sS -o "$TMP_DIR/create.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$PRODUCT_ID\",\"name\":\"$PRODUCT_NAME\",\"note\":\"Foamy classic\",\"description\":\"Forbidden delete target\",\"price\":5.8,\"strength\":\"Balanced\"}" > "$TMP_DIR/create.status"
[ "$(cat "$TMP_DIR/create.status")" = "201" ]

curl -sS -o "$TMP_DIR/buyer-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"buyer@gptcoffee.test","password":"buyer123"}' > "$TMP_DIR/buyer-login.status"
[ "$(cat "$TMP_DIR/buyer-login.status")" = "200" ]
BUYER_TOKEN="$(jq -r '.token' "$TMP_DIR/buyer-login.json")"
[ -n "$BUYER_TOKEN" ]
[ "$BUYER_TOKEN" != "null" ]

# When — authenticated non-admin attempts deletion
curl -sS -o "$TMP_DIR/delete-body.json" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $BUYER_TOKEN" > "$TMP_DIR/delete.status"

# Then — request is forbidden and the product remains in the catalog
[ "$(cat "$TMP_DIR/delete.status")" = "403" ]
grep -F 'Admin access required.' "$TMP_DIR/delete-body.json" >/dev/null
curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu-after.json"
jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu-after.json" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:delete_product_forbidden_non_admin"

# Cleanup — remove the created product as admin
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
