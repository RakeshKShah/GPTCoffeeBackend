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

# Given — seed customization objects with checkout-relevant identifiers and prices
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
      "id": "coffee-601",
      "name": "House Roast",
      "note": "Simple daily coffee",
      "description": "Balanced brewed coffee",
      "price": 3.25,
      "strength": "Balanced",
      "gradient": "from-amber-300 via-orange-500 to-stone-900"
    }
  ],
  "customizations": {
    "extras": [
      { "id": "cust-601", "name": "Extra Shot", "label": "Extra Shot", "price": 0.75 },
      { "id": "cust-602", "name": "Vanilla Syrup", "label": "Vanilla Syrup", "price": 0.5 }
    ]
  },
  "orders": []
}
EOF

# When — request the menu
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/menu" > "$STATUS_FILE"

# Then — verify customization entries expose id, name/label, and price data
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
jq -e '.customizations.extras[] | select(.id == "cust-601" and .name == "Extra Shot" and .price == 0.75)' "$RESPONSE_FILE" >/dev/null
jq -e '.customizations.extras[] | select(.id == "cust-602" and .name == "Vanilla Syrup" and .price == 0.5)' "$RESPONSE_FILE" >/dev/null

echo "CODEVALID_TEST_ASSERTION_OK:get_menu_customizations_have_required_fields_for_checkout"

# Cleanup — restore original db.json via trap
