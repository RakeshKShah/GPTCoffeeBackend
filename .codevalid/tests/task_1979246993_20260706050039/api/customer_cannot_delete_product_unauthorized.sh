#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="prod-102-${CASE_SUFFIX}"
PRODUCT_NAME="Protected Product ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — authenticate as admin and buyer, then create an isolated product for the buyer to target
curl -sS -o "$TMP_DIR/admin-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/admin-login.status"
[ "$(cat "$TMP_DIR/admin-login.status")" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$TMP_DIR/admin-login.json")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

curl -sS -o "$TMP_DIR/buyer-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"buyer@gptcoffee.test","password":"buyer123"}' > "$TMP_DIR/buyer-login.status"
[ "$(cat "$TMP_DIR/buyer-login.status")" = "200" ]
BUYER_TOKEN="$(jq -r '.token' "$TMP_DIR/buyer-login.json")"
[ -n "$BUYER_TOKEN" ]
[ "$BUYER_TOKEN" != "null" ]

curl -sS -o "$TMP_DIR/create-product.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$PRODUCT_ID\",\"name\":\"$PRODUCT_NAME\",\"note\":\"Buyer should not delete this\",\"description\":\"Admin-only managed product\",\"price\":5.10,\"strength\":\"Bold\"}" > "$TMP_DIR/create-product.status"
[ "$(cat "$TMP_DIR/create-product.status")" = "201" ]

# When — attempt to delete the product using a buyer token on an admin-only route
curl -sS -o "$TMP_DIR/delete-response.json" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $BUYER_TOKEN" > "$TMP_DIR/delete.status"

# Then — response is 403 and the product remains present
[ "$(cat "$TMP_DIR/delete.status")" = "403" ]
grep -F 'Admin access required.' "$TMP_DIR/delete-response.json" >/dev/null
curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu.json"
jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu.json" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:customer_cannot_delete_product_unauthorized"

# Cleanup — remove the product as admin
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
