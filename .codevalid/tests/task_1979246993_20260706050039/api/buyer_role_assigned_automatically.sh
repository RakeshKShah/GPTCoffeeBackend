#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
USER_EMAIL="buyertest-${CASE_SUFFIX}@example.com"
USER_NAME="Buyer User ${CASE_SUFFIX}"
USER_PASSWORD="buyerPass123"
RESPONSE_FILE="/tmp/buyer_role_assigned_automatically_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/buyer_role_assigned_automatically_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT
export USER_EMAIL USER_NAME USER_PASSWORD RESPONSE_FILE CASE_SUFFIX

# Given
node --input-type=module <<'EOF'
import { readFile, writeFile } from 'node:fs/promises';
const dataPath = '/app/src/data/db.json';
try {
  const db = JSON.parse(await readFile(dataPath, 'utf8'));
  db.users = db.users.filter((user) => user.email !== process.env.USER_EMAIL);
  await writeFile(dataPath, JSON.stringify(db, null, 2));
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
}
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
const body = JSON.parse(await readFile(process.env.RESPONSE_FILE, 'utf8'));
if (body.user.role !== 'buyer') throw new Error('response role was not buyer');
const db = JSON.parse(await readFile('/app/src/data/db.json', 'utf8'));
const user = db.users.find((candidate) => candidate.email === process.env.USER_EMAIL);
if (!user) throw new Error('user missing from database');
if (user.role !== 'buyer') throw new Error('stored role was not buyer');
EOF

echo "CODEVALID_TEST_ASSERTION_OK:buyer_role_assigned_automatically"

# Cleanup
node --input-type=module <<'EOF'
import { readFile, writeFile } from 'node:fs/promises';
const dataPath = '/app/src/data/db.json';
const db = JSON.parse(await readFile(dataPath, 'utf8'));
db.users = db.users.filter((user) => user.email !== process.env.USER_EMAIL);
await writeFile(dataPath, JSON.stringify(db, null, 2));
EOF
