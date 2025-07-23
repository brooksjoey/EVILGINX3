#!/bin/bash
# === EVILGINX3 BACKUP & RECOVERY MANAGER ===
# Purpose: Complete backup and recovery solution for Evilginx3 deployments
# Features: Automated backups, encryption, remote storage, disaster recovery

set -euo pipefail

### === CONFIGURATION ===
EVILGINX_DIR="/opt/posh-ai/evilginx3"
BACKUP_DIR="/opt/posh-ai/backups"
REMOTE_BACKUP_DIR="${REMOTE_BACKUP_DIR:-}"
ENCRYPTION_KEY_FILE="/etc/posh-ai/backup.key"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
COMPRESSION_LEVEL="${COMPRESSION_LEVEL:-6}"

### === UTILITIES ===
log() { echo -e "\033[1;32m[BACKUP-MGR]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARNING]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
fatal() { error "$*"; exit 1; }

### === INITIALIZATION ===
init_backup_system() {
    log "Initializing backup system..."
    
    # Create directories
    mkdir -p "$BACKUP_DIR"/{full,incremental,logs,temp}
    chmod 700 "$BACKUP_DIR"
    
    # Generate encryption key if it doesn't exist
    if [[ ! -f "$ENCRYPTION_KEY_FILE" ]]; then
        log "Generating encryption key..."
        mkdir -p "$(dirname "$ENCRYPTION_KEY_FILE")"
        openssl rand -base64 32 > "$ENCRYPTION_KEY_FILE"
        chmod 600 "$ENCRYPTION_KEY_FILE"
        log "Encryption key generated: $ENCRYPTION_KEY_FILE"
    fi
    
    log "Backup system initialized"
}

### === BACKUP FUNCTIONS ===
create_full_backup() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="evilginx3_full_${timestamp}"
    local backup_file="$BACKUP_DIR/full/${backup_name}.tar.gz.enc"
    local temp_dir="$BACKUP_DIR/temp/$backup_name"
    
    log "Creating full backup: $backup_name"
    
    # Create temporary directory
    mkdir -p "$temp_dir"
    
    # Copy all important files
    log "Copying Evilginx3 files..."
    cp -r "$EVILGINX_DIR" "$temp_dir/" 2>/dev/null || true
    
    # Copy system configurations
    log "Copying system configurations..."
    mkdir -p "$temp_dir/system"
    cp /etc/systemd/system/evilginx*.service "$temp_dir/system/" 2>/dev/null || true
    cp -r /etc/nginx/sites-available/evilginx* "$temp_dir/system/" 2>/dev/null || true
    cp -r /etc/letsencrypt/live/* "$temp_dir/system/" 2>/dev/null || true
    
    # Create backup metadata
    cat > "$temp_dir/backup_info.json" <<EOF
{
    "backup_type": "full",
    "timestamp": "$timestamp",
    "hostname": "$(hostname)",
    "evilginx_version": "$(cd "$EVILGINX_DIR" && ./evilginx -version 2>/dev/null || echo 'unknown')",
    "domain": "$(grep -o '"domain":"[^"]*"' "$EVILGINX_DIR/config.json" 2>/dev/null | cut -d'"' -f4 || echo 'unknown')",
    "external_ip": "$(grep -o '"external_ipv4":"[^"]*"' "$EVILGINX_DIR/config.json" 2>/dev/null | cut -d'"' -f4 || echo 'unknown')"
}
EOF
    
    # Create compressed archive
    log "Creating compressed archive..."
    tar -czf "$temp_dir.tar.gz" -C "$BACKUP_DIR/temp" "$backup_name"
    
    # Encrypt the backup
    log "Encrypting backup..."
    openssl enc -aes-256-cbc -salt -pbkdf2 \
        -in "$temp_dir.tar.gz" \
        -out "$backup_file" \
        -pass file:"$ENCRYPTION_KEY_FILE"
    
    # Cleanup
    rm -rf "$temp_dir" "$temp_dir.tar.gz"
    
    # Generate checksum
    sha256sum "$backup_file" > "${backup_file}.sha256"
    
    log "Full backup completed: $backup_file"
    log "Backup size: $(du -h "$backup_file" | cut -f1)"
    
    # Upload to remote if configured
    if [[ -n "$REMOTE_BACKUP_DIR" ]]; then
        upload_to_remote "$backup_file"
    fi
    
    echo "$backup_file"
}

create_incremental_backup() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="evilginx3_incremental_${timestamp}"
    local backup_file="$BACKUP_DIR/incremental/${backup_name}.tar.gz.enc"
    local temp_dir="$BACKUP_DIR/temp/$backup_name"
    
    log "Creating incremental backup: $backup_name"
    
    # Find files modified in last 24 hours
    mkdir -p "$temp_dir"
    
    # Copy modified Evilginx3 files
    find "$EVILGINX_DIR" -type f -mtime -1 -exec cp --parents {} "$temp_dir/" \; 2>/dev/null || true
    
    # Copy recent logs
    mkdir -p "$temp_dir/logs"
    journalctl -u evilginx* --since "24 hours ago" > "$temp_dir/logs/systemd.log" 2>/dev/null || true
    find /var/log -name "*evilginx*" -mtime -1 -exec cp {} "$temp_dir/logs/" \; 2>/dev/null || true
    
    # Create backup metadata
    cat > "$temp_dir/backup_info.json" <<EOF
{
    "backup_type": "incremental",
    "timestamp": "$timestamp",
    "hostname": "$(hostname)",
    "files_modified_since": "24 hours ago"
}
EOF
    
    # Only proceed if there are files to backup
    if [[ $(find "$temp_dir" -type f | wc -l) -gt 1 ]]; then
        # Create compressed archive
        tar -czf "$temp_dir.tar.gz" -C "$BACKUP_DIR/temp" "$backup_name"
        
        # Encrypt the backup
        openssl enc -aes-256-cbc -salt -pbkdf2 \
            -in "$temp_dir.tar.gz" \
            -out "$backup_file" \
            -pass file:"$ENCRYPTION_KEY_FILE"
        
        # Generate checksum
        sha256sum "$backup_file" > "${backup_file}.sha256"
        
        log "Incremental backup completed: $backup_file"
        echo "$backup_file"
    else
        log "No files modified in last 24 hours, skipping incremental backup"
        echo ""
    fi
    
    # Cleanup
    rm -rf "$temp_dir" "$temp_dir.tar.gz" 2>/dev/null || true
}

### === RECOVERY FUNCTIONS ===
list_backups() {
    log "Available backups:"
    echo ""
    echo "FULL BACKUPS:"
    echo "============="
    if ls "$BACKUP_DIR/full/"*.tar.gz.enc >/dev/null 2>&1; then
        for backup in "$BACKUP_DIR/full/"*.tar.gz.enc; do
            local size
            size=$(du -h "$backup" | cut -f1)
            local date
            date=$(stat -c %y "$backup" | cut -d' ' -f1,2 | cut -d'.' -f1)
            printf "%-50s %8s %s\n" "$(basename "$backup")" "$size" "$date"
        done
    else
        echo "No full backups found"
    fi
    
    echo ""
    echo "INCREMENTAL BACKUPS:"
    echo "===================="
    if ls "$BACKUP_DIR/incremental/"*.tar.gz.enc >/dev/null 2>&1; then
        for backup in "$BACKUP_DIR/incremental/"*.tar.gz.enc; do
            local size
            size=$(du -h "$backup" | cut -f1)
            local date
            date=$(stat -c %y "$backup" | cut -d'.' -f1)
            printf "%-50s %8s %s\n" "$(basename "$backup")" "$size" "$date"
        done
    else
        echo "No incremental backups found"
    fi
}

restore_backup() {
    local backup_file="$1"
    local restore_dir="${2:-/opt/posh-ai/evilginx3_restored}"
    
    [[ -f "$backup_file" ]] || fatal "Backup file not found: $backup_file"
    
    log "Restoring backup: $(basename "$backup_file")"
    log "Restore location: $restore_dir"
    
    # Verify checksum if available
    if [[ -f "${backup_file}.sha256" ]]; then
        log "Verifying backup integrity..."
        if sha256sum -c "${backup_file}.sha256" >/dev/null 2>&1; then
            log "✓ Backup integrity verified"
        else
            fatal "Backup integrity check failed!"
        fi
    fi
    
    # Create restore directory
    mkdir -p "$restore_dir"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Decrypt backup
    log "Decrypting backup..."
    openssl enc -d -aes-256-cbc -pbkdf2 \
        -in "$backup_file" \
        -out "$temp_dir/backup.tar.gz" \
        -pass file:"$ENCRYPTION_KEY_FILE"
    
    # Extract backup
    log "Extracting backup..."
    tar -xzf "$temp_dir/backup.tar.gz" -C "$temp_dir"
    
    # Find the extracted directory
    local extracted_dir
    extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "evilginx3_*" | head -n1)
    
    if [[ -n "$extracted_dir" ]]; then
        cp -r "$extracted_dir"/* "$restore_dir/"
        log "✓ Backup restored to: $restore_dir"
        
        # Show backup info if available
        if [[ -f "$restore_dir/backup_info.json" ]]; then
            log "Backup information:"
            cat "$restore_dir/backup_info.json"
        fi
    else
        fatal "Could not find extracted backup data"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

### === REMOTE BACKUP FUNCTIONS ===
upload_to_remote() {
    local backup_file="$1"
    
    if [[ -z "$REMOTE_BACKUP_DIR" ]]; then
        return 0
    fi
    
    log "Uploading to remote storage: $REMOTE_BACKUP_DIR"
    
    # Support different remote storage types
    case "$REMOTE_BACKUP_DIR" in
        s3://*)
            aws s3 cp "$backup_file" "$REMOTE_BACKUP_DIR/" 2>/dev/null || warn "Failed to upload to S3"
            aws s3 cp "${backup_file}.sha256" "$REMOTE_BACKUP_DIR/" 2>/dev/null || true
            ;;
        scp://*)
            local remote_path="${REMOTE_BACKUP_DIR#scp://}"
            scp "$backup_file" "$remote_path/" 2>/dev/null || warn "Failed to upload via SCP"
            scp "${backup_file}.sha256" "$remote_path/" 2>/dev/null || true
            ;;
        rsync://*)
            local remote_path="${REMOTE_BACKUP_DIR#rsync://}"
            rsync -av "$backup_file" "$remote_path/" 2>/dev/null || warn "Failed to upload via rsync"
            rsync -av "${backup_file}.sha256" "$remote_path/" 2>/dev/null || true
            ;;
        *)
            warn "Unsupported remote backup protocol: $REMOTE_BACKUP_DIR"
            ;;
    esac
}

### === MAINTENANCE FUNCTIONS ===
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    
    local deleted_count=0
    
    # Clean full backups
    while IFS= read -r -d '' backup; do
        rm -f "$backup" "${backup}.sha256"
        ((deleted_count++))
    done < <(find "$BACKUP_DIR/full" -name "*.tar.gz.enc" -mtime +$RETENTION_DAYS -print0 2>/dev/null)
    
    # Clean incremental backups
    while IFS= read -r -d '' backup; do
        rm -f "$backup" "${backup}.sha256"
        ((deleted_count++))
    done < <(find "$BACKUP_DIR/incremental" -name "*.tar.gz.enc" -mtime +$RETENTION_DAYS -print0 2>/dev/null)
    
    log "Deleted $deleted_count old backup files"
}

show_backup_stats() {
    log "Backup Statistics"
    echo ""
    
    local full_count
    full_count=$(find "$BACKUP_DIR/full" -name "*.tar.gz.enc" 2>/dev/null | wc -l)
    local incremental_count
    incremental_count=$(find "$BACKUP_DIR/incremental" -name "*.tar.gz.enc" 2>/dev/null | wc -l)
    
    local total_size
    total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    
    echo "Full Backups: $full_count"
    echo "Incremental Backups: $incremental_count"
    echo "Total Backup Size: $total_size"
    echo "Retention Period: $RETENTION_DAYS days"
    echo "Backup Directory: $BACKUP_DIR"
    echo "Remote Backup: ${REMOTE_BACKUP_DIR:-'Not configured'}"
    echo ""
    
    if [[ -f "$ENCRYPTION_KEY_FILE" ]]; then
        echo "✓ Encryption enabled"
    else
        echo "✗ Encryption not configured"
    fi
}

### === AUTOMATED BACKUP SCHEDULER ===
setup_cron() {
    log "Setting up automated backup schedule..."
    
    # Create backup script
    cat > /usr/local/bin/evilginx3-backup <<'EOF'
#!/bin/bash
/opt/posh-ai/evilginx3/tools/backup_manager.sh auto-backup
EOF
    chmod +x /usr/local/bin/evilginx3-backup
    
    # Add cron jobs
    (crontab -l 2>/dev/null || true; echo "0 2 * * 0 /usr/local/bin/evilginx3-backup full") | crontab -
    (crontab -l 2>/dev/null || true; echo "0 2 * * 1-6 /usr/local/bin/evilginx3-backup incremental") | crontab -
    (crontab -l 2>/dev/null || true; echo "0 3 * * 0 /usr/local/bin/evilginx3-backup cleanup") | crontab -
    
    log "✓ Automated backup schedule configured:"
    log "  - Full backup: Weekly (Sunday 2:00 AM)"
    log "  - Incremental backup: Daily (2:00 AM)"
    log "  - Cleanup: Weekly (Sunday 3:00 AM)"
}

### === HELP FUNCTION ===
show_help() {
    cat <<EOF
Evilginx3 Backup & Recovery Manager

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  init                  Initialize backup system
  full                  Create full backup
  incremental           Create incremental backup
  list                  List available backups
  restore <file> [dir]  Restore backup to directory
  cleanup               Remove old backups
  stats                 Show backup statistics
  setup-cron            Setup automated backup schedule
  auto-backup <type>    Automated backup (used by cron)

Environment Variables:
  RETENTION_DAYS        Days to keep backups (default: 30)
  REMOTE_BACKUP_DIR     Remote backup location (s3://, scp://, rsync://)
  COMPRESSION_LEVEL     Compression level 1-9 (default: 6)

Examples:
  $0 init                                    # Initialize backup system
  $0 full                                    # Create full backup
  $0 incremental                             # Create incremental backup
  $0 restore backup.tar.gz.enc /tmp/restore # Restore backup
  $0 setup-cron                             # Setup automated backups

Remote Backup Examples:
  REMOTE_BACKUP_DIR=s3://my-bucket/backups $0 full
  REMOTE_BACKUP_DIR=scp://user@server:/backups $0 full
  REMOTE_BACKUP_DIR=rsync://user@server:/backups $0 full

EOF
}

### === MAIN EXECUTION ===
main() {
    case "${1:-help}" in
        "init")
            init_backup_system
            ;;
        "full")
            init_backup_system
            create_full_backup
            ;;
        "incremental")
            init_backup_system
            create_incremental_backup
            ;;
        "list")
            list_backups
            ;;
        "restore")
            [[ -n "${2:-}" ]] || fatal "Please specify backup file to restore"
            restore_backup "$2" "${3:-}"
            ;;
        "cleanup")
            cleanup_old_backups
            ;;
        "stats")
            show_backup_stats
            ;;
        "setup-cron")
            setup_cron
            ;;
        "auto-backup")
            case "${2:-}" in
                "full")
                    create_full_backup >/dev/null
                    ;;
                "incremental")
                    create_incremental_backup >/dev/null
                    ;;
                "cleanup")
                    cleanup_old_backups >/dev/null
                    ;;
                *)
                    fatal "auto-backup requires: full, incremental, or cleanup"
                    ;;
            esac
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
