#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_DIR="/workdir/src/data"
DB_PATH="$DB_DIR/db.json"
LOGIN_FILE="/tmp/orders_across_multiple_days_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/orders_across_multiple_days_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/orders_across_multiple_days_status_${CASE_SUFFIX}.txt"

cleanup_tmp() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_tmp EXIT

# Given — create an admin and orders across multiple days within the same current month
mkdir -p "$DB_DIR"
TODAY_UTC="$(date -u +%Y-%m-%d)"
THIS_MONTH_PREFIX="$(date -u +%Y-%m)"
cat > "$DB_PATH" <<JSON
{
  "users": [
    {
      "id": "admin-multiday-${CASE_SUFFIX}",
      "name": "Admin Multi Day ${CASE_SUFFIX}",
      "email": "admin-multiday-${CASE_SUFFIX}@gptcoffee.test",
      "password": "admin123",
      "role": "admin"
    }
  ],
  "products": [],
  "customizations": {},
  "orders": [
    {
      "id": "order-multi-001-${CASE_SUFFIX}",
      "buyerId": "buyer-1",
      "buyerName": "Buyer One",
      "createdAt": "${THIS_MONTH_PREFIX}-01T10:00:00Z",
      "readyAt": "${THIS_MONTH_PREFIX}-01T10:15:00Z",
      "status": "Completed",
      "total": 50,
      "items": []
    },
    {
      "id": "order-multi-002-${CASE_SUFFIX}",
      "buyerId": "buyer-2",
      "buyerName": "Buyer Two",
      "createdAt": "${THIS_MONTH_PREFIX}-10T15:00:00Z",
      "readyAt": "${THIS_MONTH_PREFIX}-10T15:15:00Z",
      "status": "Completed",
      "total": 75,
      "items": []
    },
    {
      "id": "order-multi-003-${CASE_SUFFIX}",
      "buyerId": "buyer-3",
      "buyerName": "Buyer Three",
      "createdAt": "${TODAY_UTC}T08:00:00Z",
      "readyAt": "${TODAY_UTC}T08:15:00Z",
      "status": "Completed",
      "total": 100,
      "items": []
    }
  ]
}
JSON

curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"admin-multiday-${CASE_SUFFIX}@gptcoffee.test\",\"password\":\"admin123\"}" \
  > "$LOGIN_FILE"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When — request the sales dashboard
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/admin/sales" > "$STATUS_FILE"

# Then — verify daily, monthly, total, and order count values
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"daily":100' "$RESPONSE_FILE" >/dev/null
grep -F '"monthly":225' "$RESPONSE_FILE" >/dev/null
grep -F '"total":225' "$RESPONSE_FILE" >/dev/null
grep -F '"orderCount":3' "$RESPONSE_FILE" >/dev/null

echo 'CODEVALID_TEST_ASSERTION_OK:orders_across_multiple_days'

# Cleanup — remove the test database file
rm -f "$DB_PATH"
