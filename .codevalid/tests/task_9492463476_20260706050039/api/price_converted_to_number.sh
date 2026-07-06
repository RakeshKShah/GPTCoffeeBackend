#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
ADMIN_TOKEN="$(printf '%s' '{"userId":"admin-sample","role":"admin"}' | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"
PRODUCT_ID="coffee-espresso-02-${CASE_SUFFIX}"
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

# Given — create an existing product with a numeric starting price
cat >"$CREATE_BODY" <<EOF
{"id":"$PRODUCT_ID","name":"Espresso","price":3.5,"description":"Pure espresso shot","note":"Short pull","strength":"Bold"}
EOF
curl -sS -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data @"$CREATE_BODY" >/dev/null
cat >"$PATCH_BODY" <<EOF
{"price":"4.75"}
EOF

# When — update using a string price value
curl -sS -o "$PATCH_RESPONSE" -w '%{http_code}' \
  -X PATCH "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data @"$PATCH_BODY" > "$PATCH_STATUS"

# Then — verify the returned and catalog prices are numeric JSON values
STATUS="$(cat "$PATCH_STATUS")"
[ "$STATUS" = "200" ]
grep -F '"id":"'"$PRODUCT_ID"'"' "$PATCH_RESPONSE" >/dev/null
grep -F '"price":4.75' "$PATCH_RESPONSE" >/dev/null
if grep -F '"price":"4.75"' "$PATCH_RESPONSE" >/dev/null; then
  echo "price remained a string in response"
  exit 1
fi
curl -sS "$BASE_URL/api/menu" > "$MENU_RESPONSE"
grep -F '"id":"'"$PRODUCT_ID"'"' "$MENU_RESPONSE" >/dev/null
grep -F '"price":4.75' "$MENU_RESPONSE" >/dev/null
if grep -F '"price":"4.75"' "$MENU_RESPONSE" >/dev/null; then
  echo "price remained a string in catalog"
  exit 1
fi
echo "CODEVALID_TEST_ASSERTION_OK:price_converted_to_number"

# Cleanup — handled by trap deleting the created product
