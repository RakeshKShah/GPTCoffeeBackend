#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_DIR="/workdir/src/data"
DB_PATH="$DB_DIR/db.json"
LOGIN_FILE="/tmp/non_admin_access_forbidden_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/non_admin_access_forbidden_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/non_admin_access_forbidden_status_${CASE_SUFFIX}.txt"

cleanup_tmp() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_tmp EXIT

# Given — create a non-admin user with valid credentials and existing order data
mkdir -p "$DB_DIR"
TODAY_UTC="$(date -u +%Y-%m-%d)"
cat > "$DB_PATH" <<JSON
{
  "users": [
    {
      "id": "buyer-forbidden-${CASE_SUFFIX}",
      "name": "Buyer Forbidden ${CASE_SUFFIX}",
      "email": "buyer-forbidden-${CASE_SUFFIX}@gptcoffee.test",
      "password": "buyer123",
      "role": "buyer"
    }
  ],
  "products": [],
  "customizations": {},
  "orders": [
    {
      "id": "order-auth-002-${CASE_SUFFIX}",
      "buyerId": "buyer-x",
      "buyerName": "Buyer X",
      "createdAt": "${TODAY_UTC}T10:00:00Z",
      "readyAt": "${TODAY_UTC}T10:15:00Z",
      "status": "Completed",
      "total": 100,
      "items": []
    }
  ]
}
JSON

curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"buyer-forbidden-${CASE_SUFFIX}@gptcoffee.test\",\"password\":\"buyer123\"}" \
  > "$LOGIN_FILE"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When — call the admin sales endpoint as a non-admin user
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/admin/sales" > "$STATUS_FILE"

# Then — verify the request is rejected as forbidden
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "403" ]
grep -F 'Admin access required.' "$RESPONSE_FILE" >/dev/null

echo 'CODEVALID_TEST_ASSERTION_OK:non_admin_access_forbidden'

# Cleanup — remove the test database file
rm -f "$DB_PATH"
