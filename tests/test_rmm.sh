#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly RMM_BIN="$REPO_DIR/rmm"

fail() {
    printf 'test failure: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local haystack="$1"
    local needle="$2"

    [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_file_contains() {
    local path="$1"
    local needle="$2"

    grep -q "$needle" "$path" || fail "expected $path to contain: $needle"
}

assert_line_count_at_most() {
    local path="$1"
    local expected_max="$2"
    local actual_count

    actual_count="$(wc -l < "$path" | tr -d '[:space:]')"
    [ "$actual_count" -le "$expected_max" ] || fail "expected $path to have at most $expected_max lines, got $actual_count"
}

make_notifier_fixture() {
    local fixture_root="$1"
    local archive_path="$2"
    local app_root="$fixture_root/IBM Notifier.app/Contents/MacOS"

    mkdir -p "$app_root"
    cat <<'EOF' > "$app_root/IBM Notifier"
#!/bin/bash
exit 0
EOF
    chmod +x "$app_root/IBM Notifier"
    ditto -c -k --sequesterRsrc --keepParent "$fixture_root/IBM Notifier.app" "$archive_path"
}

make_release_json() {
    local archive_path="$1"
    local release_json_path="$2"
    local digest

    digest="$(shasum -a 256 "$archive_path" | awk '{print $1}')"

    cat <<EOF > "$release_json_path"
{
  "tag_name": "v-test",
  "name": "Test Release",
  "assets": [
    {
      "name": "IBM.Notifier.zip",
      "browser_download_url": "file://$archive_path",
      "digest": "sha256:$digest"
    }
  ]
}
EOF
}

run_with_env() {
    local env_root="$1"
    shift

    HOME="$env_root/home" \
    RMM_NOTIFIER_PRIMARY_APP_ROOT="$env_root/apps" \
    RMM_NOTIFIER_FALLBACK_APP_ROOT="$env_root/apps" \
    RMM_SKIP_SERVICE_RESTART=true \
    "$@"
}

test_help_and_config_updates() {
    local env_root
    local output
    local config_path

    env_root="$(mktemp -d /tmp/rmm-test-config.XXXXXX)"
    trap "rm -rf '$env_root'" RETURN

    mkdir -p "$env_root/home"

    output="$(run_with_env "$env_root" "$RMM_BIN" help)"
    assert_contains "$output" "install-notifier"

    output="$(run_with_env "$env_root" "$RMM_BIN" -cm 500)"
    assert_contains "$output" "Set MEM_THRESHOLD_MB=500"

    output="$(run_with_env "$env_root" "$RMM_BIN" -ct 200)"
    assert_contains "$output" "Set START_INTERVAL=200"

    config_path="$env_root/home/Library/Application Support/raycast_mem_monitor/raycast_mem_monitor.conf"
    [ -f "$config_path" ] || fail "missing config file after update"
    assert_file_contains "$config_path" "MEM_THRESHOLD_MB=500"
    assert_file_contains "$config_path" "START_INTERVAL=200"
}

test_log_truncation() {
    local env_root
    local log_path
    local output

    env_root="$(mktemp -d /tmp/rmm-test-log.XXXXXX)"
    trap "rm -rf '$env_root'" RETURN

    mkdir -p "$env_root/home"
    log_path="$env_root/home/test.log"

    cat <<'EOF' > "$log_path"
line 1
line 2
line 3
line 4
line 5
line 6
EOF

    output="$(
        HOME="$env_root/home" \
        RMM_LOG_FILE="$log_path" \
        RMM_LOG_MAX_BYTES=20 \
        RMM_LOG_KEEP_LINES=2 \
        bash "$REPO_DIR/raycast_mem_monitor.sh" check
    )"
    [ -z "$output" ] || fail "expected no stdout from direct check"

    assert_line_count_at_most "$log_path" 2
}

test_install_notifier_from_release_metadata() {
    local env_root
    local fixture_root
    local archive_path
    local release_json_path
    local output
    local installed_binary

    env_root="$(mktemp -d /tmp/rmm-test-notifier-api.XXXXXX)"
    trap "rm -rf '$env_root'" RETURN

    mkdir -p "$env_root/home" "$env_root/apps" "$env_root/fixture"
    fixture_root="$env_root/fixture"
    archive_path="$fixture_root/IBM.Notifier.zip"
    release_json_path="$fixture_root/release.json"

    make_notifier_fixture "$fixture_root" "$archive_path"
    make_release_json "$archive_path" "$release_json_path"

    output="$(
        HOME="$env_root/home" \
        RMM_NOTIFIER_PRIMARY_APP_ROOT="$env_root/apps" \
        RMM_NOTIFIER_FALLBACK_APP_ROOT="$env_root/apps" \
        RMM_SKIP_SERVICE_RESTART=true \
        RMM_NOTIFIER_LATEST_RELEASE_API="file://$release_json_path" \
        "$RMM_BIN" install-notifier
    )"
    assert_contains "$output" "Installed IBM Notifier to:"

    installed_binary="$env_root/apps/IBM Notifier.app/Contents/MacOS/IBM Notifier"
    [ -x "$installed_binary" ] || fail "expected notifier binary at $installed_binary"

    output="$(
        HOME="$env_root/home" \
        RMM_NOTIFIER_PRIMARY_APP_ROOT="$env_root/apps" \
        RMM_NOTIFIER_FALLBACK_APP_ROOT="$env_root/apps" \
        RMM_SKIP_SERVICE_RESTART=true \
        "$RMM_BIN" status
    )"
    assert_contains "$output" "IBM Notifier: installed at $installed_binary"
}

test_install_notifier_fallback_download() {
    local env_root
    local fixture_root
    local archive_path
    local output
    local installed_binary

    env_root="$(mktemp -d /tmp/rmm-test-notifier-fallback.XXXXXX)"
    trap "rm -rf '$env_root'" RETURN

    mkdir -p "$env_root/home" "$env_root/apps" "$env_root/fixture"
    fixture_root="$env_root/fixture"
    archive_path="$fixture_root/IBM.Notifier.zip"

    make_notifier_fixture "$fixture_root" "$archive_path"

    output="$(
        HOME="$env_root/home" \
        RMM_NOTIFIER_PRIMARY_APP_ROOT="$env_root/apps" \
        RMM_NOTIFIER_FALLBACK_APP_ROOT="$env_root/apps" \
        RMM_SKIP_SERVICE_RESTART=true \
        RMM_NOTIFIER_LATEST_RELEASE_API="file://$fixture_root/missing.json" \
        RMM_NOTIFIER_LATEST_DOWNLOAD_URL="file://$archive_path" \
        "$RMM_BIN" -n 2>/dev/null
    )"
    assert_contains "$output" "falling back to releases/latest/download"
    assert_contains "$output" "Installed IBM Notifier to:"

    installed_binary="$env_root/apps/IBM Notifier.app/Contents/MacOS/IBM Notifier"
    [ -x "$installed_binary" ] || fail "expected notifier binary at $installed_binary"

    output="$(
        HOME="$env_root/home" \
        RMM_NOTIFIER_PRIMARY_APP_ROOT="$env_root/apps" \
        RMM_NOTIFIER_FALLBACK_APP_ROOT="$env_root/apps" \
        RMM_SKIP_SERVICE_RESTART=true \
        "$RMM_BIN" -n
    )"
    assert_contains "$output" "IBM Notifier already installed at: $installed_binary"
}

main() {
    bash -n "$REPO_DIR/rmm" "$REPO_DIR/raycast_mem_monitor.sh" "$REPO_DIR/deploy.sh"
    test_help_and_config_updates
    test_log_truncation
    test_install_notifier_from_release_metadata
    test_install_notifier_fallback_download
    printf 'tests passed\n'
}

main "$@"
