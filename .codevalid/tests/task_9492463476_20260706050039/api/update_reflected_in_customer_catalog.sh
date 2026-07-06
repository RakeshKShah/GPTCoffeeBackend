#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
ADMIN_TOKEN="$(printf '%s' '{"userId":"admin-sample","role":"admin"}' | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"
PRODUCT_ID="coffee-americano-04-${CASE_SUFFIX}"
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

# Given — create a product visible in the customer catalog
cat >"$CREATE_BODY" <<EOF
{"id":"$PRODUCT_ID","name":"Americano","price":3.0,"description":"Hot water over espresso","note":"Clean and bright","strength":"Balanced"}
EOF
curl -sS -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data @"$CREATE_BODY" >/dev/null
cat >"$PATCH_BODY" <<EOF
{"name":"Premium Americano","price":3.75}
EOF

# When — admin updates the product
curl -sS -o "$PATCH_RESPONSE" -w '%{http_code}' \
  -X PATCH "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data @"$PATCH_BODY" > "$PATCH_STATUS"

# Then — customer-facing menu returns the updated product details
STATUS="$(cat "$PATCH_STATUS")"
[ "$STATUS" = "200" ]
grep -F '"name":"Premium Americano"' "$PATCH_RESPONSE" >/dev/null
grep -F '"price":3.75' "$PATCH_RESPONSE" >/dev/null
curl -sS "$BASE_URL/api/menu" > "$MENU_RESPONSE"
grep -F '"id":"'"$PRODUCT_ID"'"' "$MENU_RESPONSE" >/dev/null
grep -F '"name":"Premium Americano"' "$MENU_RESPONSE" >/dev/null
grep -F '"price":3.75' "$MENU_RESPONSE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:update_reflected_in_customer_catalog"

# Cleanup — handled by trap deleting the created product
