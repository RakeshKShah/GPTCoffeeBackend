#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
ADMIN_TOKEN="$(printf '%s' '{"userId":"admin-sample","role":"admin"}' | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"
PRODUCT_ID="coffee-cappuccino-03-${CASE_SUFFIX}"
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

# Given — create a product with fields that should be preserved
cat >"$CREATE_BODY" <<EOF
{"id":"$PRODUCT_ID","name":"Cappuccino","price":4.0,"description":"Frothy espresso with steamed milk foam","note":"hot-drinks","strength":"Balanced","gradient":"from-stone-700 via-amber-800 to-black"}
EOF
curl -sS -X POST "$BASE_URL/api/admin/products" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data @"$CREATE_BODY" >/dev/null
cat >"$PATCH_BODY" <<EOF
{"name":"Classic Cappuccino"}
EOF

# When — send a partial update containing only the name change
curl -sS -o "$PATCH_RESPONSE" -w '%{http_code}' \
  -X PATCH "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data @"$PATCH_BODY" > "$PATCH_STATUS"

# Then — verify unsent fields are preserved
STATUS="$(cat "$PATCH_STATUS")"
[ "$STATUS" = "200" ]
grep -F '"id":"'"$PRODUCT_ID"'"' "$PATCH_RESPONSE" >/dev/null
grep -F '"name":"Classic Cappuccino"' "$PATCH_RESPONSE" >/dev/null
grep -F '"price":4' "$PATCH_RESPONSE" >/dev/null
grep -F '"description":"Frothy espresso with steamed milk foam"' "$PATCH_RESPONSE" >/dev/null
grep -F '"note":"hot-drinks"' "$PATCH_RESPONSE" >/dev/null
grep -F '"strength":"Balanced"' "$PATCH_RESPONSE" >/dev/null
grep -F '"gradient":"from-stone-700 via-amber-800 to-black"' "$PATCH_RESPONSE" >/dev/null
curl -sS "$BASE_URL/api/menu" > "$MENU_RESPONSE"
grep -F '"id":"'"$PRODUCT_ID"'"' "$MENU_RESPONSE" >/dev/null
grep -F '"name":"Classic Cappuccino"' "$MENU_RESPONSE" >/dev/null
grep -F '"description":"Frothy espresso with steamed milk foam"' "$MENU_RESPONSE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:partial_update_preserves_unsent_fields"

# Cleanup — handled by trap deleting the created product
