#!/bin/bash
# === EVILGINX3 SECURITY HARDENING SUITE ===
# Purpose: Comprehensive security hardening for Evilginx3 deployments
# Features: System hardening, firewall configuration, intrusion detection, log monitoring

set -euo pipefail

### === CONFIGURATION ===
EVILGINX_DIR="/opt/posh-ai/evilginx3"
SECURITY_LOG="/var/log/evilginx3-security.log"
FAIL2BAN_JAIL="/etc/fail2ban/jail.d/evilginx3.conf"
UFW_RULES_FILE="/etc/ufw/applications.d/evilginx3"
OSSEC_CONFIG="/var/ossec/etc/ossec.conf"

### === UTILITIES ===
log() { 
    echo -e "\033[1;31m[SECURITY]\033[0m $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$SECURITY_LOG"
}
warn() { echo -e "\033[1;33m[WARNING]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
fatal() { error "$*"; exit 1; }

### === SYSTEM HARDENING ===
harden_system() {
    log "Starting system hardening..."
    
    # Disable unnecessary services
    log "Disabling unnecessary services..."
    local services_to_disable=(
        "bluetooth"
        "cups"
        "avahi-daemon"
        "whoopsie"
        "apport"
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            systemctl disable "$service" >/dev/null 2>&1 || true
            systemctl stop "$service" >/dev/null 2>&1 || true
            log "  ✓ Disabled $service"
        fi
    done
    
    # Configure kernel parameters
    log "Hardening kernel parameters..."
    cat > /etc/sysctl.d/99-evilginx3-security.conf <<EOF
# Network security
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Memory protection
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1

# File system security
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.suid_dumpable = 0
EOF
    
    sysctl -p /etc/sysctl.d/99-evilginx3-security.conf >/dev/null
    log "  ✓ Kernel parameters hardened"
    
    # Set secure file permissions
    log "Setting secure file permissions..."
    chmod 700 "$EVILGINX_DIR"
    chmod 600 "$EVILGINX_DIR/config.json" 2>/dev/null || true
    chmod 700 "$EVILGINX_DIR/phishlets" 2>/dev/null || true
    
    # Secure SSH configuration
    if [[ -f /etc/ssh/sshd_config ]]; then
        log "Hardening SSH configuration..."
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
        
        # Apply SSH hardening
        sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
        sed -i 's/#Protocol 2/Protocol 2/' /etc/ssh/sshd_config
        
        # Add additional security settings
        cat >> /etc/ssh/sshd_config <<EOF

# Evilginx3 Security Hardening
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers $(whoami)
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no
EOF
        
        systemctl restart sshd
        log "  ✓ SSH hardened"
    fi
    
    log "✅ System hardening completed"
}

### === FIREWALL CONFIGURATION ===
configure_firewall() {
    log "Configuring firewall..."
    
    # Install UFW if not present
    if ! command -v ufw >/dev/null; then
        apt-get update -qq
        apt-get install -y ufw
    fi
    
    # Reset UFW to defaults
    ufw --force reset >/dev/null
    
    # Set default policies
    ufw default deny incoming >/dev/null
    ufw default allow outgoing >/dev/null
    
    # Allow SSH (current session)
    local ssh_port
    ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | cut -d':' -f2 | head -n1)
    if [[ -n "$ssh_port" ]]; then
        ufw allow "$ssh_port"/tcp comment "SSH" >/dev/null
        log "  ✓ SSH allowed on port $ssh_port"
    fi
    
    # Allow HTTP/HTTPS
    ufw allow 80/tcp comment "HTTP" >/dev/null
    ufw allow 443/tcp comment "HTTPS" >/dev/null
    log "  ✓ HTTP/HTTPS allowed"
    
    # Allow DNS (if Evilginx3 handles DNS)
    ufw allow 53/tcp comment "DNS TCP" >/dev/null
    ufw allow 53/udp comment "DNS UDP" >/dev/null
    log "  ✓ DNS allowed"
    
    # Rate limiting for HTTP/HTTPS
    ufw limit 80/tcp >/dev/null
    ufw limit 443/tcp >/dev/null
    log "  ✓ Rate limiting enabled"
    
    # Enable UFW
    ufw --force enable >/dev/null
    
    # Create application profile
    cat > "$UFW_RULES_FILE" <<EOF
[Evilginx3]
title=Evilginx3 Phishing Framework
description=Evilginx3 phishing framework ports
ports=80,443,53/tcp|53/udp
EOF
    
    log "✅ Firewall configured"
}

### === INTRUSION DETECTION ===
setup_fail2ban() {
    log "Setting up Fail2Ban..."
    
    # Install Fail2Ban if not present
    if ! command -v fail2ban-server >/dev/null; then
        apt-get update -qq
        apt-get install -y fail2ban
    fi
    
    # Create Evilginx3 jail configuration
    cat > "$FAIL2BAN_JAIL" <<EOF
[evilginx3-auth]
enabled = true
port = http,https
filter = evilginx3-auth
logpath = /var/log/nginx/access.log
          $EVILGINX_DIR/logs/*.log
maxretry = 5
bantime = 3600
findtime = 600

[evilginx3-dos]
enabled = true
port = http,https
filter = evilginx3-dos
logpath = /var/log/nginx/access.log
maxretry = 50
bantime = 600
findtime = 60

[ssh-aggressive]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400
findtime = 600
EOF
    
    # Create custom filters
    mkdir -p /etc/fail2ban/filter.d
    
    # Auth failure filter
    cat > /etc/fail2ban/filter.d/evilginx3-auth.conf <<EOF
[Definition]
failregex = ^<HOST> .* "(GET|POST) .*/login.*" (401|403|404) .*$
            ^<HOST> .* ".*" (401|403) .*$
            Authentication failed for <HOST>
ignoreregex =
EOF
    
    # DOS filter
    cat > /etc/fail2ban/filter.d/evilginx3-dos.conf <<EOF
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*" (200|404|301|302) .*$
ignoreregex = ^<HOST> -.*"(GET|POST) .*/favicon.ico.*" .*$
              ^<HOST> -.*"(GET|POST) .*/robots.txt.*" .*$
EOF
    
    # Restart Fail2Ban
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    log "✅ Fail2Ban configured"
}

### === LOG MONITORING ===
setup_log_monitoring() {
    log "Setting up log monitoring..."
    
    # Create log rotation for Evilginx3
    cat > /etc/logrotate.d/evilginx3 <<EOF
$EVILGINX_DIR/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 root root
    postrotate
        systemctl reload evilginx3 2>/dev/null || true
    endscript
}

$SECURITY_LOG {
    daily
    missingok
    rotate 90
    compress
    delaycompress
    notifempty
    create 640 root root
}
EOF
    
    # Create security monitoring script
    cat > /usr/local/bin/evilginx3-security-monitor <<'EOF'
#!/bin/bash
SECURITY_LOG="/var/log/evilginx3-security.log"
ALERT_EMAIL="${ALERT_EMAIL:-}"

# Check for suspicious activity
check_failed_logins() {
    local failed_count
    failed_count=$(grep "Authentication failed" /var/log/auth.log | grep "$(date '+%b %d')" | wc -l)
    if [[ $failed_count -gt 10 ]]; then
        echo "[ALERT] High number of failed login attempts: $failed_count" >> "$SECURITY_LOG"
        [[ -n "$ALERT_EMAIL" ]] && echo "High failed login attempts detected" | mail -s "Security Alert" "$ALERT_EMAIL"
    fi
}

# Check for port scans
check_port_scans() {
    local scan_count
    scan_count=$(grep "UFW BLOCK" /var/log/ufw.log | grep "$(date '+%b %d')" | wc -l)
    if [[ $scan_count -gt 50 ]]; then
        echo "[ALERT] Possible port scan detected: $scan_count blocked connections" >> "$SECURITY_LOG"
        [[ -n "$ALERT_EMAIL" ]] && echo "Port scan detected" | mail -s "Security Alert" "$ALERT_EMAIL"
    fi
}

# Check Evilginx3 service status
check_service_status() {
    if ! systemctl is-active --quiet evilginx3; then
        echo "[ALERT] Evilginx3 service is not running" >> "$SECURITY_LOG"
        [[ -n "$ALERT_EMAIL" ]] && echo "Evilginx3 service down" | mail -s "Service Alert" "$ALERT_EMAIL"
    fi
}

# Run checks
check_failed_logins
check_port_scans
check_service_status
EOF
    
    chmod +x /usr/local/bin/evilginx3-security-monitor
    
    # Add to cron
    (crontab -l 2>/dev/null || true; echo "*/15 * * * * /usr/local/bin/evilginx3-security-monitor") | crontab -
    
    log "✅ Log monitoring configured"
}

### === NETWORK SECURITY ===
configure_network_security() {
    log "Configuring network security..."
    
    # Install and configure iptables-persistent
    if ! dpkg -l | grep -q iptables-persistent; then
        echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
        echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
        apt-get install -y iptables-persistent
    fi
    
    # Configure additional iptables rules
    cat > /etc/iptables/rules.v4 <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Allow loopback
-A INPUT -i lo -j ACCEPT

# Allow established connections
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow SSH (adjust port as needed)
-A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set
-A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
-A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS with rate limiting
-A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
-A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -m limit --limit 25/minute --limit-burst 100 -j ACCEPT

# Allow DNS
-A INPUT -p tcp --dport 53 -j ACCEPT
-A INPUT -p udp --dport 53 -j ACCEPT

# Drop invalid packets
-A INPUT -m conntrack --ctstate INVALID -j DROP

# Log dropped packets
-A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7

COMMIT
EOF
    
    # Apply rules
    iptables-restore < /etc/iptables/rules.v4
    
    log "✅ Network security configured"
}

### === SSL/TLS HARDENING ===
harden_ssl() {
    log "Hardening SSL/TLS configuration..."
    
    # Create strong DH parameters
    if [[ ! -f /etc/ssl/certs/dhparam.pem ]]; then
        log "Generating strong DH parameters (this may take a while)..."
        openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
    fi
    
    # Create secure Nginx SSL configuration
    cat > /etc/nginx/snippets/ssl-params.conf <<EOF
# SSL Configuration for Evilginx3
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/ssl/certs/dhparam.pem;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
ssl_ecdh_curve secp384r1;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# Security headers
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
add_header Referrer-Policy "strict-origin-when-cross-origin";
EOF
    
    log "✅ SSL/TLS hardened"
}

### === SECURITY AUDIT ===
run_security_audit() {
    log "Running security audit..."
    
    local audit_report="/tmp/evilginx3_security_audit_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== EVILGINX3 SECURITY AUDIT REPORT ==="
        echo "Generated: $(date)"
        echo "Hostname: $(hostname)"
        echo ""
        
        echo "=== SYSTEM INFORMATION ==="
        echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
        echo "Kernel: $(uname -r)"
        echo "Uptime: $(uptime -p)"
        echo ""
        
        echo "=== NETWORK SERVICES ==="
        echo "Listening ports:"
        ss -tlnp | grep -E ':(22|53|80|443|8443)\s'
        echo ""
        
        echo "=== FIREWALL STATUS ==="
        ufw status verbose 2>/dev/null || echo "UFW not configured"
        echo ""
        
        echo "=== FAIL2BAN STATUS ==="
        fail2ban-client status 2>/dev/null || echo "Fail2Ban not running"
        echo ""
        
        echo "=== SSL CERTIFICATE STATUS ==="
        if [[ -f /etc/letsencrypt/live/*/fullchain.pem ]]; then
            for cert in /etc/letsencrypt/live/*/fullchain.pem; do
                domain=$(basename "$(dirname "$cert")")
                expiry=$(openssl x509 -enddate -noout -in "$cert" | cut -d= -f2)
                echo "$domain: expires $expiry"
            done
        else
            echo "No SSL certificates found"
        fi
        echo ""
        
        echo "=== RECENT SECURITY EVENTS ==="
        tail -n 20 "$SECURITY_LOG" 2>/dev/null || echo "No security log found"
        echo ""
        
        echo "=== SYSTEM UPDATES ==="
        apt list --upgradable 2>/dev/null | head -n 10 || echo "Cannot check updates"
        
    } > "$audit_report"
    
    log "Security audit completed: $audit_report"
    cat "$audit_report"
}

### === HELP FUNCTION ===
show_help() {
    cat <<EOF
Evilginx3 Security Hardening Suite

Usage: $0 [COMMAND]

Commands:
  all                   Run all security hardening steps
  system               Harden system configuration
  firewall             Configure firewall (UFW)
  fail2ban             Setup intrusion detection
  monitoring           Setup log monitoring
  network              Configure network security
  ssl                  Harden SSL/TLS configuration
  audit                Run security audit
  status               Show security status

Examples:
  $0 all                # Complete security hardening
  $0 system             # System hardening only
  $0 audit              # Security audit only

Environment Variables:
  ALERT_EMAIL          Email for security alerts

Files:
  Security Log: $SECURITY_LOG
  Fail2Ban Jail: $FAIL2BAN_JAIL
  UFW Rules: $UFW_RULES_FILE

EOF
}

### === STATUS CHECK ===
show_status() {
    log "Security Status Check"
    echo ""
    
    # Check services
    echo "=== SERVICE STATUS ==="
    services=("ufw" "fail2ban" "nginx" "evilginx3")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "✓ $service: ACTIVE"
        else
            echo "✗ $service: INACTIVE"
        fi
    done
    echo ""
    
    # Check firewall
    echo "=== FIREWALL STATUS ==="
    if ufw status | grep -q "Status: active"; then
        echo "✓ UFW: ACTIVE"
        ufw status numbered | head -n 10
    else
        echo "✗ UFW: INACTIVE"
    fi
    echo ""
    
    # Check fail2ban
    echo "=== INTRUSION DETECTION ==="
    if systemctl is-active --quiet fail2ban; then
        echo "✓ Fail2Ban: ACTIVE"
        fail2ban-client status | head -n 5
    else
        echo "✗ Fail2Ban: INACTIVE"
    fi
    echo ""
    
    # Check SSL certificates
    echo "=== SSL CERTIFICATES ==="
    if [[ -d /etc/letsencrypt/live ]]; then
        for cert_dir in /etc/letsencrypt/live/*/; do
            if [[ -f "$cert_dir/fullchain.pem" ]]; then
                domain=$(basename "$cert_dir")
                expiry=$(openssl x509 -enddate -noout -in "$cert_dir/fullchain.pem" | cut -d= -f2)
                echo "✓ $domain: expires $expiry"
            fi
        done
    else
        echo "✗ No SSL certificates found"
    fi
}

### === MAIN EXECUTION ===
main() {
    # Ensure running as root
    [[ $EUID -eq 0 ]] || fatal "This script must be run as root"
    
    # Create security log
    mkdir -p "$(dirname "$SECURITY_LOG")"
    touch "$SECURITY_LOG"
    
    case "${1:-help}" in
        "all")
            harden_system
            configure_firewall
            setup_fail2ban
            setup_log_monitoring
            configure_network_security
            harden_ssl
            log "✅ Complete security hardening finished"
            ;;
        "system")
            harden_system
            ;;
        "firewall")
            configure_firewall
            ;;
        "fail2ban")
            setup_fail2ban
            ;;
        "monitoring")
            setup_log_monitoring
            ;;
        "network")
            configure_network_security
            ;;
        "ssl")
            harden_ssl
            ;;
        "audit")
            run_security_audit
            ;;
        "status")
            show_status
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
