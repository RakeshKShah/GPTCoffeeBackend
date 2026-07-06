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

# Given — seed a latte product and multiple customization categories
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
      "id": "coffee-501",
      "name": "Latte",
      "note": "Smooth espresso and milk",
      "description": "Classic cafe latte",
      "price": 5.2,
      "strength": "Mellow",
      "gradient": "from-rose-200 via-orange-600 to-stone-950"
    }
  ],
  "customizations": {
    "milk": [
      { "id": "milk-1", "name": "Whole Milk", "label": "Whole Milk", "price": 0 },
      { "id": "milk-2", "name": "Skim Milk", "label": "Skim Milk", "price": 0 },
      { "id": "milk-3", "name": "Oat Milk", "label": "Oat Milk", "price": 0.85 }
    ],
    "size": [
      { "id": "size-8", "name": "8oz", "label": "8oz", "price": 0 },
      { "id": "size-12", "name": "12oz", "label": "12oz", "price": 0.75 },
      { "id": "size-16", "name": "16oz", "label": "16oz", "price": 1.25 }
    ],
    "sweetener": [
      { "id": "sweet-1", "name": "Sugar", "label": "Sugar", "price": 0 },
      { "id": "sweet-2", "name": "Honey", "label": "Honey", "price": 0.4 },
      { "id": "sweet-3", "name": "Stevia", "label": "Stevia", "price": 0.3 }
    ]
  },
  "orders": []
}
EOF

# When — request the menu
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/menu" > "$STATUS_FILE"

# Then — verify multiple customization categories are present
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
jq -e '.products[] | select(.id == "coffee-501" and .name == "Latte")' "$RESPONSE_FILE" >/dev/null
jq -e '.customizations | has("milk") and has("size") and has("sweetener")' "$RESPONSE_FILE" >/dev/null
jq -e '.customizations.milk[] | select(.name == "Oat Milk")' "$RESPONSE_FILE" >/dev/null
jq -e '.customizations.size[] | select(.name == "16oz")' "$RESPONSE_FILE" >/dev/null
jq -e '.customizations.sweetener[] | select(.name == "Honey")' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:get_menu_returns_multiple_customization_types"

# Cleanup — restore original db.json via trap
