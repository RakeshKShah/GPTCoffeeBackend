#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
USER_EMAIL="newaccount-${CASE_SUFFIX}@example.com"
USER_NAME="New Account ${CASE_SUFFIX}"
USER_PASSWORD="newPass123"
SAMPLE_BUYER_EMAIL="buyer@gptcoffee.test"
SAMPLE_ADMIN_EMAIL="admin@gptcoffee.test"
RESPONSE_FILE="/tmp/signup_preserves_existing_sample_accounts_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/signup_preserves_existing_sample_accounts_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT
export USER_EMAIL USER_NAME USER_PASSWORD SAMPLE_BUYER_EMAIL SAMPLE_ADMIN_EMAIL RESPONSE_FILE CASE_SUFFIX

# Given
node --input-type=module <<'EOF'
import { readFile, writeFile } from 'node:fs/promises';
const dataPath = '/app/src/data/db.json';
let db;
try {
  db = JSON.parse(await readFile(dataPath, 'utf8'));
} catch (error) {
  if (error.code === 'ENOENT') {
    throw new Error('expected seeded database file with sample accounts');
  }
  throw error;
}
const buyer = db.users.find((user) => user.email === process.env.SAMPLE_BUYER_EMAIL);
const admin = db.users.find((user) => user.email === process.env.SAMPLE_ADMIN_EMAIL);
if (!buyer) throw new Error('sample buyer missing before test');
if (!admin) throw new Error('sample admin missing before test');
db.users = db.users.filter((user) => user.email !== process.env.USER_EMAIL);
await writeFile(dataPath, JSON.stringify(db, null, 2));
EOF

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"${USER_NAME}\",\"email\":\"${USER_EMAIL}\",\"password\":\"${USER_PASSWORD}\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
node --input-type=module <<'EOF'
import { readFile } from 'node:fs/promises';
const db = JSON.parse(await readFile('/app/src/data/db.json', 'utf8'));
const buyer = db.users.find((user) => user.email === process.env.SAMPLE_BUYER_EMAIL);
const admin = db.users.find((user) => user.email === process.env.SAMPLE_ADMIN_EMAIL);
const created = db.users.find((user) => user.email === process.env.USER_EMAIL);
if (!buyer) throw new Error('sample buyer missing after signup');
if (buyer.role !== 'buyer') throw new Error('sample buyer role changed');
if (!admin) throw new Error('sample admin missing after signup');
if (admin.role !== 'admin') throw new Error('sample admin role changed');
if (!created) throw new Error('new user missing');
if (created.role !== 'buyer') throw new Error('new user role mismatch');
EOF

echo "CODEVALID_TEST_ASSERTION_OK:signup_preserves_existing_sample_accounts"

# Cleanup
node --input-type=module <<'EOF'
import { readFile, writeFile } from 'node:fs/promises';
const dataPath = '/app/src/data/db.json';
const db = JSON.parse(await readFile(dataPath, 'utf8'));
db.users = db.users.filter((user) => user.email !== process.env.USER_EMAIL);
await writeFile(dataPath, JSON.stringify(db, null, 2));
EOF
