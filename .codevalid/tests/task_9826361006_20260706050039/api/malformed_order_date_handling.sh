#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_DIR="/workdir/src/data"
DB_PATH="$DB_DIR/db.json"
LOGIN_FILE="/tmp/malformed_order_date_handling_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/malformed_order_date_handling_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/malformed_order_date_handling_status_${CASE_SUFFIX}.txt"

cleanup_tmp() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_tmp EXIT

# Given — create an admin plus valid and malformed order createdAt values
mkdir -p "$DB_DIR"
TODAY_UTC="$(date -u +%Y-%m-%d)"
cat > "$DB_PATH" <<JSON
{
  "users": [
    {
      "id": "admin-malformed-${CASE_SUFFIX}",
      "name": "Admin Malformed ${CASE_SUFFIX}",
      "email": "admin-malformed-${CASE_SUFFIX}@gptcoffee.test",
      "password": "admin123",
      "role": "admin"
    }
  ],
  "products": [],
  "customizations": {},
  "orders": [
    {
      "id": "order-valid-001-${CASE_SUFFIX}",
      "buyerId": "buyer-1",
      "buyerName": "Buyer One",
      "createdAt": "${TODAY_UTC}T10:00:00Z",
      "readyAt": "${TODAY_UTC}T10:15:00Z",
      "status": "Completed",
      "total": 100,
      "items": []
    },
    {
      "id": "order-invalid-001-${CASE_SUFFIX}",
      "buyerId": "buyer-2",
      "buyerName": "Buyer Two",
      "createdAt": "invalid-date-string",
      "readyAt": "${TODAY_UTC}T11:15:00Z",
      "status": "Completed",
      "total": 200,
      "items": []
    },
    {
      "id": "order-null-001-${CASE_SUFFIX}",
      "buyerId": "buyer-3",
      "buyerName": "Buyer Three",
      "createdAt": null,
      "readyAt": "${TODAY_UTC}T12:15:00Z",
      "status": "Completed",
      "total": 150,
      "items": []
    }
  ]
}
JSON

curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"admin-malformed-${CASE_SUFFIX}@gptcoffee.test\",\"password\":\"admin123\"}" \
  > "$LOGIN_FILE"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When — request sales metrics with malformed dates present
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/admin/sales" > "$STATUS_FILE"

# Then — verify the endpoint responds successfully and reflects current implementation behavior
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"daily":100' "$RESPONSE_FILE" >/dev/null
grep -F '"monthly":null' "$RESPONSE_FILE" >/dev/null
grep -F '"total":450' "$RESPONSE_FILE" >/dev/null
grep -F '"orderCount":3' "$RESPONSE_FILE" >/dev/null

echo 'CODEVALID_TEST_ASSERTION_OK:malformed_order_date_handling'

# Cleanup — remove the test database file
rm -f "$DB_PATH"
