#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_FILE="/app/src/data/db.json"
BACKUP_FILE="/tmp/get_my_orders_authenticated_customer_success_${CASE_SUFFIX}.db.json.bak"
RESPONSE_FILE="/tmp/get_my_orders_authenticated_customer_success_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/get_my_orders_authenticated_customer_success_${CASE_SUFFIX}.status"
BUYER_ID="buyer-01-${CASE_SUFFIX}"
OTHER_BUYER_ID="buyer-02-${CASE_SUFFIX}"
BUYER_TOKEN="$(node -e "process.stdout.write(Buffer.from(JSON.stringify({userId: process.argv[1], role: 'buyer'})).toString('base64url'))" "$BUYER_ID")"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$BACKUP_FILE"
}
trap cleanup_files EXIT

# Given — create isolated users and orders directly in the file-backed app database
mkdir -p /app/src/data
if [ -f "$DB_FILE" ]; then
  cp "$DB_FILE" "$BACKUP_FILE"
else
  printf '%s' '{"users":[],"products":[],"customizations":{},"orders":[]}' > "$BACKUP_FILE"
fi
DB_FILE="$DB_FILE" BUYER_ID="$BUYER_ID" OTHER_BUYER_ID="$OTHER_BUYER_ID" node --input-type=module - <<'EOF'
import { readFile, writeFile } from 'node:fs/promises';
const dbFile = process.env.DB_FILE;
const buyerId = process.env.BUYER_ID;
const otherBuyerId = process.env.OTHER_BUYER_ID;
let db;
try {
  db = JSON.parse(await readFile(dbFile, 'utf8'));
} catch {
  db = { users: [], products: [], customizations: {}, orders: [] };
}
for (const user of [
  { id: buyerId, name: 'Case Buyer', email: `case-buyer-${buyerId}@example.test`, password: 'buyer123', role: 'buyer' },
  { id: otherBuyerId, name: 'Other Buyer', email: `other-buyer-${otherBuyerId}@example.test`, password: 'buyer123', role: 'buyer' },
]) {
  if (!db.users.some((candidate) => candidate.id === user.id)) db.users.push(user);
}
db.orders = [
  {
    id: `ORD-MINE-${buyerId}`,
    buyerId,
    buyerName: 'Case Buyer',
    createdAt: new Date().toISOString(),
    readyAt: new Date(Date.now() + 900000).toISOString(),
    status: 'Placed',
    total: 50,
    items: [{ id: `item-${buyerId}`, productName: 'Velvet Latte', quantity: 1, total: 50 }],
  },
  {
    id: `ORD-OTHER-${otherBuyerId}`,
    buyerId: otherBuyerId,
    buyerName: 'Other Buyer',
    createdAt: new Date().toISOString(),
    readyAt: new Date(Date.now() + 900000).toISOString(),
    status: 'Placed',
    total: 15,
    items: [{ id: `item-${otherBuyerId}`, productName: 'Midnight Mocha', quantity: 1, total: 15 }],
  },
  ...(db.orders || []),
];
await writeFile(dbFile, JSON.stringify(db, null, 2));
EOF

# When — request my orders as the isolated customer
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer ${BUYER_TOKEN}" \
  "$BASE_URL/api/orders/my" > "$STATUS_FILE"

# Then — only the authenticated buyer's orders are returned
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"orders":' "$RESPONSE_FILE"
grep -F "ORD-MINE-${BUYER_ID}" "$RESPONSE_FILE"
grep -F "\"buyerId\":\"${BUYER_ID}\"" "$RESPONSE_FILE"
if grep -F "ORD-OTHER-${OTHER_BUYER_ID}" "$RESPONSE_FILE" >/dev/null 2>&1; then
  echo "unexpected other buyer order present"
  exit 1
fi

# Cleanup — restore the original file-backed database
cp "$BACKUP_FILE" "$DB_FILE"

echo 'CODEVALID_TEST_ASSERTION_OK:get_my_orders_authenticated_customer_success'
