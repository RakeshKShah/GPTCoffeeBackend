#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_DIR="/workdir/src/data"
DB_PATH="$DB_DIR/db.json"
LOGIN_FILE="/tmp/monthly_aggregation_accuracy_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/monthly_aggregation_accuracy_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/monthly_aggregation_accuracy_status_${CASE_SUFFIX}.txt"

cleanup_tmp() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_tmp EXIT

# Given — create an admin and orders where only current-month orders should count toward monthly
mkdir -p "$DB_DIR"
TODAY_UTC="$(date -u +%Y-%m-%d)"
THIS_MONTH_PREFIX="$(date -u +%Y-%m)"
PREV_MONTH_PREFIX="$(date -u -d "$(date -u +%Y-%m-01) -1 day" +%Y-%m)"
NEXT_MONTH_PREFIX="$(date -u -d "$(date -u +%Y-%m-28) +6 day" +%Y-%m)"
cat > "$DB_PATH" <<JSON
{
  "users": [
    {
      "id": "admin-monthly-${CASE_SUFFIX}",
      "name": "Admin Monthly ${CASE_SUFFIX}",
      "email": "admin-monthly-${CASE_SUFFIX}@gptcoffee.test",
      "password": "admin123",
      "role": "admin"
    }
  ],
  "products": [],
  "customizations": {},
  "orders": [
    {
      "id": "order-month-001-${CASE_SUFFIX}",
      "buyerId": "buyer-1",
      "buyerName": "Buyer One",
      "createdAt": "${THIS_MONTH_PREFIX}-01T00:00:00Z",
      "readyAt": "${THIS_MONTH_PREFIX}-01T00:15:00Z",
      "status": "Completed",
      "total": 120,
      "items": []
    },
    {
      "id": "order-month-002-${CASE_SUFFIX}",
      "buyerId": "buyer-2",
      "buyerName": "Buyer Two",
      "createdAt": "${THIS_MONTH_PREFIX}-28T23:59:59Z",
      "readyAt": "${THIS_MONTH_PREFIX}-28T23:59:59Z",
      "status": "Completed",
      "total": 180,
      "items": []
    },
    {
      "id": "order-month-003-${CASE_SUFFIX}",
      "buyerId": "buyer-3",
      "buyerName": "Buyer Three",
      "createdAt": "${PREV_MONTH_PREFIX}-15T12:00:00Z",
      "readyAt": "${PREV_MONTH_PREFIX}-15T12:15:00Z",
      "status": "Completed",
      "total": 500,
      "items": []
    },
    {
      "id": "order-month-004-${CASE_SUFFIX}",
      "buyerId": "buyer-4",
      "buyerName": "Buyer Four",
      "createdAt": "${NEXT_MONTH_PREFIX}-01T00:00:00Z",
      "readyAt": "${NEXT_MONTH_PREFIX}-01T00:15:00Z",
      "status": "Completed",
      "total": 600,
      "items": []
    }
  ]
}
JSON

curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"admin-monthly-${CASE_SUFFIX}@gptcoffee.test\",\"password\":\"admin123\"}" \
  > "$LOGIN_FILE"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When — request sales metrics
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/admin/sales" > "$STATUS_FILE"

# Then — verify monthly total includes only current-month orders
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"monthly":300' "$RESPONSE_FILE" >/dev/null

echo 'CODEVALID_TEST_ASSERTION_OK:monthly_aggregation_accuracy'

# Cleanup — remove the test database file
rm -f "$DB_PATH"
