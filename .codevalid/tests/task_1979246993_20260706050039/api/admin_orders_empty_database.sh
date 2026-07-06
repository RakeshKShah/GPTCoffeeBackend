#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_FILE="${DB_FILE:-/app/src/data/db.json}"
TMP_DIR="$(mktemp -d)"
BACKUP_DB="$TMP_DIR/db-backup-${CASE_SUFFIX}.json"
LOGIN_BODY="$TMP_DIR/admin_login_${CASE_SUFFIX}.json"
ORDERS_BODY="$TMP_DIR/empty_orders_${CASE_SUFFIX}.json"
LOGIN_STATUS="$TMP_DIR/admin_login_${CASE_SUFFIX}.status"
ORDERS_STATUS="$TMP_DIR/empty_orders_${CASE_SUFFIX}.status"
restore_db() {
  if [ -f "$BACKUP_DB" ]; then
    cp "$BACKUP_DB" "$DB_FILE"
  fi
  rm -rf "$TMP_DIR"
}
trap restore_db EXIT

# Given
mkdir -p "$(dirname "$DB_FILE")"
if [ -f "$DB_FILE" ]; then
  cp "$DB_FILE" "$BACKUP_DB"
else
  node -e "const fs=require('fs'); const file=process.argv[1]; const db={users:[{id:'buyer-sample',name:'Maya Buyer',email:'buyer@gptcoffee.test',password:'buyer123',role:'buyer'},{id:'admin-sample',name:'Ari Admin',email:'admin@gptcoffee.test',password:'admin123',role:'admin'}],products:[],customizations:{},orders:[]}; fs.writeFileSync(file, JSON.stringify(db, null, 2)); fs.writeFileSync(process.argv[2], JSON.stringify(db, null, 2));" "$DB_FILE" "$BACKUP_DB"
fi
node -e "const fs=require('fs'); const file=process.argv[1]; const db=JSON.parse(fs.readFileSync(file,'utf8')); db.orders=[]; fs.writeFileSync(file, JSON.stringify(db, null, 2));" "$DB_FILE"

curl -sS \
  -o "$LOGIN_BODY" \
  -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$LOGIN_STATUS"

LOGIN_CODE="$(cat "$LOGIN_STATUS")"
[ "$LOGIN_CODE" = "200" ]
ADMIN_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(data.token || '');" "$LOGIN_BODY")"
[ -n "$ADMIN_TOKEN" ]

# When
curl -sS \
  -o "$ORDERS_BODY" \
  -w '%{http_code}' \
  -X GET "$BASE_URL/api/admin/orders" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > "$ORDERS_STATUS"

# Then
ORDERS_CODE="$(cat "$ORDERS_STATUS")"
[ "$ORDERS_CODE" = "200" ]
grep -F '"orders":[]' "$ORDERS_BODY" >/dev/null
EMPTY_COUNT="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(String(Array.isArray(data.orders) ? data.orders.length : -1));" "$ORDERS_BODY")"
[ "$EMPTY_COUNT" = "0" ]

echo "CODEVALID_TEST_ASSERTION_OK:admin_orders_empty_database"

# Cleanup
# Original file-backed DB is restored by trap.
