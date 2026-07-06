#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_DIR="/workdir/src/data"
DB_PATH="$DB_DIR/db.json"
LOGIN_FILE="/tmp/year_boundary_january_orders_login_${CASE_SUFFIX}.json"
RESPONSE_FILE="/tmp/year_boundary_january_orders_response_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/year_boundary_january_orders_status_${CASE_SUFFIX}.txt"

cleanup_tmp() {
  rm -f "$LOGIN_FILE" "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_tmp EXIT

# Given — create an admin with current-month and prior-year previous-month orders to validate boundary behavior
mkdir -p "$DB_DIR"
TODAY_UTC="$(date -u +%Y-%m-%d)"
THIS_MONTH_PREFIX="$(date -u +%Y-%m)"
PREV_MONTH_PREFIX="$(date -u -d "$(date -u +%Y-%m-01) -1 day" +%Y-%m)"
cat > "$DB_PATH" <<JSON
{
  "users": [
    {
      "id": "admin-boundary-${CASE_SUFFIX}",
      "name": "Admin Boundary ${CASE_SUFFIX}",
      "email": "admin-boundary-${CASE_SUFFIX}@gptcoffee.test",
      "password": "admin123",
      "role": "admin"
    }
  ],
  "products": [],
  "customizations": {},
  "orders": [
    {
      "id": "order-boundary-001-${CASE_SUFFIX}",
      "buyerId": "buyer-1",
      "buyerName": "Buyer One",
      "createdAt": "${THIS_MONTH_PREFIX}-15T12:00:00Z",
      "readyAt": "${THIS_MONTH_PREFIX}-15T12:15:00Z",
      "status": "Completed",
      "total": 250,
      "items": []
    },
    {
      "id": "order-boundary-002-${CASE_SUFFIX}",
      "buyerId": "buyer-2",
      "buyerName": "Buyer Two",
      "createdAt": "${TODAY_UTC}T09:00:00Z",
      "readyAt": "${TODAY_UTC}T09:15:00Z",
      "status": "Completed",
      "total": 150,
      "items": []
    },
    {
      "id": "order-boundary-003-${CASE_SUFFIX}",
      "buyerId": "buyer-3",
      "buyerName": "Buyer Three",
      "createdAt": "${PREV_MONTH_PREFIX}-28T23:00:00Z",
      "readyAt": "${PREV_MONTH_PREFIX}-28T23:15:00Z",
      "status": "Completed",
      "total": 400,
      "items": []
    }
  ]
}
JSON

curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"admin-boundary-${CASE_SUFFIX}@gptcoffee.test\",\"password\":\"admin123\"}" \
  > "$LOGIN_FILE"
TOKEN="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$LOGIN_FILE")"
[ -n "$TOKEN" ]

# When — request sales metrics
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/admin/sales" > "$STATUS_FILE"

# Then — verify current-month aggregation and total across the boundary
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"daily":150' "$RESPONSE_FILE" >/dev/null
grep -F '"monthly":400' "$RESPONSE_FILE" >/dev/null
grep -F '"total":800' "$RESPONSE_FILE" >/dev/null
grep -F '"orderCount":3' "$RESPONSE_FILE" >/dev/null

echo 'CODEVALID_TEST_ASSERTION_OK:year_boundary_january_orders'

# Cleanup — remove the test database file
rm -f "$DB_PATH"
