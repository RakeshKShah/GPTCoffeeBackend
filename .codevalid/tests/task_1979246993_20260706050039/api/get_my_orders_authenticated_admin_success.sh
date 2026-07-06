#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DB_FILE="/app/src/data/db.json"
BACKUP_FILE="/tmp/get_my_orders_authenticated_admin_success_${CASE_SUFFIX}.db.json.bak"
RESPONSE_FILE="/tmp/get_my_orders_authenticated_admin_success_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/get_my_orders_authenticated_admin_success_${CASE_SUFFIX}.status"
ADMIN_ID="admin-01-${CASE_SUFFIX}"
OTHER_BUYER_ID="buyer-x-${CASE_SUFFIX}"
ADMIN_TOKEN="$(node -e "process.stdout.write(Buffer.from(JSON.stringify({userId: process.argv[1], role: 'admin'})).toString('base64url'))" "$ADMIN_ID")"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$BACKUP_FILE"
}
trap cleanup_files EXIT

# Given — create isolated admin user and orders in the file-backed database
mkdir -p /app/src/data
if [ -f "$DB_FILE" ]; then
  cp "$DB_FILE" "$BACKUP_FILE"
else
  printf '%s' '{"users":[],"products":[],"customizations":{},"orders":[]}' > "$BACKUP_FILE"
fi
DB_FILE="$DB_FILE" ADMIN_ID="$ADMIN_ID" OTHER_BUYER_ID="$OTHER_BUYER_ID" node --input-type=module - <<'EOF'
import { readFile, writeFile } from 'node:fs/promises';
const dbFile = process.env.DB_FILE;
const adminId = process.env.ADMIN_ID;
const otherBuyerId = process.env.OTHER_BUYER_ID;
let db;
try {
  db = JSON.parse(await readFile(dbFile, 'utf8'));
} catch {
  db = { users: [], products: [], customizations: {}, orders: [] };
}
for (const user of [
  { id: adminId, name: 'Case Admin', email: `case-admin-${adminId}@example.test`, password: 'admin123', role: 'admin' },
  { id: otherBuyerId, name: 'Other Buyer', email: `other-buyer-${otherBuyerId}@example.test`, password: 'buyer123', role: 'buyer' },
]) {
  if (!db.users.some((candidate) => candidate.id === user.id)) db.users.push(user);
}
db.orders = [
  {
    id: `ORD-MINE-${adminId}`,
    buyerId: adminId,
    buyerName: 'Case Admin',
    createdAt: new Date().toISOString(),
    readyAt: new Date(Date.now() + 900000).toISOString(),
    status: 'Placed',
    total: 120,
    items: [{ id: `item-${adminId}`, productName: 'Golden Cortado', quantity: 1, total: 120 }],
  },
  {
    id: `ORD-OTHER-${otherBuyerId}`,
    buyerId: otherBuyerId,
    buyerName: 'Other Buyer',
    createdAt: new Date().toISOString(),
    readyAt: new Date(Date.now() + 900000).toISOString(),
    status: 'Placed',
    total: 22,
    items: [{ id: `item-${otherBuyerId}`, productName: 'Ember Cold Brew', quantity: 1, total: 22 }],
  },
  ...(db.orders || []),
];
await writeFile(dbFile, JSON.stringify(db, null, 2));
EOF

# When — request my orders as the isolated admin
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "$BASE_URL/api/orders/my" > "$STATUS_FILE"

# Then — the admin can access the endpoint and sees only their own orders
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"orders":' "$RESPONSE_FILE"
grep -F "ORD-MINE-${ADMIN_ID}" "$RESPONSE_FILE"
grep -F "\"buyerId\":\"${ADMIN_ID}\"" "$RESPONSE_FILE"
if grep -F "ORD-OTHER-${OTHER_BUYER_ID}" "$RESPONSE_FILE" >/dev/null 2>&1; then
  echo "unexpected other buyer order present"
  exit 1
fi

# Cleanup — restore the original file-backed database
cp "$BACKUP_FILE" "$DB_FILE"

echo 'CODEVALID_TEST_ASSERTION_OK:get_my_orders_authenticated_admin_success'
