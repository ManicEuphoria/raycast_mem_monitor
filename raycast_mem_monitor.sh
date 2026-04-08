#!/bin/bash
# =======================================================
# Raycast Memory Monitor
# Author: boozer.asia
# Mailme: cory@boozer.asia
# =======================================================

set -euo pipefail
IFS=$'\n\t'

# ===================== CONFIGURATION =====================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly APP_NAME="Raycast"
readonly DEFAULT_MEM_THRESHOLD_MB=420
readonly DEFAULT_START_INTERVAL=300
readonly DEFAULT_LOG_MAX_BYTES=262144
readonly DEFAULT_LOG_KEEP_LINES=200
readonly CONFIG_FILE="${RMM_CONFIG_FILE:-$SCRIPT_DIR/raycast_mem_monitor.conf}"
readonly LOG_FILE="${RMM_LOG_FILE:-$HOME/raycast_mem_monitor.log}"
readonly LOG_MAX_BYTES="${RMM_LOG_MAX_BYTES:-$DEFAULT_LOG_MAX_BYTES}"
readonly LOG_KEEP_LINES="${RMM_LOG_KEEP_LINES:-$DEFAULT_LOG_KEEP_LINES}"

# IBM Notifier configuration
readonly NA_APP_NAME="IBM Notifier.app"
readonly NA_PRIMARY_APP_ROOT="${RMM_NOTIFIER_PRIMARY_APP_ROOT:-/Applications}"
readonly NA_FALLBACK_APP_ROOT="${RMM_NOTIFIER_FALLBACK_APP_ROOT:-$HOME/Applications}"
readonly WINDOW_TYPE="banner" # Due to macOS system limit, alert type is not support 
readonly BAR_TITLE="Raycast Monitor"
readonly TIMEOUT="3"  # This is a must-set, or banner will not show due to IBM process was killed too early

NA_PATH=""
NOTIFIER_AVAILABLE=false

MEM_THRESHOLD_MB="$DEFAULT_MEM_THRESHOLD_MB"
START_INTERVAL="$DEFAULT_START_INTERVAL"

# ===================== LANGUAGE DETECTION =====================
# Detect system language
SYSTEM_LANG=$(defaults read -g AppleLanguages | head -n 2 | tail -n 1 | tr -d ' "' || echo "en")

# Check if Chinese
if [[ "$SYSTEM_LANG" == zh* ]]; then
    IS_CHINESE=true
else
    IS_CHINESE=false
fi

# Set localized strings
if [ "$IS_CHINESE" = true ]; then
    readonly TITLE="内存占用提醒"
    readonly BUTTON_1="确定"
    readonly MSG_NOT_RUNNING="未运行"
    readonly MSG_CURRENT_MEMORY="当前内存占用"
    readonly MSG_EXCEEDED_THRESHOLD="超过阈值"
    readonly MSG_RESTARTING="重启"
    readonly MSG_NOTIFICATION_TEMPLATE="%s 占用内存 %dMB，超过阈值，已重启应用。"
else
    readonly TITLE="Memory Usage Alert"
    readonly BUTTON_1="OK"
    readonly MSG_NOT_RUNNING="not running"
    readonly MSG_CURRENT_MEMORY="Current memory usage"
    readonly MSG_EXCEEDED_THRESHOLD="Exceeded threshold"
    readonly MSG_RESTARTING="restarting"
    readonly MSG_NOTIFICATION_TEMPLATE="%s memory usage %dMB exceeded threshold, application restarted."
fi

# ===================== FUNCTIONS =====================

is_positive_integer() {
    [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]
}

# Log process
log_info() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
    trim_log_file_if_needed
}

trim_log_file_if_needed() {
    local max_bytes="$LOG_MAX_BYTES"
    local keep_lines="$LOG_KEEP_LINES"
    local file_size
    local tmp_file

    [ -f "$LOG_FILE" ] || return

    if ! is_positive_integer "$max_bytes"; then
        max_bytes="$DEFAULT_LOG_MAX_BYTES"
    fi

    if ! is_positive_integer "$keep_lines"; then
        keep_lines="$DEFAULT_LOG_KEEP_LINES"
    fi

    file_size="$(wc -c < "$LOG_FILE" | tr -d '[:space:]')"
    [ "$file_size" -le "$max_bytes" ] && return

    tmp_file="$(mktemp -t raycast_mem_monitor.log)"
    tail -n "$keep_lines" "$LOG_FILE" > "$tmp_file" || true
    mv "$tmp_file" "$LOG_FILE"
}

read_config_value() {
    local key="$1"
    local default_value="$2"
    local value=""

    if [ -f "$CONFIG_FILE" ]; then
        value=$(awk -F= -v key="$key" '
            /^[[:space:]]*#/ { next }
            $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
                value = $2
                sub(/^[[:space:]]+/, "", value)
                sub(/[[:space:]]+$/, "", value)
                gsub(/^"/, "", value)
                gsub(/"$/, "", value)
                print value
            }
        ' "$CONFIG_FILE" | tail -n 1)
    fi

    if is_positive_integer "$value"; then
        printf '%s\n' "$value"
    else
        printf '%s\n' "$default_value"
    fi
}

load_config() {
    MEM_THRESHOLD_MB="$(read_config_value "MEM_THRESHOLD_MB" "$DEFAULT_MEM_THRESHOLD_MB")"
    START_INTERVAL="$(read_config_value "START_INTERVAL" "$DEFAULT_START_INTERVAL")"
}

find_notifier_path() {
    local candidate
    local candidates=(
        "$NA_PRIMARY_APP_ROOT/$NA_APP_NAME/Contents/MacOS/IBM Notifier"
        "$NA_FALLBACK_APP_ROOT/$NA_APP_NAME/Contents/MacOS/IBM Notifier"
    )

    for candidate in "${candidates[@]}"; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

refresh_notifier_state() {
    if NA_PATH="$(find_notifier_path)"; then
        NOTIFIER_AVAILABLE=true
    else
        NA_PATH=""
        NOTIFIER_AVAILABLE=false
    fi
}

# Get raycast pid
get_app_pid() {
    pgrep -x "$APP_NAME" || true
}

# Get memeory usage
get_memory_mb() {
    local pid="$1"
    local mem_kb
    mem_kb=$(ps -o rss= -p "$pid" | tr -d '[:space:]')
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

run_check() {
    local app_pid
    local mem_mb
    local subtitle

    load_config
    refresh_notifier_state

    app_pid=$(get_app_pid)

    if [ -z "$app_pid" ]; then
        log_info "$APP_NAME $MSG_NOT_RUNNING"
        return 0
    fi

    mem_mb=$(get_memory_mb "$app_pid")
    log_info "$MSG_CURRENT_MEMORY: ${mem_mb}MB (threshold: ${MEM_THRESHOLD_MB}MB)"

    if [ "$mem_mb" -gt "$MEM_THRESHOLD_MB" ]; then
        log_info "$MSG_EXCEEDED_THRESHOLD (${mem_mb}MB > ${MEM_THRESHOLD_MB}MB), $MSG_RESTARTING $APP_NAME"
        restart_app "$app_pid"

        if [ "$NOTIFIER_AVAILABLE" = true ]; then
            subtitle=$(printf "$MSG_NOTIFICATION_TEMPLATE" "$APP_NAME" "$mem_mb")
            send_notification "$subtitle"
        fi
    fi
}

run_daemon() {
    while true; do
        run_check
        sleep "$START_INTERVAL"
    done
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [check|daemon|help]

check   Run one memory check immediately.
daemon  Run continuously and re-read config before every cycle.
help    Show this message.
EOF
}

# ===================== MAIN PROCEDURE =====================

main() {
    local action="${1:-check}"

    case "$action" in
        check)
            run_check
            ;;
        daemon)
            run_daemon
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
}

main "$@"
