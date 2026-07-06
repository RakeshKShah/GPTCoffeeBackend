#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
USER_EMAIL="tokentest-${CASE_SUFFIX}@example.com"
USER_NAME="Token Test ${CASE_SUFFIX}"
USER_PASSWORD="tokenPass123"
RESPONSE_FILE="/tmp/response_includes_token_and_user_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/response_includes_token_and_user_${CASE_SUFFIX}.status"
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
if (!body.token || typeof body.token !== 'string') throw new Error('missing token');
if (!body.user) throw new Error('missing user');
for (const field of ['id', 'name', 'email', 'role']) {
  if (!(field in body.user)) throw new Error(`missing field ${field}`);
}
if ('password' in body.user) throw new Error('password field should be omitted');
if (body.user.email !== process.env.USER_EMAIL) throw new Error('wrong email');
if (body.user.name !== process.env.USER_NAME) throw new Error('wrong name');
if (body.user.role !== 'buyer') throw new Error('wrong role');
if (!String(body.user.id).startsWith('buyer-')) throw new Error('unexpected id format');
EOF

echo "CODEVALID_TEST_ASSERTION_OK:response_includes_token_and_user"

# Cleanup
node --input-type=module <<'EOF'
import { readFile, writeFile } from 'node:fs/promises';
const dataPath = '/app/src/data/db.json';
const db = JSON.parse(await readFile(dataPath, 'utf8'));
db.users = db.users.filter((user) => user.email !== process.env.USER_EMAIL);
await writeFile(dataPath, JSON.stringify(db, null, 2));
EOF
