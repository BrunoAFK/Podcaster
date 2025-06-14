#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Source environment if available (for cron)
if [[ -f /etc/environment ]]; then
    set -a  # automatically export all variables
    source /etc/environment
    set +a
fi

# Get podcast name from environment
PODCAST_NAME="${PODCAST_NAME:-unknown}"
PODCAST_DISPLAY="${PODCAST_NAME^^}"  # Uppercase for display

# Universal paths that work for any podcast
LOG_FILE="/app/logs/run_${PODCAST_NAME}.log"
PYTHON_SCRIPT="/app/scripts/feed.py"
LOCK_FILE="/tmp/run_${PODCAST_NAME}.lock"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Function to cleanup lock file on exit
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# Check for existing lock to prevent duplicate runs
if [[ -f "$LOCK_FILE" ]]; then
    echo "⚠️ Another instance is already running (lock file exists: $LOCK_FILE)"
    exit 1
fi

# Create lock file
echo $$ > "$LOCK_FILE"

# Function to log with timestamp and colors
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    case "$level" in
        "ERROR")
            echo -e "🔴 [$timestamp] \033[31m$message\033[0m"
            ;;
        "SUCCESS") 
            echo -e "✅ [$timestamp] \033[32m$message\033[0m"
            ;;
        "WARNING")
            echo -e "⚠️  [$timestamp] \033[33m$message\033[0m"
            ;;
        "INFO")
            echo -e "ℹ️  [$timestamp] \033[36m$message\033[0m"
            ;;
        "CONFIG")
            echo -e "⚙️  [$timestamp] \033[35m$message\033[0m"
            ;;
        *)
            echo -e "📝 [$timestamp] $message"
            ;;
    esac
}

# Function to log to file (without colors)
log_to_file() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    case "$level" in
        "ERROR")
            echo "🔴 [$timestamp] $message" >> "$LOG_FILE"
            ;;
        "SUCCESS") 
            echo "✅ [$timestamp] $message" >> "$LOG_FILE"
            ;;
        "WARNING")
            echo "⚠️  [$timestamp] $message" >> "$LOG_FILE"
            ;;
        "INFO")
            echo "ℹ️  [$timestamp] $message" >> "$LOG_FILE"
            ;;
        "CONFIG")
            echo "⚙️  [$timestamp] $message" >> "$LOG_FILE"
            ;;
        *)
            echo "📝 [$timestamp] $message" >> "$LOG_FILE"
            ;;
    esac
}

# Combined logging function
log_both() {
    log_message "$1" "$2"
    log_to_file "$1" "$2"
}

# Function to check Python environment
check_python_environment() {
    log_both "🐍 Checking Python environment..." "CONFIG"
    
    # Check if Python is available
    if ! command -v python3 &> /dev/null; then
        log_both "❌ Python3 not found in PATH" "ERROR"
        return 1
    fi
    
    # Check Python modules
    if ! python3 -c "import requests, feedparser, feedgen" 2>/dev/null; then
        log_both "❌ Required Python modules not available" "ERROR"
        log_both "Python path: $(which python3)" "ERROR"
        log_both "Python version: $(python3 --version 2>&1)" "ERROR"
        python3 -c "import sys; print('Python sys.path:', sys.path)" 2>&1 | head -1 | xargs -I {} log_both "{}" "ERROR"
        return 1
    fi
    
    log_both "✅ Python environment OK" "CONFIG"
    return 0
}

# Function to check and display notification configuration
check_notification_config() {
    local enabled="${TELEGRAM_NOTIFICATIONS_ENABLED:-true}"
    local types="${TELEGRAM_NOTIFICATION_TYPES:-all}"
    local has_token="${TELEGRAM_BOT_TOKEN:+yes}"
    local has_chat_id="${TELEGRAM_CHAT_ID:+yes}"
    
    log_both "📱 Telegram notification configuration:" "CONFIG"
    
    if [[ "$enabled" == "true" ]]; then
        if [[ -n "${has_token:-}" && -n "${has_chat_id:-}" ]]; then
            log_both "   Status: ✅ ENABLED (types: $types)" "CONFIG"
        else
            log_both "   Status: ❌ DISABLED (missing credentials)" "CONFIG"
        fi
    else
        log_both "   Status: 🔇 DISABLED (via TELEGRAM_NOTIFICATIONS_ENABLED=false)" "CONFIG"
    fi
}

# Function to send Telegram notification from bash
send_telegram_alert() {
    local message="$1"
    local msg_type="${2:-error}"  # default to error
    
    # Check if notifications are enabled
    if [[ "${TELEGRAM_NOTIFICATIONS_ENABLED:-true}" != "true" ]]; then
        return
    fi
    
    # Check if we have required credentials
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        return
    fi
    
    # Get allowed notification types
    local allowed_types="${TELEGRAM_NOTIFICATION_TYPES:-all}"
    
    # Check if this notification type is allowed
    if [[ "$allowed_types" != *"all"* ]] && [[ "$allowed_types" != *"$msg_type"* ]]; then
        return
    fi
    
    # Choose emoji based on message type
    local emoji="🚨"
    case "$msg_type" in
        "error") emoji="🚨" ;;
        "success") emoji="✅" ;;
        "info") emoji="ℹ️" ;;
        *) emoji="📝" ;;
    esac
    
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=$emoji ${PODCAST_NAME}_feed runner ($msg_type): $message" \
        -d "parse_mode=HTML" \
        --max-time 10 || true  # Don't fail if notification fails
}

test_notifications() {
    log_both "🧪 Testing Telegram notifications for ${PODCAST_NAME}..." "INFO"
    
    if [[ "${TELEGRAM_NOTIFICATIONS_ENABLED:-true}" != "true" ]]; then
        log_both "❌ Cannot test - notifications are disabled" "WARNING"
        return 1
    fi
    
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        log_both "❌ Cannot test - missing credentials" "ERROR"
        return 1
    fi
    
    # Test different notification types
    local types="${TELEGRAM_NOTIFICATION_TYPES:-all}"
    
    log_both "Testing notification types: $types" "INFO"
    
    if [[ "$types" == *"all"* ]] || [[ "$types" == *"info"* ]]; then
        send_telegram_alert "Test info notification 📝" "info"
        sleep 1
    fi
    
    if [[ "$types" == *"all"* ]] || [[ "$types" == *"success"* ]]; then
        send_telegram_alert "Test success notification ✅" "success"
        sleep 1
    fi
    
    if [[ "$types" == *"all"* ]] || [[ "$types" == *"error"* ]]; then
        send_telegram_alert "Test error notification (not a real error!) ⚠️" "error"
    fi
    
    log_both "✅ Test notifications sent!" "SUCCESS"
}

# Show usage
show_usage() {
    echo -e "\n🚀 \033[1;34m${PODCAST_DISPLAY} Feed Runner\033[0m"
    echo -e "📺 Universal Podcast Feed Generator\n"
    echo -e "\033[1mUsage:\033[0m $0 [OPTIONS]"
    echo -e "\n\033[1mOptions:\033[0m"
    echo -e "  🔄 --fetch-all    Fetch all available episodes instead of just new ones"
    echo -e "  🔇 --quiet        Suppress Telegram notifications (useful for manual runs)"
    echo -e "  🧪 --test         Test Telegram notification configuration"
    echo -e "  🐛 --debug        Run environment diagnostics"
    echo -e "  ❓ --help         Show this help message"
    echo -e "\n\033[1mExamples:\033[0m"
    echo -e "  📡 $0                    # Normal operation (check for new episodes)"
    echo -e "  📚 $0 --fetch-all        # Download all available episodes"
    echo -e "  🤫 $0 --fetch-all --quiet # Download all episodes without notifications"
    echo -e "  🧪 $0 --test             # Test notification configuration"
    echo -e "  🐛 $0 --debug            # Debug environment issues"
    echo -e "\n\033[1mCurrent Podcast:\033[0m $PODCAST_NAME"
    echo ""
}

# Parse command line arguments
PYTHON_ARGS=()
FETCH_ALL=false
QUIET_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --fetch-all)
            PYTHON_ARGS+=("--fetch-all")
            FETCH_ALL=true
            shift
            ;;
        --quiet)
            PYTHON_ARGS+=("--quiet")
            QUIET_MODE=true
            shift
            ;;
        --test)
            check_notification_config
            test_notifications
            exit 0
            ;;
        --debug)
            # Run debug script if it exists
            if [[ -f "/app/shared/debug-cron.sh" ]]; then
                bash /app/shared/debug-cron.sh
            else
                log_both "🐛 Debug script not found, running basic diagnostics..." "INFO"
                check_python_environment
                check_notification_config
                log_both "Environment check complete" "INFO"
            fi
            exit 0
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo -e "\n🎙️  \033[1;35m${PODCAST_DISPLAY} Feed Runner Starting...\033[0m\n"
    
    # Log startup to file
    log_to_file "${PODCAST_DISPLAY} Feed Runner Starting..." "INFO"
    
    # Validate environment
    if [[ "$PODCAST_NAME" == "unknown" ]]; then
        log_both "⚠️ PODCAST_NAME not set - using 'unknown'" "WARNING"
    fi
    
    # Check Python environment first
    if ! check_python_environment; then
        local error_msg="Python environment check failed"
        log_both "$error_msg" "ERROR"
        send_telegram_alert "$error_msg" "error"
        exit 1
    fi
    
    # Display configuration
    check_notification_config
    
    if [[ "$QUIET_MODE" == true ]]; then
        log_both "🤫 Quiet mode enabled - notifications suppressed for this run" "CONFIG"
    fi
    
    if [[ "$FETCH_ALL" == true ]]; then
        log_both "Pokrećem full episode fetch..." "INFO"
    else
        log_both "Pokrećem ${PODCAST_NAME}_feed script..." "INFO"
    fi
    
    # Check if Python script exists
    if [[ ! -f "$PYTHON_SCRIPT" ]]; then
        local error_msg="Python script not found: $PYTHON_SCRIPT"
        log_both "$error_msg" "ERROR"
        send_telegram_alert "$error_msg" "error"
        exit 1
    fi
    
    # Check if required environment variables are set
    if [[ -z "${DOMAIN:-}" ]]; then
        local error_msg="DOMAIN environment variable not set"
        log_both "$error_msg" "ERROR"
        send_telegram_alert "$error_msg" "error"
        exit 1
    fi
    
    log_both "Svi preduvjeti ispunjeni ✨ (${PODCAST_NAME})" "INFO"
    
    # Run the Python script with timeout and arguments
    local timeout_duration=300
    if [[ "$FETCH_ALL" == true ]]; then
        timeout_duration=600  # Longer timeout for fetching all episodes
        log_both "Koristim produženi timeout (${timeout_duration}s) za fetch-all..." "INFO"
    fi
    
    # Capture both stdout and stderr, and send to both console and log file
    if timeout $timeout_duration python3 "$PYTHON_SCRIPT" "${PYTHON_ARGS[@]}" 2>&1 | while IFS= read -r line; do
        echo "$line"  # Display on console
        echo "$(date '+%Y-%m-%d %H:%M:%S') $line" >> "$LOG_FILE"  # Log to file
    done; then
        local exit_code=${PIPESTATUS[0]}
        if [[ $exit_code -eq 0 ]]; then
            if [[ "$FETCH_ALL" == true ]]; then
                log_both "Full episode fetch završen uspješno! 🎉" "SUCCESS"
                # Send success notification if enabled
                if [[ "$QUIET_MODE" != true ]]; then
                    send_telegram_alert "Full episode fetch completed successfully" "success"
                fi
            else
                log_both "Script završen uspješno! 🎉" "SUCCESS"
            fi
        else
            local error_msg="Python script failed with exit code $exit_code"
            log_both "$error_msg" "ERROR"
            if [[ "$QUIET_MODE" != true ]]; then
                send_telegram_alert "$error_msg" "error"
            fi
            exit $exit_code
        fi
    else
        local exit_code=$?
        local error_msg="Script failed with exit code $exit_code"
        log_both "$error_msg" "ERROR"
        # Only send alert if not in quiet mode AND notifications enabled
        if [[ "$QUIET_MODE" != true ]]; then
            send_telegram_alert "$error_msg" "error"
        fi
        exit $exit_code
    fi
    
    echo -e "\n✨ \033[1;32mSve gotovo!\033[0m\n"
    log_to_file "Sve gotovo!" "SUCCESS"
}

# Error handling
handle_error() {
    local exit_code=$?
    local error_msg="Script interrupted unexpectedly with exit code $exit_code"
    log_both "$error_msg" "ERROR"
    send_telegram_alert "$error_msg" "error"
    cleanup
    exit $exit_code
}

# Trap to handle unexpected exits
trap 'handle_error' ERR

# Run main function
main "$@"