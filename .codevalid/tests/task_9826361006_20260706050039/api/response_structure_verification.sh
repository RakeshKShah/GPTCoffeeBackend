#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_DIR="/workdir/src/data"
DB_PATH="$DB_DIR/db.json"
LOGIN_FILE="/tmp/response_structure_verification_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/response_structure_verification_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/response_structure_verification_status_${CASE_SUFFIX}.txt"

cleanup_tmp() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_tmp EXIT

# Given — create an admin and one order to verify the response contains all required metrics
mkdir -p "$DB_DIR"
TODAY_UTC="$(date -u +%Y-%m-%d)"
cat > "$DB_PATH" <<JSON
{
  "users": [
    {
      "id": "admin-structure-${CASE_SUFFIX}",
      "name": "Admin Structure ${CASE_SUFFIX}",
      "email": "admin-structure-${CASE_SUFFIX}@gptcoffee.test",
      "password": "admin123",
      "role": "admin"
    }
  ],
  "products": [],
  "customizations": {},
  "orders": [
    {
      "id": "order-struct-001-${CASE_SUFFIX}",
      "buyerId": "buyer-1",
      "buyerName": "Buyer One",
      "createdAt": "${TODAY_UTC}T10:00:00Z",
      "readyAt": "${TODAY_UTC}T10:15:00Z",
      "status": "Completed",
      "total": 99.99,
      "items": []
    }
  ]
}
JSON

curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"admin-structure-${CASE_SUFFIX}@gptcoffee.test\",\"password\":\"admin123\"}" \
  > "$LOGIN_FILE"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When — request the sales metrics payload
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/admin/sales" > "$STATUS_FILE"

# Then — verify status 200 and the required JSON fields are present
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"daily":99.99' "$RESPONSE_FILE" >/dev/null
grep -F '"monthly":99.99' "$RESPONSE_FILE" >/dev/null
grep -F '"total":99.99' "$RESPONSE_FILE" >/dev/null
grep -F '"orderCount":1' "$RESPONSE_FILE" >/dev/null

echo 'CODEVALID_TEST_ASSERTION_OK:response_structure_verification'

# Cleanup — remove the test database file
rm -f "$DB_PATH"
