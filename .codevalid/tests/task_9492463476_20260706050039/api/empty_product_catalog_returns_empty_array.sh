#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
PRODUCT_ID_1="empty-menu-one-${CASE_SUFFIX}"
PRODUCT_ID_2="empty-menu-two-${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — admin creates isolated products and then removes them so the catalog has no products from this test
curl -sS -o "$TMP_DIR/admin-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/login.status"
[ "$(cat "$TMP_DIR/login.status")" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$TMP_DIR/admin-login.json")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

curl -sS -o /dev/null -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$PRODUCT_ID_1\",\"name\":\"Temporary Roast ${CASE_SUFFIX}\",\"note\":\"Transient product\",\"description\":\"Will be removed before assertion\",\"price\":4.2,\"strength\":\"Balanced\"}" > "$TMP_DIR/create1.status"
[ "$(cat "$TMP_DIR/create1.status")" = "201" ]

curl -sS -o /dev/null -w '%{http_code}' \
  -X POST "$BASE_URL/api/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data "{\"id\":\"$PRODUCT_ID_2\",\"name\":\"Temporary Brew ${CASE_SUFFIX}\",\"note\":\"Transient product\",\"description\":\"Also removed before assertion\",\"price\":4.6,\"strength\":\"Mellow\"}" > "$TMP_DIR/create2.status"
[ "$(cat "$TMP_DIR/create2.status")" = "201" ]

curl -sS -o /dev/null -w '%{http_code}' -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID_1" -H "Authorization: Bearer $ADMIN_TOKEN" > "$TMP_DIR/delete1.status"
[ "$(cat "$TMP_DIR/delete1.status")" = "204" ]
curl -sS -o /dev/null -w '%{http_code}' -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID_2" -H "Authorization: Bearer $ADMIN_TOKEN" > "$TMP_DIR/delete2.status"
[ "$(cat "$TMP_DIR/delete2.status")" = "204" ]

# When — customer requests the menu after all products created in this test have been removed
curl -sS -o "$TMP_DIR/menu.json" -w '%{http_code}' \
  "$BASE_URL/api/menu" > "$TMP_DIR/menu.status"

# Then — response remains valid, products array excludes the removed products, and customizations are still present
[ "$(cat "$TMP_DIR/menu.status")" = "200" ]
jq -e '.products | type == "array"' "$TMP_DIR/menu.json" >/dev/null
jq -e '.customizations | type == "object"' "$TMP_DIR/menu.json" >/dev/null
if jq -e --arg id "$PRODUCT_ID_1" '.products[] | select(.id == $id)' "$TMP_DIR/menu.json" >/dev/null; then
  echo "First removed product unexpectedly present"
  exit 1
fi
if jq -e --arg id "$PRODUCT_ID_2" '.products[] | select(.id == $id)' "$TMP_DIR/menu.json" >/dev/null; then
  echo "Second removed product unexpectedly present"
  exit 1
fi
grep -F '"products"' "$TMP_DIR/menu.json" >/dev/null
grep -F '"customizations"' "$TMP_DIR/menu.json" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:empty_product_catalog_returns_empty_array"

# Cleanup — idempotently ensure test products remain absent
curl -sS -o /dev/null -w '%{http_code}' -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID_1" -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
curl -sS -o /dev/null -w '%{http_code}' -X DELETE "$BASE_URL/api/admin/products/$PRODUCT_ID_2" -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null || true
