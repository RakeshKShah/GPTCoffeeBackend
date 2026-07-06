#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="/tmp/unauthenticated_user_denied_from_admin_sales-${CASE_SUFFIX}"
mkdir -p "$TMP_DIR"
RESPONSE_BODY="$TMP_DIR/response.json"
STATUS_FILE="$TMP_DIR/response.status"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
# No authentication token or session is provided.

# When
curl -sS -o "$RESPONSE_BODY" -w '%{http_code}' -X GET "$BASE_URL/api/admin/sales" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "401" ]
grep -F 'Missing or invalid session.' "$RESPONSE_BODY" >/dev/null
! grep -F '"daily"' "$RESPONSE_BODY" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_user_denied_from_admin_sales"

# Cleanup
# No persistent side effects.
