#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
ADMIN_TOKEN="$(printf '%s' '{"userId":"admin-sample","role":"admin"}' | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"
PRODUCT_ID="coffee-latte-01-${CASE_SUFFIX}"
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

# Given — create an isolated product that can be updated
cat >"$CREATE_BODY" <<EOF
{"id":"$PRODUCT_ID","name":"Caffè Latte","price":4.5,"description":"Smooth espresso with steamed milk","note":"Classic milk coffee","strength":"Balanced"}
EOF
curl -sS -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data @"$CREATE_BODY" >/dev/null
cat >"$PATCH_BODY" <<EOF
{"name":"Vanilla Latte","price":5.25,"description":"Smooth espresso with steamed milk and vanilla syrup"}
EOF

# When — update the existing coffee product
curl -sS -o "$PATCH_RESPONSE" -w '%{http_code}' \
  -X PATCH "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data @"$PATCH_BODY" > "$PATCH_STATUS"

# Then — verify response and customer-facing catalog reflect the change
STATUS="$(cat "$PATCH_STATUS")"
[ "$STATUS" = "200" ]
grep -F '"id":"'"$PRODUCT_ID"'"' "$PATCH_RESPONSE" >/dev/null
grep -F '"name":"Vanilla Latte"' "$PATCH_RESPONSE" >/dev/null
grep -F '"price":5.25' "$PATCH_RESPONSE" >/dev/null
grep -F '"description":"Smooth espresso with steamed milk and vanilla syrup"' "$PATCH_RESPONSE" >/dev/null
curl -sS "$BASE_URL/api/menu" > "$MENU_RESPONSE"
grep -F '"id":"'"$PRODUCT_ID"'"' "$MENU_RESPONSE" >/dev/null
grep -F '"name":"Vanilla Latte"' "$MENU_RESPONSE" >/dev/null
grep -F '"price":5.25' "$MENU_RESPONSE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:admin_updates_product_successfully"

# Cleanup — handled by trap deleting the created product
