#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="/tmp/sales_calculations_across_order_date_distributions-${CASE_SUFFIX}"
mkdir -p "$TMP_DIR"
LOGIN_BODY="$TMP_DIR/login.json"
SALES_BODY="$TMP_DIR/sales.json"
SALES_STATUS="$TMP_DIR/sales.status"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
LOGIN_STATUS="$(curl -sS -o "$LOGIN_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}')"
[ "$LOGIN_STATUS" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$LOGIN_BODY")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

# When
curl -sS -o "$SALES_BODY" -w '%{http_code}' -X GET "$BASE_URL/api/admin/sales" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$SALES_STATUS"

# Then
STATUS="$(cat "$SALES_STATUS")"
[ "$STATUS" = "200" ]
grep -F '"daily":18.55' "$SALES_BODY" >/dev/null
grep -F '"monthly":18.55' "$SALES_BODY" >/dev/null
grep -F '"total":31' "$SALES_BODY" >/dev/null
grep -F '"orderCount":2' "$SALES_BODY" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:sales_calculations_across_order_date_distributions"

# Cleanup
# No persistent side effects; validates current seeded date distribution.
