#!/bin/bash
# === DNS AUTO-CONFIGURATION TOOL ===
# Purpose: Automatically configure DNS records for Evilginx3 phishing domains
# Supports: Cloudflare, DigitalOcean, AWS Route53, and manual configuration

set -euo pipefail

### === CONFIGURATION ===
DOMAIN="${DOMAIN:-hrahra.org}"
EXTERNAL_IP="${EXTERNAL_IP:-$(curl -s https://api.ipify.org)}"
DNS_PROVIDER="${DNS_PROVIDER:-manual}"
CONFIG_FILE="/opt/posh-ai/evilginx3/config/dns_config.json"

# DNS Provider API Keys (set as environment variables)
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
DIGITALOCEAN_TOKEN="${DIGITALOCEAN_TOKEN:-}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"

### === UTILITIES ===
log() { echo -e "\033[1;34m[DNS-CONFIG]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARNING]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
fatal() { error "$*"; exit 1; }

### === DNS RECORD TEMPLATES ===
declare -A DNS_RECORDS=(
    ["@"]="A"
    ["www"]="A"
    ["login"]="A"
    ["securelogin"]="A"
    ["webmail"]="A"
    ["portal"]="A"
    ["mail"]="A"
    ["autodiscover"]="A"
    ["*"]="A"
)

### === CLOUDFLARE DNS MANAGEMENT ===
cloudflare_get_zone_id() {
    local domain="$1"
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${domain}" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json" | \
        jq -r '.result[0].id // empty'
}

cloudflare_create_record() {
    local zone_id="$1"
    local name="$2"
    local type="$3"
    local content="$4"
    
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"${type}\",\"name\":\"${name}\",\"content\":\"${content}\",\"ttl\":300}" | \
        jq -r '.success'
}

cloudflare_setup() {
    [[ -z "$CLOUDFLARE_API_TOKEN" ]] && fatal "CLOUDFLARE_API_TOKEN not set"
    
    log "Setting up Cloudflare DNS for $DOMAIN"
    local zone_id
    zone_id=$(cloudflare_get_zone_id "$DOMAIN")
    [[ -z "$zone_id" ]] && fatal "Could not find Cloudflare zone for $DOMAIN"
    
    for record in "${!DNS_RECORDS[@]}"; do
        local record_name="$record"
        [[ "$record" == "@" ]] && record_name="$DOMAIN" || record_name="${record}.${DOMAIN}"
        
        log "Creating DNS record: $record_name -> $EXTERNAL_IP"
        if cloudflare_create_record "$zone_id" "$record_name" "${DNS_RECORDS[$record]}" "$EXTERNAL_IP" | grep -q "true"; then
            log "  ✓ $record_name created successfully"
        else
            warn "  ✗ Failed to create $record_name (may already exist)"
        fi
    done
}

### === DIGITALOCEAN DNS MANAGEMENT ===
digitalocean_setup() {
    [[ -z "$DIGITALOCEAN_TOKEN" ]] && fatal "DIGITALOCEAN_TOKEN not set"
    
    log "Setting up DigitalOcean DNS for $DOMAIN"
    
    # Create domain if it doesn't exist
    curl -s -X POST "https://api.digitalocean.com/v2/domains" \
        -H "Authorization: Bearer ${DIGITALOCEAN_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"name\":\"${DOMAIN}\",\"ip_address\":\"${EXTERNAL_IP}\"}" >/dev/null
    
    for record in "${!DNS_RECORDS[@]}"; do
        local record_name="$record"
        [[ "$record" == "@" ]] && record_name="@"
        
        log "Creating DNS record: $record_name -> $EXTERNAL_IP"
        curl -s -X POST "https://api.digitalocean.com/v2/domains/${DOMAIN}/records" \
            -H "Authorization: Bearer ${DIGITALOCEAN_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"${DNS_RECORDS[$record]}\",\"name\":\"${record_name}\",\"data\":\"${EXTERNAL_IP}\",\"ttl\":300}" >/dev/null
        log "  ✓ $record_name created"
    done
}

### === AWS ROUTE53 MANAGEMENT ===
aws_setup() {
    [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]] && fatal "AWS credentials not set"
    
    command -v aws >/dev/null || fatal "AWS CLI not installed"
    
    log "Setting up AWS Route53 DNS for $DOMAIN"
    
    # Get hosted zone ID
    local zone_id
    zone_id=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query "HostedZones[0].Id" --output text | cut -d'/' -f3)
    [[ "$zone_id" == "None" ]] && fatal "Could not find Route53 hosted zone for $DOMAIN"
    
    for record in "${!DNS_RECORDS[@]}"; do
        local record_name="$record"
        [[ "$record" == "@" ]] && record_name="$DOMAIN" || record_name="${record}.${DOMAIN}"
        
        log "Creating DNS record: $record_name -> $EXTERNAL_IP"
        
        cat > /tmp/route53-record.json <<EOF
{
    "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "${record_name}",
            "Type": "${DNS_RECORDS[$record]}",
            "TTL": 300,
            "ResourceRecords": [{"Value": "${EXTERNAL_IP}"}]
        }
    }]
}
EOF
        
        aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" --change-batch file:///tmp/route53-record.json >/dev/null
        log "  ✓ $record_name created"
    done
    
    rm -f /tmp/route53-record.json
}

### === MANUAL DNS CONFIGURATION ===
manual_setup() {
    log "Manual DNS Configuration Required"
    echo ""
    echo "Please create the following DNS records in your DNS provider:"
    echo "=================================================="
    
    for record in "${!DNS_RECORDS[@]}"; do
        local record_name="$record"
        [[ "$record" == "@" ]] && record_name="$DOMAIN" || record_name="${record}.${DOMAIN}"
        printf "%-25s %-5s %s\n" "$record_name" "${DNS_RECORDS[$record]}" "$EXTERNAL_IP"
    done
    
    echo ""
    echo "Additional recommended records:"
    echo "=================================================="
    echo "TXT records for domain verification:"
    echo "${DOMAIN}                 TXT   \"v=spf1 ip4:${EXTERNAL_IP} ~all\""
    echo "_dmarc.${DOMAIN}          TXT   \"v=DMARC1; p=none; rua=mailto:admin@${DOMAIN}\""
    
    # Save configuration for reference
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
{
    "domain": "$DOMAIN",
    "external_ip": "$EXTERNAL_IP",
    "dns_provider": "$DNS_PROVIDER",
    "records_created": $(date -Iseconds),
    "dns_records": {
$(for record in "${!DNS_RECORDS[@]}"; do
    local record_name="$record"
    [[ "$record" == "@" ]] && record_name="$DOMAIN" || record_name="${record}.${DOMAIN}"
    echo "        \"$record_name\": \"$EXTERNAL_IP\","
done | sed '$ s/,$//')
    }
}
EOF
    
    log "DNS configuration saved to: $CONFIG_FILE"
}

### === DNS VERIFICATION ===
verify_dns() {
    log "Verifying DNS propagation..."
    local failed=0
    
    for record in "${!DNS_RECORDS[@]}"; do
        local record_name="$record"
        [[ "$record" == "@" ]] && record_name="$DOMAIN" || record_name="${record}.${DOMAIN}"
        
        local resolved_ip
        resolved_ip=$(dig +short "$record_name" @8.8.8.8 | tail -n1)
        
        if [[ "$resolved_ip" == "$EXTERNAL_IP" ]]; then
            log "  ✓ $record_name resolves correctly"
        else
            warn "  ✗ $record_name resolves to '$resolved_ip' (expected: $EXTERNAL_IP)"
            ((failed++))
        fi
    done
    
    if ((failed > 0)); then
        warn "DNS propagation incomplete. Wait 5-10 minutes and try again."
        return 1
    else
        log "✅ All DNS records verified successfully"
        return 0
    fi
}

### === MAIN EXECUTION ===
main() {
    log "Starting DNS auto-configuration for $DOMAIN"
    log "External IP: $EXTERNAL_IP"
    log "DNS Provider: $DNS_PROVIDER"
    
    case "$DNS_PROVIDER" in
        "cloudflare")
            cloudflare_setup
            ;;
        "digitalocean")
            digitalocean_setup
            ;;
        "aws"|"route53")
            aws_setup
            ;;
        "manual")
            manual_setup
            return 0
            ;;
        *)
            fatal "Unsupported DNS provider: $DNS_PROVIDER. Use: cloudflare, digitalocean, aws, or manual"
            ;;
    esac
    
    log "DNS records created. Waiting 30 seconds for propagation..."
    sleep 30
    
    if verify_dns; then
        log "✅ DNS configuration completed successfully"
    else
        warn "DNS verification failed. Records may still be propagating."
    fi
}

### === HELP FUNCTION ===
show_help() {
    cat <<EOF
DNS Auto-Configuration Tool for Evilginx3

Usage: $0 [OPTIONS]

Environment Variables:
  DOMAIN                 Target domain (default: hrahra.org)
  EXTERNAL_IP           External IP address (auto-detected if not set)
  DNS_PROVIDER          DNS provider: cloudflare, digitalocean, aws, manual
  
Provider-specific variables:
  CLOUDFLARE_API_TOKEN  Cloudflare API token
  DIGITALOCEAN_TOKEN    DigitalOcean API token
  AWS_ACCESS_KEY_ID     AWS access key
  AWS_SECRET_ACCESS_KEY AWS secret key

Examples:
  # Manual configuration (shows required records)
  DNS_PROVIDER=manual $0
  
  # Cloudflare automatic setup
  CLOUDFLARE_API_TOKEN=your_token DNS_PROVIDER=cloudflare $0
  
  # DigitalOcean automatic setup
  DIGITALOCEAN_TOKEN=your_token DNS_PROVIDER=digitalocean $0
  
  # AWS Route53 automatic setup
  AWS_ACCESS_KEY_ID=key AWS_SECRET_ACCESS_KEY=secret DNS_PROVIDER=aws $0

Commands:
  verify    Verify existing DNS records
  help      Show this help message

EOF
}

### === COMMAND LINE HANDLING ===
case "${1:-}" in
    "verify")
        verify_dns
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    "")
        main
        ;;
    *)
        error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
