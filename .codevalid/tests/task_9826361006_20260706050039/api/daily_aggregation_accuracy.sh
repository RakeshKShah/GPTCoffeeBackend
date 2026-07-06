#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_DIR="/workdir/src/data"
DB_PATH="$DB_DIR/db.json"
LOGIN_FILE="/tmp/daily_aggregation_accuracy_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/daily_aggregation_accuracy_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/daily_aggregation_accuracy_status_${CASE_SUFFIX}.txt"

cleanup_tmp() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_tmp EXIT

# Given — create an admin and orders where only two are from today
mkdir -p "$DB_DIR"
TODAY_UTC="$(date -u +%Y-%m-%d)"
YESTERDAY_UTC="$(date -u -d '1 day ago' +%Y-%m-%d)"
TOMORROW_UTC="$(date -u -d '1 day' +%Y-%m-%d)"
cat > "$DB_PATH" <<JSON
{
  "users": [
    {
      "id": "admin-daily-${CASE_SUFFIX}",
      "name": "Admin Daily ${CASE_SUFFIX}",
      "email": "admin-daily-${CASE_SUFFIX}@gptcoffee.test",
      "password": "admin123",
      "role": "admin"
    }
  ],
  "products": [],
  "customizations": {},
  "orders": [
    {
      "id": "order-daily-001-${CASE_SUFFIX}",
      "buyerId": "buyer-1",
      "buyerName": "Buyer One",
      "createdAt": "${TODAY_UTC}T08:00:00Z",
      "readyAt": "${TODAY_UTC}T08:15:00Z",
      "status": "Completed",
      "total": 100,
      "items": []
    },
    {
      "id": "order-daily-002-${CASE_SUFFIX}",
      "buyerId": "buyer-2",
      "buyerName": "Buyer Two",
      "createdAt": "${TODAY_UTC}T23:59:59Z",
      "readyAt": "${TOMORROW_UTC}T00:14:59Z",
      "status": "Completed",
      "total": 50,
      "items": []
    },
    {
      "id": "order-daily-003-${CASE_SUFFIX}",
      "buyerId": "buyer-3",
      "buyerName": "Buyer Three",
      "createdAt": "${YESTERDAY_UTC}T23:59:59Z",
      "readyAt": "${TODAY_UTC}T00:14:59Z",
      "status": "Completed",
      "total": 999,
      "items": []
    },
    {
      "id": "order-daily-004-${CASE_SUFFIX}",
      "buyerId": "buyer-4",
      "buyerName": "Buyer Four",
      "createdAt": "${TOMORROW_UTC}T00:00:00Z",
      "readyAt": "${TOMORROW_UTC}T00:15:00Z",
      "status": "Completed",
      "total": 888,
      "items": []
    }
  ]
}
JSON

curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"admin-daily-${CASE_SUFFIX}@gptcoffee.test\",\"password\":\"admin123\"}" \
  > "$LOGIN_FILE"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When — request sales metrics
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/admin/sales" > "$STATUS_FILE"

# Then — verify daily total includes only today's two orders
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"daily":150' "$RESPONSE_FILE" >/dev/null

echo 'CODEVALID_TEST_ASSERTION_OK:daily_aggregation_accuracy'

# Cleanup — remove the test database file
rm -f "$DB_PATH"
