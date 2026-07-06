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

# Given — seed at least one product and one customization option
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
      "id": "coffee-001",
      "name": "Espresso",
      "note": "Rich and concentrated",
      "description": "Short pulled espresso shot",
      "price": 3.5,
      "strength": "Bold",
      "gradient": "from-amber-300 via-orange-500 to-stone-900"
    }
  ],
  "customizations": {
    "milk": [
      { "id": "cust-101", "name": "Oat Milk", "label": "Oat Milk", "price": 0.6 },
      { "id": "cust-102", "name": "Almond Milk", "label": "Almond Milk", "price": 0.5 }
    ]
  },
  "orders": []
}
EOF

# When — request the customer menu
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/menu" > "$STATUS_FILE"

# Then — verify both products and customizations are returned
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
jq -e '.products | type == "array" and length >= 1' "$RESPONSE_FILE" >/dev/null
jq -e '.products[] | select(.id == "coffee-001" and .name == "Espresso")' "$RESPONSE_FILE" >/dev/null
jq -e '.customizations.milk[] | select(.id == "cust-101")' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:get_menu_returns_products_and_customizations"

# Cleanup — restore original db.json via trap
