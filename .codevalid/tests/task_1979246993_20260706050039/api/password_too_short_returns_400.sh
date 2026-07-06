#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
USER_EMAIL="short-pass-${CASE_SUFFIX}@example.com"
USER_NAME="Short Pass ${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/password_too_short_returns_400_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/password_too_short_returns_400_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT
export USER_EMAIL RESPONSE_FILE CASE_SUFFIX

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
  --data "{\"name\":\"${USER_NAME}\",\"email\":\"${USER_EMAIL}\",\"password\":\"abc12\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "400" ]
grep -F 'Name, email, and a 6+ character password are required.' "$RESPONSE_FILE" >/dev/null
node --input-type=module <<'EOF'
import { readFile } from 'node:fs/promises';
try {
  const db = JSON.parse(await readFile('/app/src/data/db.json', 'utf8'));
  const user = db.users.find((candidate) => candidate.email === process.env.USER_EMAIL);
  if (user) throw new Error('user should not have been created');
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
}
EOF

echo "CODEVALID_TEST_ASSERTION_OK:password_too_short_returns_400"

# Cleanup
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
