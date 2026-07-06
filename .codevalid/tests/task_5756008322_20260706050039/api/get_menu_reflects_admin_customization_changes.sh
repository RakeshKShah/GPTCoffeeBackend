#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="$(mktemp -d)"
LOGIN_RESPONSE="$TMP_DIR/login.json"
LOGIN_STATUS="$TMP_DIR/login.status"
PUT_RESPONSE="$TMP_DIR/put.json"
PUT_STATUS="$TMP_DIR/put.status"
MENU_RESPONSE="$TMP_DIR/menu.json"
MENU_STATUS="$TMP_DIR/menu.status"
DB_FILE="/tmp/test_gen_0h6sbpi5/src/data/db.json"
BACKUP_FILE="$TMP_DIR/db.backup.json"
cleanup_files() {
  if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" "$DB_FILE"
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

if [ -f "$DB_FILE" ]; then
  cp "$DB_FILE" "$BACKUP_FILE"
fi

# Given — ensure baseline data exists, authenticate as admin, and update customizations through the admin API
mkdir -p "$(dirname "$DB_FILE")"
cat > "$DB_FILE" <<'EOF'
{
  "users": [
    {
      "id": "buyer-sample",
      "name": "Maya Buyer",
      "email": "buyer@gptcoffee.test",
      "password": "buyer123",
      "role": "buyer"
    },
    {
      "id": "admin-sample",
      "name": "Ari Admin",
      "email": "admin@gptcoffee.test",
      "password": "admin123",
      "role": "admin"
    }
  ],
  "products": [
    {
      "id": "coffee-admin-base",
      "name": "Flat White",
      "note": "Baseline product",
      "description": "Used to anchor menu response",
      "price": 5.1,
      "strength": "Balanced",
      "gradient": "from-amber-300 via-orange-500 to-stone-900"
    }
  ],
  "customizations": {
    "milk": [
      { "id": "cust-401", "name": "Soy Milk", "label": "Soy Milk", "price": 0.6 }
    ]
  },
  "orders": []
}
EOF

curl -sS -o "$LOGIN_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"admin@gptcoffee.test","password":"admin123"}' > "$LOGIN_STATUS"
[ "$(cat "$LOGIN_STATUS")" = "200" ]
ADMIN_TOKEN="$(jq -r '.token' "$LOGIN_RESPONSE")"
[ -n "$ADMIN_TOKEN" ]
[ "$ADMIN_TOKEN" != "null" ]

cat > "$TMP_DIR/customizations.json" <<EOF
{
  "customizations": {
    "milk": [
      { "id": "cust-401", "name": "Organic Soy Milk", "label": "Organic Soy Milk", "price": 0.7 },
      { "id": "cust-402", "name": "Coconut Milk", "label": "Coconut Milk", "price": 0.9 }
    ],
    "size": [
      { "id": "size-classic-${CASE_SUFFIX}", "name": "Classic", "label": "Classic", "price": 0.75 }
    ]
  }
}
EOF

curl -sS -o "$PUT_RESPONSE" -w '%{http_code}' -X PUT "$BASE_URL/api/admin/customizations" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data @"$TMP_DIR/customizations.json" > "$PUT_STATUS"
[ "$(cat "$PUT_STATUS")" = "200" ]

# When — fetch the customer menu after the admin update
curl -sS -o "$MENU_RESPONSE" -w '%{http_code}' "$BASE_URL/api/menu" > "$MENU_STATUS"

# Then — verify the menu reflects the updated admin-managed customizations
STATUS="$(cat "$MENU_STATUS")"
[ "$STATUS" = "200" ]
jq -e '.customizations.milk[] | select(.id == "cust-401" and .name == "Organic Soy Milk")' "$MENU_RESPONSE" >/dev/null
jq -e '.customizations.milk[] | select(.id == "cust-402" and .name == "Coconut Milk")' "$MENU_RESPONSE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:get_menu_reflects_admin_customization_changes"

# Cleanup — restore original db.json via trap
