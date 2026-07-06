#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_DIR="/workdir/src/data"
DB_PATH="$DB_DIR/db.json"
RESPONSE_FILE="/tmp/unauthorized_access_no_auth_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/unauthorized_access_no_auth_status_${CASE_SUFFIX}.txt"

cleanup_tmp() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_tmp EXIT

# Given — create database state with at least one order but intentionally no auth token
mkdir -p "$DB_DIR"
TODAY_UTC="$(date -u +%Y-%m-%d)"
cat > "$DB_PATH" <<JSON
{
  "users": [
    {
      "id": "admin-unauth-${CASE_SUFFIX}",
      "name": "Admin Unauth ${CASE_SUFFIX}",
      "email": "admin-unauth-${CASE_SUFFIX}@gptcoffee.test",
      "password": "admin123",
      "role": "admin"
    }
  ],
  "products": [],
  "customizations": {},
  "orders": [
    {
      "id": "order-auth-001-${CASE_SUFFIX}",
      "buyerId": "buyer-1",
      "buyerName": "Buyer One",
      "createdAt": "${TODAY_UTC}T10:00:00Z",
      "readyAt": "${TODAY_UTC}T10:15:00Z",
      "status": "Completed",
      "total": 100,
      "items": []
    }
  ]
}
JSON

# When — call the admin sales endpoint without authentication
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  "$BASE_URL/api/admin/sales" > "$STATUS_FILE"

# Then — verify the request is rejected as unauthorized
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "401" ]
grep -F 'Missing or invalid session.' "$RESPONSE_FILE" >/dev/null

echo 'CODEVALID_TEST_ASSERTION_OK:unauthorized_access_no_auth'

# Cleanup — remove the test database file
rm -f "$DB_PATH"
