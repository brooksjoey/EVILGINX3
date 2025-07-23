#!/bin/bash
set -euo pipefail

DOMAIN="hrahra.org"
EMAIL="admin@$DOMAIN"

export DEBIAN_FRONTEND=noninteractive

apt update -qq
apt install -y certbot python3-certbot-nginx python3-certbot-dns-cloudflare

systemctl stop nginx 2>/dev/null || true

certbot certonly --standalone --non-interactive --agree-tos --email $EMAIL -d $DOMAIN -d "*.$DOMAIN" --preferred-challenges dns

cat > /etc/cron.d/certbot-renewal <<EOF
0 0,12 * * * root /usr/bin/certbot renew --quiet --deploy-hook "systemctl reload nginx"
EOF

systemctl enable cron
systemctl start cron

chmod 644 /etc/cron.d/certbot-renewal

cat > /usr/local/bin/ssl-check.sh <<'EOF'
#!/bin/bash
DOMAIN="hrahra.org"
CERT_FILE="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"

if [ -f "$CERT_FILE" ]; then
    EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_LEFT=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))
    
    if [ $DAYS_LEFT -lt 30 ]; then
        echo "SSL certificate expires in $DAYS_LEFT days. Attempting renewal..."
        /usr/bin/certbot renew --force-renewal --deploy-hook "systemctl reload nginx"
    else
        echo "SSL certificate valid for $DAYS_LEFT more days"
    fi
else
    echo "SSL certificate not found. Requesting new certificate..."
    certbot certonly --standalone --non-interactive --agree-tos --email admin@$DOMAIN -d $DOMAIN -d "*.$DOMAIN"
fi
EOF

chmod +x /usr/local/bin/ssl-check.sh

echo "0 6 * * * root /usr/local/bin/ssl-check.sh >> /var/log/ssl-check.log 2>&1" >> /etc/crontab

systemctl start nginx

echo "SSL automation configured for $DOMAIN"
echo "Certificate location: /etc/letsencrypt/live/$DOMAIN/"
echo "Auto-renewal: Every 12 hours via cron"
echo "Manual check: /usr/local/bin/ssl-check.sh"
