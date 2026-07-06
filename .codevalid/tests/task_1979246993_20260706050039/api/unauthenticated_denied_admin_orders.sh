#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="$(mktemp -d)"
RESPONSE_BODY="$TMP_DIR/unauth_${CASE_SUFFIX}.json"
STATUS_FILE="$TMP_DIR/unauth_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
INVALID_TOKEN="invalid-session-${CASE_SUFFIX}"

# When
curl -sS \
  -o "$RESPONSE_BODY" \
  -w '%{http_code}' \
  -X GET "$BASE_URL/api/admin/orders" \
  -H "Authorization: Bearer $INVALID_TOKEN" > "$STATUS_FILE"

# Then
HTTP_CODE="$(cat "$STATUS_FILE")"
[ "$HTTP_CODE" = "401" ]
grep -E 'Missing or invalid session|Invalid session' "$RESPONSE_BODY" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_denied_admin_orders"

# Cleanup
# No persistent side effects; unauthenticated read attempt is stateless.
