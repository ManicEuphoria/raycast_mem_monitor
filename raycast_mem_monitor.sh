#!/bin/bash
# =======================================================
# Raycast Memory Monitor v0.2
# Author: boozer.asia
# Mailme: cory@boozer.asia
# =======================================================

set -euo pipefail
IFS=$'\n\t'

# ===================== CONFIGURATION =====================
readonly APP_NAME="Raycast"
readonly MEM_THRESHOLD_MB=500 # Set default threshold max 500MB
readonly LOG_FILE="$HOME/raycast_mem_monitor.log"

# IBM Notifier configuration
readonly NA_PATH="/Applications/IBM Notifier.app/Contents/MacOS/IBM Notifier"
readonly WINDOW_TYPE="banner" # Due to macOS system limit, alert type is not support 
readonly BAR_TITLE="Raycast Monitor"
readonly TITLE="内存占用提醒"
readonly TIMEOUT="3"  # This is a must-set, or banner will not show due to IBM process was killed too early
readonly BUTTON_1="OK"

# Check if IBM Notifier is installed, if not, skip notification step
if [ -x "$NA_PATH" ]; then
    NOTIFIER_AVAILABLE=true
else
    NOTIFIER_AVAILABLE=false
fi

# ===================== FUNCTIONS =====================

# Log process
log_info() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
}

# Get raycast pid
get_app_pid() {
    pgrep -x "$APP_NAME" || true
}

# Get memeory usage
get_memory_mb() {
    local pid="$1"
    local mem_kb
    mem_kb=$(ps -o rss= -p "$pid")
    echo $((mem_kb / 1024))
}

# Send notification, then kill IBM Notifier process
send_notification() {
    local subtitle="$1"

    # Show notification banner
    "$NA_PATH" \
        -type "$WINDOW_TYPE" \
        -bar_title "$BAR_TITLE" \
        -title "$TITLE" \
        -subtitle "$subtitle" \
        -timeout "$TIMEOUT" \
        -main_button_label "$BUTTON_1" \
        -always_on_top &

    local notify_pid=$!
    sleep 0.5  # Make sure process starts

    # Capture helper process
    local helper_pids
    helper_pids=$(pgrep -P "$notify_pid" || true)

     # Wait until banner popup
    sleep "$TIMEOUT"

    # Kill helper process
    if [ -n "$helper_pids" ]; then
        kill $helper_pids 2>/dev/null || true
    fi

    # Kill main process
    kill "$notify_pid" 2>/dev/null || true
}

restart_app() {
    local pid="$1"
    kill "$pid" 2>/dev/null || true
    sleep 1
    open -a "$APP_NAME"
}


# ===================== MAIN PROCEDURE =====================

app_pid=$(get_app_pid)

if [ -z "$app_pid" ]; then
    log_info "$APP_NAME 未运行"
    exit 0
fi

mem_mb=$(get_memory_mb "$app_pid")
log_info "当前内存占用: ${mem_mb}MB"


if [ "$mem_mb" -gt "$MEM_THRESHOLD_MB" ]; then
    log_info "超过阈值 (${mem_mb}MB > ${MEM_THRESHOLD_MB}MB)，重启 $APP_NAME"
    restart_app "$app_pid"

    if [ "$NOTIFIER_AVAILABLE" = true ]; then
        subtitle="${APP_NAME} 占用内存 ${mem_mb}MB，超过阈值，已重启应用。"
        send_notification "$subtitle"
    fi
fi

exit 0
