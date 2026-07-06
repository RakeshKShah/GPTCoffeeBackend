#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
ADMIN_TOKEN="$(printf '%s' '{"userId":"admin-sample","role":"admin"}' | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="nonexistent-product-${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
PATCH_BODY="$TMP_DIR/patch.json"
PATCH_RESPONSE="$TMP_DIR/patch-response.json"
PATCH_STATUS="$TMP_DIR/patch-status.txt"
trap 'rm -rf "$TMP_DIR"' EXIT

# Given — use a guaranteed-missing product id
cat >"$PATCH_BODY" <<EOF
{"name":"Updated Name","price":3}
EOF

# When — attempt to update a non-existent product
curl -sS -o "$PATCH_RESPONSE" -w '%{http_code}' \
  -X PATCH "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data @"$PATCH_BODY" > "$PATCH_STATUS"

# Then — verify not found response
STATUS="$(cat "$PATCH_STATUS")"
[ "$STATUS" = "404" ]
grep -F '"message":"Product not found."' "$PATCH_RESPONSE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:admin_update_product_not_found"

# Cleanup — no persistent side effects
