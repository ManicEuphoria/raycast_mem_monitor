#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SOURCE_SCRIPT="$REPO_DIR/raycast_mem_monitor.sh"
readonly SOURCE_PLIST="$REPO_DIR/com.user.raycastmem.plist"
readonly INSTALL_DIR="$HOME/Library/Application Support/raycast_mem_monitor"
readonly TARGET_SCRIPT="$INSTALL_DIR/raycast_mem_monitor.sh"
readonly LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
readonly TARGET_PLIST="$LAUNCH_AGENTS_DIR/$(basename "$SOURCE_PLIST")"
readonly SCRIPT_PATH_TOKEN="__SCRIPT_PATH__"

log() {
    printf '[deploy] %s\n' "$1"
}

fail() {
    printf '[deploy] %s\n' "$1" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: ./deploy.sh [install|dry-run|status|uninstall|help]

install    Install or update the monitor script and LaunchAgent, then reload launchd.
dry-run    Render and validate the LaunchAgent without writing to the system.
status     Show installed paths and current launchd state.
uninstall  Remove the installed LaunchAgent and script from the user directory.
help       Show this message.
EOF
}

require_source_files() {
    [ -f "$SOURCE_SCRIPT" ] || fail "Missing source script: $SOURCE_SCRIPT"
    [ -f "$SOURCE_PLIST" ] || fail "Missing source plist: $SOURCE_PLIST"
    grep -q "$SCRIPT_PATH_TOKEN" "$SOURCE_PLIST" || fail "Missing $SCRIPT_PATH_TOKEN placeholder in $SOURCE_PLIST"
}

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

render_plist() {
    local output_path="$1"
    local escaped_script_path

    escaped_script_path="$(escape_sed_replacement "$TARGET_SCRIPT")"
    sed "s|$SCRIPT_PATH_TOKEN|$escaped_script_path|g" "$SOURCE_PLIST" > "$output_path"
    plutil -lint "$output_path" >/dev/null
}

read_plist_label() {
    local plist_path="$1"
    /usr/libexec/PlistBuddy -c 'Print :Label' "$plist_path"
}

make_temp_plist() {
    mktemp -t raycast_mem_monitor
}

bootout_label_if_needed() {
    local label="$1"
    local domain="gui/$(id -u)"

    launchctl bootout "$domain/$label" >/dev/null 2>&1 || true
}

install_or_update() {
    local tmp_plist
    local previous_label=""
    local label
    local domain="gui/$(id -u)"

    require_source_files

    if [ -f "$TARGET_PLIST" ]; then
        previous_label="$(read_plist_label "$TARGET_PLIST" 2>/dev/null || true)"
    fi

    mkdir -p "$INSTALL_DIR" "$LAUNCH_AGENTS_DIR"
    install -m 755 "$SOURCE_SCRIPT" "$TARGET_SCRIPT"

    tmp_plist="$(make_temp_plist)"
    trap "rm -f '$tmp_plist'" EXIT
    render_plist "$tmp_plist"
    install -m 644 "$tmp_plist" "$TARGET_PLIST"

    label="$(read_plist_label "$TARGET_PLIST")"
    if [ -n "$previous_label" ] && [ "$previous_label" != "$label" ]; then
        bootout_label_if_needed "$previous_label"
    fi
    bootout_label_if_needed "$label"
    launchctl bootstrap "$domain" "$TARGET_PLIST"
    launchctl enable "$domain/$label"
    launchctl kickstart -k "$domain/$label"

    log "Installed script to: $TARGET_SCRIPT"
    log "Installed LaunchAgent to: $TARGET_PLIST"
    log "Reloaded launchd label: $label"
}

dry_run() {
    local tmp_plist
    local label

    require_source_files

    tmp_plist="$(make_temp_plist)"
    trap "rm -f '$tmp_plist'" EXIT
    render_plist "$tmp_plist"
    label="$(read_plist_label "$tmp_plist")"

    log "Dry run passed"
    log "Would install script to: $TARGET_SCRIPT"
    log "Would install LaunchAgent to: $TARGET_PLIST"
    log "Resolved launchd label: $label"
}

status() {
    local label=""
    local domain="gui/$(id -u)"

    log "Source script: $SOURCE_SCRIPT"
    log "Source plist: $SOURCE_PLIST"
    log "Installed script: $TARGET_SCRIPT"
    log "Installed LaunchAgent: $TARGET_PLIST"

    if [ -f "$TARGET_PLIST" ]; then
        label="$(read_plist_label "$TARGET_PLIST")"
        log "Launchd label: $label"
        launchctl print "$domain/$label" >/dev/null 2>&1 && log "LaunchAgent state: loaded" || log "LaunchAgent state: not loaded"
    else
        log "LaunchAgent state: not installed"
    fi
}

uninstall() {
    local label=""

    if [ -f "$TARGET_PLIST" ]; then
        label="$(read_plist_label "$TARGET_PLIST")"
        bootout_label_if_needed "$label"
        rm -f "$TARGET_PLIST"
        log "Removed LaunchAgent: $TARGET_PLIST"
    else
        log "LaunchAgent not installed"
    fi

    if [ -f "$TARGET_SCRIPT" ]; then
        rm -f "$TARGET_SCRIPT"
        log "Removed script: $TARGET_SCRIPT"
    else
        log "Installed script not found"
    fi
}

main() {
    local action="${1:-install}"

    case "$action" in
        install)
            install_or_update
            ;;
        dry-run)
            dry_run
            ;;
        status)
            status
            ;;
        uninstall)
            uninstall
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            usage
            fail "Unknown action: $action"
            ;;
    esac
}

main "$@"
