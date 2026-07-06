#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
MISSING_PRODUCT_ID="prod-999-${CASE_SUFFIX}"
SENTINEL_PRODUCT_ID="sentinel-${CASE_SUFFIX}"
SENTINEL_PRODUCT_NAME="Sentinel ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — authenticate as admin, ensure the target id does not exist, and create a sentinel product to detect unintended changes
curl -sS -o "$TMP_DIR/admin-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/admin-login.status"
[ "$(cat "$TMP_DIR/admin-login.status")" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$TMP_DIR/admin-login.json")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$MISSING_PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true

curl -sS -o "$TMP_DIR/create-sentinel.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$SENTINEL_PRODUCT_ID\",\"name\":\"$SENTINEL_PRODUCT_NAME\",\"note\":\"Control product\",\"description\":\"Verifies unrelated data is preserved\",\"price\":6.00,\"strength\":\"Balanced\"}" > "$TMP_DIR/create-sentinel.status"
[ "$(cat "$TMP_DIR/create-sentinel.status")" = "201" ]

# When — delete a product id that does not exist
curl -sS -o "$TMP_DIR/delete-body.txt" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$MISSING_PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$TMP_DIR/delete.status"

# Then — response is still 204, the body is empty, the missing id is absent, and the sentinel product remains
[ "$(cat "$TMP_DIR/delete.status")" = "204" ]
[ ! -s "$TMP_DIR/delete-body.txt" ]
curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu.json"
if jq -e --arg id "$MISSING_PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu.json" >/dev/null; then
  echo "Nonexistent product unexpectedly present after delete"
  exit 1
fi
jq -e --arg id "$SENTINEL_PRODUCT_ID" '.products[] | select(.id == $id)' "$TMP_DIR/menu.json" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:admin_deletes_nonexistent_product_returns_204"

# Cleanup — remove sentinel product
curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$SENTINEL_PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
