#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
DB_FILE="/tmp/test_gen_0h6sbpi5/src/data/db.json"
TMP_DIR="$(mktemp -d)"
RESPONSE_FILE="$TMP_DIR/response.json"
STATUS_FILE="$TMP_DIR/status.txt"
BACKUP_FILE="$TMP_DIR/db.backup.json"
cleanup_files() {
  if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" "$DB_FILE"
  else
    rm -f "$DB_FILE"
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

if [ -f "$DB_FILE" ]; then
  cp "$DB_FILE" "$BACKUP_FILE"
fi

# Given — seed one product and no customizations
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
      "id": "coffee-301",
      "name": "Cappuccino",
      "note": "Foamy and balanced",
      "description": "Espresso with steamed milk foam",
      "price": 4.8,
      "strength": "Balanced",
      "gradient": "from-yellow-200 via-amber-500 to-stone-950"
    }
  ],
  "customizations": {},
  "orders": []
}
EOF

# When — request the menu
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/menu" > "$STATUS_FILE"

# Then — verify product exists and customizations are empty
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
jq -e '.products[] | select(.id == "coffee-301" and .name == "Cappuccino")' "$RESPONSE_FILE" >/dev/null
jq -e '.customizations == {}' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:get_menu_empty_customizations_returns_products"

# Cleanup — restore original db.json via trap
