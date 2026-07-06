#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID="prod-104-${CASE_SUFFIX}"
PRODUCT_NAME="Persist Delete ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — authenticate as admin and create an isolated product that will be deleted and re-checked through fresh reads
curl -sS -o "$TMP_DIR/admin-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/admin-login.status"
[ "$(cat "$TMP_DIR/admin-login.status")" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$TMP_DIR/admin-login.json")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

curl -sS -o "$TMP_DIR/create-product.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$PRODUCT_ID\",\"name\":\"$PRODUCT_NAME\",\"note\":\"Persistence verification fixture\",\"description\":\"Should remain deleted after writeDb\",\"price\":7.15,\"strength\":\"Strong\"}" > "$TMP_DIR/create-product.status"
[ "$(cat "$TMP_DIR/create-product.status")" = "201" ]

curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu-before.json"
jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu-before.json" >/dev/null

# When — delete the product as admin
curl -sS -o "$TMP_DIR/delete-body.txt" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$TMP_DIR/delete.status"

# Then — response is 204 and repeated fresh reads confirm the product remains absent, indicating persisted deletion
[ "$(cat "$TMP_DIR/delete.status")" = "204" ]
[ ! -s "$TMP_DIR/delete-body.txt" ]
curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu-after-first-read.json"
if jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu-after-first-read.json" >/dev/null; then
  echo "Deleted product still present on first post-delete read"
  exit 1
fi

curl -sS -o "$TMP_DIR/admin-login-again.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/admin-login-again.status"
[ "$(cat "$TMP_DIR/admin-login-again.status")" = "200" ]
ADMIN_TOKEN_AGAIN="$(jq -r '.token' "$TMP_DIR/admin-login-again.json")"
[ -n "$ADMIN_TOKEN_AGAIN" ]
[ "$ADMIN_TOKEN_AGAIN" != "null" ]

curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu-after-second-read.json"
if jq -e --arg id "$PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu-after-second-read.json" >/dev/null; then
  echo "Deleted product still present on second post-delete read"
  exit 1
fi

echo "CODEVALID_TEST_ASSERTION_OK:database_persistence_verified_after_product_deletion"

# Cleanup — idempotently remove the product if it still exists
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
