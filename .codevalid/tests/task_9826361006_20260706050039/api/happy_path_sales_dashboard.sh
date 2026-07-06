#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_DIR="/workdir/src/data"
DB_PATH="$DB_DIR/db.json"
LOGIN_FILE="/tmp/happy_path_sales_dashboard_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/happy_path_sales_dashboard_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/happy_path_sales_dashboard_status_${CASE_SUFFIX}.txt"

cleanup_tmp() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_tmp EXIT

# Given — create an isolated admin user and orders for today, this month, and a prior month
mkdir -p "$DB_DIR"
TODAY_UTC="$(date -u +%Y-%m-%d)"
THIS_MONTH_PREFIX="$(date -u +%Y-%m)"
PREV_MONTH_PREFIX="$(date -u -d "$(date -u +%Y-%m-01) -1 day" +%Y-%m)"
cat > "$DB_PATH" <<JSON
{
  "users": [
    {
      "id": "admin-happy-${CASE_SUFFIX}",
      "name": "Admin Happy ${CASE_SUFFIX}",
      "email": "admin-happy-${CASE_SUFFIX}@gptcoffee.test",
      "password": "admin123",
      "role": "admin"
    }
  ],
  "products": [],
  "customizations": {},
  "orders": [
    {
      "id": "order-happy-001-${CASE_SUFFIX}",
      "buyerId": "buyer-001",
      "buyerName": "Buyer One",
      "createdAt": "${TODAY_UTC}T10:30:00Z",
      "readyAt": "${TODAY_UTC}T10:45:00Z",
      "status": "Completed",
      "total": 150,
      "items": []
    },
    {
      "id": "order-happy-002-${CASE_SUFFIX}",
      "buyerId": "buyer-002",
      "buyerName": "Buyer Two",
      "createdAt": "${TODAY_UTC}T14:45:00Z",
      "readyAt": "${TODAY_UTC}T15:00:00Z",
      "status": "Completed",
      "total": 75.5,
      "items": []
    },
    {
      "id": "order-happy-003-${CASE_SUFFIX}",
      "buyerId": "buyer-003",
      "buyerName": "Buyer Three",
      "createdAt": "${THIS_MONTH_PREFIX}-10T09:00:00Z",
      "readyAt": "${THIS_MONTH_PREFIX}-10T09:15:00Z",
      "status": "Completed",
      "total": 200,
      "items": []
    },
    {
      "id": "order-happy-004-${CASE_SUFFIX}",
      "buyerId": "buyer-004",
      "buyerName": "Buyer Four",
      "createdAt": "${PREV_MONTH_PREFIX}-20T16:00:00Z",
      "readyAt": "${PREV_MONTH_PREFIX}-20T16:15:00Z",
      "status": "Completed",
      "total": 300,
      "items": []
    }
  ]
}
JSON

curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"admin-happy-${CASE_SUFFIX}@gptcoffee.test\",\"password\":\"admin123\"}" \
  > "$LOGIN_FILE"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When — request the admin sales dashboard
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/admin/sales" > "$STATUS_FILE"

# Then — assert the response includes the expected daily, monthly, total, and orderCount values
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"daily":225.5' "$RESPONSE_FILE" >/dev/null
grep -F '"monthly":425.5' "$RESPONSE_FILE" >/dev/null
grep -F '"total":725.5' "$RESPONSE_FILE" >/dev/null
grep -F '"orderCount":4' "$RESPONSE_FILE" >/dev/null

echo 'CODEVALID_TEST_ASSERTION_OK:happy_path_sales_dashboard'

# Cleanup — remove the test database file
rm -f "$DB_PATH"
