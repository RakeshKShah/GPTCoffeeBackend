#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_FILE="/app/src/data/db.json"
BACKUP_FILE="/tmp/get_my_orders_precreated_sample_accounts_${CASE_SUFFIX}.db.json.bak"
BUYER_LOGIN_FILE="/tmp/get_my_orders_precreated_sample_accounts_${CASE_SUFFIX}_buyer_login.json"
ADMIN_LOGIN_FILE="/tmp/get_my_orders_precreated_sample_accounts_${CASE_SUFFIX}_admin_login.json"
BUYER_RESPONSE_FILE="/tmp/get_my_orders_precreated_sample_accounts_${CASE_SUFFIX}_buyer_orders.json"
ADMIN_RESPONSE_FILE="/tmp/get_my_orders_precreated_sample_accounts_${CASE_SUFFIX}_admin_orders.json"
BUYER_STATUS_FILE="/tmp/get_my_orders_precreated_sample_accounts_${CASE_SUFFIX}_buyer.status"
ADMIN_STATUS_FILE="/tmp/get_my_orders_precreated_sample_accounts_${CASE_SUFFIX}_admin.status"
BUYER_TOKEN_FILE="/tmp/get_my_orders_precreated_sample_accounts_${CASE_SUFFIX}_buyer.token"
ADMIN_TOKEN_FILE="/tmp/get_my_orders_precreated_sample_accounts_${CASE_SUFFIX}_admin.token"
cleanup_files() {
  rm -f "$BACKUP_FILE" "$BUYER_LOGIN_FILE" "$ADMIN_LOGIN_FILE" "$BUYER_RESPONSE_FILE" "$ADMIN_RESPONSE_FILE" "$BUYER_STATUS_FILE" "$ADMIN_STATUS_FILE" "$BUYER_TOKEN_FILE" "$ADMIN_TOKEN_FILE"
}
trap cleanup_files EXIT

# Given — preserve current db and ensure sample buyer/admin each have at least one order
mkdir -p /app/src/data
if [ -f "$DB_FILE" ]; then
  cp "$DB_FILE" "$BACKUP_FILE"
else
  printf '%s' '{"users":[],"products":[],"customizations":{},"orders":[]}' > "$BACKUP_FILE"
fi
DB_FILE="$DB_FILE" CASE_SUFFIX="$CASE_SUFFIX" node --input-type=module - <<'EOF'
import { readFile, writeFile } from 'node:fs/promises';
const dbFile = process.env.DB_FILE;
const suffix = process.env.CASE_SUFFIX;
let db;
try {
  db = JSON.parse(await readFile(dbFile, 'utf8'));
} catch {
  db = { users: [], products: [], customizations: {}, orders: [] };
}
const sampleUsers = [
  { id: 'buyer-sample', name: 'Maya Buyer', email: 'buyer@gptcoffee.test', password: 'buyer123', role: 'buyer' },
  { id: 'admin-sample', name: 'Ari Admin', email: 'admin@gptcoffee.test', password: 'admin123', role: 'admin' },
];
for (const user of sampleUsers) {
  if (!db.users.some((candidate) => candidate.id === user.id)) db.users.push(user);
}
const existingOrderIds = new Set((db.orders || []).map((order) => order.id));
const candidateOrders = [
  {
    id: `ORD-SAMPLE-BUYER-${suffix}`,
    buyerId: 'buyer-sample',
    buyerName: 'Maya Buyer',
    createdAt: new Date().toISOString(),
    readyAt: new Date(Date.now() + 900000).toISOString(),
    status: 'Placed',
    total: 9.5,
    items: [{ id: `item-buyer-${suffix}`, productName: 'Velvet Latte', quantity: 1, total: 9.5 }],
  },
  {
    id: `ORD-SAMPLE-ADMIN-${suffix}`,
    buyerId: 'admin-sample',
    buyerName: 'Ari Admin',
    createdAt: new Date().toISOString(),
    readyAt: new Date(Date.now() + 900000).toISOString(),
    status: 'Placed',
    total: 13.25,
    items: [{ id: `item-admin-${suffix}`, productName: 'Midnight Mocha', quantity: 1, total: 13.25 }],
  },
];
for (const order of candidateOrders.reverse()) {
  if (!existingOrderIds.has(order.id)) db.orders.unshift(order);
}
await writeFile(dbFile, JSON.stringify(db, null, 2));
EOF

# When — authenticate as sample buyer and sample admin, then request each account's orders
curl -sS -o "$BUYER_LOGIN_FILE" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d '{"email":"buyer@gptcoffee.test","password":"buyer123"}' \
  "$BASE_URL/api/auth/login" > "$BUYER_STATUS_FILE"
[ "$(cat "$BUYER_STATUS_FILE")" = "200" ]
node -e "const fs=require('fs');const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));if(!data.token) process.exit(1);process.stdout.write(data.token)" "$BUYER_LOGIN_FILE" > "$BUYER_TOKEN_FILE"

curl -sS -o "$BUYER_RESPONSE_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer $(cat "$BUYER_TOKEN_FILE")" \
  "$BASE_URL/api/orders/my" > "$BUYER_STATUS_FILE"

curl -sS -o "$ADMIN_LOGIN_FILE" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@gptcoffee.test","password":"admin123"}' \
  "$BASE_URL/api/auth/login" > "$ADMIN_STATUS_FILE"
[ "$(cat "$ADMIN_STATUS_FILE")" = "200" ]
node -e "const fs=require('fs');const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));if(!data.token) process.exit(1);process.stdout.write(data.token)" "$ADMIN_LOGIN_FILE" > "$ADMIN_TOKEN_FILE"

curl -sS -o "$ADMIN_RESPONSE_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer $(cat "$ADMIN_TOKEN_FILE")" \
  "$BASE_URL/api/orders/my" > "$ADMIN_STATUS_FILE"

# Then — both pre-created accounts authenticate and retrieve only their own orders
[ "$(cat "$BUYER_STATUS_FILE")" = "200" ]
[ "$(cat "$ADMIN_STATUS_FILE")" = "200" ]
grep -F '"buyer":{"id":"buyer-sample"' "$BUYER_LOGIN_FILE"
grep -F '"user":{"id":"admin-sample"' "$ADMIN_LOGIN_FILE"
grep -F '"orders":' "$BUYER_RESPONSE_FILE"
grep -F '"buyerId":"buyer-sample"' "$BUYER_RESPONSE_FILE"
grep -F 'ORD-SAMPLE-BUYER-' "$BUYER_RESPONSE_FILE"
if grep -F '"buyerId":"admin-sample"' "$BUYER_RESPONSE_FILE" >/dev/null 2>&1; then
  echo 'buyer response unexpectedly contains admin orders'
  exit 1
fi
grep -F '"orders":' "$ADMIN_RESPONSE_FILE"
grep -F '"buyerId":"admin-sample"' "$ADMIN_RESPONSE_FILE"
grep -F 'ORD-SAMPLE-ADMIN-' "$ADMIN_RESPONSE_FILE"
if grep -F '"buyerId":"buyer-sample"' "$ADMIN_RESPONSE_FILE" >/dev/null 2>&1; then
  echo 'admin response unexpectedly contains buyer orders'
  exit 1
fi

# Cleanup — restore original file-backed database
cp "$BACKUP_FILE" "$DB_FILE"

echo 'CODEVALID_TEST_ASSERTION_OK:get_my_orders_precreated_sample_accounts'
