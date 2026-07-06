#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_DIR="/workdir/src/data"
DB_PATH="$DB_DIR/db.json"
LOGIN_FILE="/tmp/empty_database_sales_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/empty_database_sales_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/empty_database_sales_status_${CASE_SUFFIX}.txt"

cleanup_tmp() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_tmp EXIT

# Given — create an isolated admin user with no orders in the database
mkdir -p "$DB_DIR"
cat > "$DB_PATH" <<JSON
{
  "users": [
    {
      "id": "admin-empty-${CASE_SUFFIX}",
      "name": "Admin Empty ${CASE_SUFFIX}",
      "email": "admin-empty-${CASE_SUFFIX}@gptcoffee.test",
      "password": "admin123",
      "role": "admin"
    }
  ],
  "products": [],
  "customizations": {},
  "orders": []
}
JSON

curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"admin-empty-${CASE_SUFFIX}@gptcoffee.test\",\"password\":\"admin123\"}" \
  > "$LOGIN_FILE"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When — request sales metrics from the empty database state
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/admin/sales" > "$STATUS_FILE"

# Then — verify zero values are returned for all metrics
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"daily":0' "$RESPONSE_FILE" >/dev/null
grep -F '"monthly":0' "$RESPONSE_FILE" >/dev/null
grep -F '"total":0' "$RESPONSE_FILE" >/dev/null
grep -F '"orderCount":0' "$RESPONSE_FILE" >/dev/null

echo 'CODEVALID_TEST_ASSERTION_OK:empty_database_sales'

# Cleanup — remove the test database file
rm -f "$DB_PATH"
