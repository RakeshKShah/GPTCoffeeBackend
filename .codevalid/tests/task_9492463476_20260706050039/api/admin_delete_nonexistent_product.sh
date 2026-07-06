#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="prod-nonexistent-999-${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — authenticate as admin and confirm the target product does not exist
curl -sS -o "$TMP_DIR/admin-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/login.status"
[ "$(cat "$TMP_DIR/login.status")" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$TMP_DIR/admin-login.json")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu-before.json"
if jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu-before.json" >/dev/null; then
  echo "Unexpected pre-existing product id"
  exit 1
fi

# When — delete a non-existent product id as admin
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$TMP_DIR/delete.status"

# Then — idempotent delete still returns 204 and the product remains absent
[ "$(cat "$TMP_DIR/delete.status")" = "204" ]
curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu-after.json"
if jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu-after.json" >/dev/null; then
  echo "Non-existent product appeared after delete"
  exit 1
fi

echo "CODEVALID_TEST_ASSERTION_OK:admin_delete_nonexistent_product"

# Cleanup — stateless for this case; no side effects were created
