#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
USER_NAME="Jane Doe ${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/missing_email_returns_400_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/missing_email_returns_400_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
: "No persisted setup required for missing email validation"

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"${USER_NAME}\",\"password\":\"securePass123\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "400" ]
grep -F 'Name, email, and a 6+ character password are required.' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:missing_email_returns_400"
