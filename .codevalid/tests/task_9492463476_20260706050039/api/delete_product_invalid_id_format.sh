#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
RAW_INVALID_ID='<script>alert(1)</script>'
ENCODED_INVALID_ID='%3Cscript%3Ealert(1)%3C%2Fscript%3E'
TMP_DIR="$(mktemp -d)"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — authenticate as admin and confirm no product exists with the malformed id literal
curl -sS -o "$TMP_DIR/admin-login.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$TMP_DIR/login.status"
[ "$(cat "$TMP_DIR/login.status")" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$TMP_DIR/admin-login.json")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

curl -sS "$BASE_URL/api/menu" > "$TMP_DIR/menu-before.json"
if grep -F "$RAW_INVALID_ID" "$TMP_DIR/menu-before.json" >/dev/null; then
  echo "Malformed id unexpectedly present in menu"
  exit 1
fi

# When — send DELETE with a URL-encoded malformed product id
curl -sS -o "$TMP_DIR/delete-body.txt" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/admin/products/$ENCODED_INVALID_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$TMP_DIR/delete.status"

# Then — request is handled safely without a server error or reflected malicious input
DELETE_STATUS="$(cat "$TMP_DIR/delete.status")"
case "$DELETE_STATUS" in
  204|404|400) ;;
  *)
    echo "Unexpected status for malformed id: $DELETE_STATUS"
    exit 1
    ;;
esac
if [ "$DELETE_STATUS" -ge 500 ]; then
  echo "Malformed id caused server error"
  exit 1
fi
if grep -F "$RAW_INVALID_ID" "$TMP_DIR/delete-body.txt" >/dev/null; then
  echo "Malformed input was reflected in response body"
  exit 1
fi

echo "CODEVALID_TEST_ASSERTION_OK:delete_product_invalid_id_format"

# Cleanup — stateless for this case; no side effects were created
