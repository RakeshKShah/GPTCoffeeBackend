#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
USER_EMAIL="existing-${CASE_SUFFIX}@example.com"
EXISTING_NAME="Existing User ${CASE_SUFFIX}"
EXISTING_PASSWORD="existingPass123"
RESPONSE_FILE="/tmp/duplicate_email_exact_returns_409_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/duplicate_email_exact_returns_409_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT
export USER_EMAIL EXISTING_NAME EXISTING_PASSWORD RESPONSE_FILE CASE_SUFFIX

# Given
node --input-type=module <<'EOF'
import { readFile, writeFile } from 'node:fs/promises';
const dataPath = '/app/src/data/db.json';
let db;
try {
  db = JSON.parse(await readFile(dataPath, 'utf8'));
} catch (error) {
  if (error.code === 'ENOENT') {
    db = { users: [], products: [], customizations: {}, orders: [] };
  } else {
    throw error;
  }
}
db.users = db.users.filter((user) => user.email !== process.env.USER_EMAIL);
db.users.push({
  id: `seed-${process.env.CASE_SUFFIX}`,
  name: process.env.EXISTING_NAME,
  email: process.env.USER_EMAIL,
  password: process.env.EXISTING_PASSWORD,
  role: 'buyer'
});
await writeFile(dataPath, JSON.stringify(db, null, 2));
EOF

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"New User\",\"email\":\"${USER_EMAIL}\",\"password\":\"newPass123\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "409" ]
grep -F 'That email is already registered.' "$RESPONSE_FILE" >/dev/null
node --input-type=module <<'EOF'
import { readFile } from 'node:fs/promises';
const db = JSON.parse(await readFile('/app/src/data/db.json', 'utf8'));
const matches = db.users.filter((candidate) => candidate.email === process.env.USER_EMAIL);
if (matches.length !== 1) throw new Error(`expected exactly one user, got ${matches.length}`);
if (matches[0].name !== process.env.EXISTING_NAME) throw new Error('existing user mutated');
if (matches[0].password !== process.env.EXISTING_PASSWORD) throw new Error('existing password mutated');
EOF

echo "CODEVALID_TEST_ASSERTION_OK:duplicate_email_exact_returns_409"

# Cleanup
node --input-type=module <<'EOF'
import { readFile, writeFile } from 'node:fs/promises';
const dataPath = '/app/src/data/db.json';
const db = JSON.parse(await readFile(dataPath, 'utf8'));
db.users = db.users.filter((user) => user.email !== process.env.USER_EMAIL);
await writeFile(dataPath, JSON.stringify(db, null, 2));
EOF
