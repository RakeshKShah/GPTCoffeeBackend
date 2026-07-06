#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
ADMIN_TOKEN="$(printf '%s' '{"userId":"admin-sample","role":"admin"}' | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"
BUYER_TOKEN="$(printf '%s' '{"userId":"buyer-sample","role":"buyer"}' | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"
PRODUCT_ID="coffee-mocha-05-${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
CREATE_BODY="$TMP_DIR/create.json"
PATCH_BODY="$TMP_DIR/patch.json"
PATCH_RESPONSE="$TMP_DIR/patch-response.json"
PATCH_STATUS="$TMP_DIR/patch-status.txt"
MENU_RESPONSE="$TMP_DIR/menu-response.json"
cleanup() {
  curl -sS -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
    -H "Authorization: Bearer $ADMIN_TOKEN" >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Given — create a product, then prepare a non-admin token
cat >"$CREATE_BODY" <<EOF
{"id":"$PRODUCT_ID","name":"Mocha Reserve","price":6.1,"description":"Chocolate espresso blend","note":"Dark cocoa","strength":"Bold"}
EOF
curl -sS -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data @"$CREATE_BODY" >/dev/null
cat >"$PATCH_BODY" <<EOF
{"name":"Blocked Update","price":6.9}
EOF

# When — non-admin attempts to update the product
curl -sS -o "$PATCH_RESPONSE" -w '%{http_code}' \
  -X PATCH "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $BUYER_TOKEN" \
  --data @"$PATCH_BODY" > "$PATCH_STATUS"

# Then — verify access is denied and catalog is unchanged
STATUS="$(cat "$PATCH_STATUS")"
[ "$STATUS" = "403" ]
grep -F '"message":"Admin access required."' "$PATCH_RESPONSE" >/dev/null
curl -sS "$BASE_URL/api/menu" > "$MENU_RESPONSE"
grep -F '"id":"'"$PRODUCT_ID"'"' "$MENU_RESPONSE" >/dev/null
grep -F '"name":"Mocha Reserve"' "$MENU_RESPONSE" >/dev/null
if grep -F '"name":"Blocked Update"' "$MENU_RESPONSE" >/dev/null; then
  echo "product was unexpectedly updated"
  exit 1
fi
echo "CODEVALID_TEST_ASSERTION_OK:non_admin_cannot_update_product"

# Cleanup — handled by trap deleting the created product
