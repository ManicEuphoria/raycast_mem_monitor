#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RMM_CLI="$REPO_DIR/rmm"

[ -x "$RMM_CLI" ] || {
    printf '[deploy] Missing CLI entrypoint: %s\n' "$RMM_CLI" >&2
    exit 1
}

if [ "$#" -eq 0 ]; then
    exec "$RMM_CLI" -i
fi

case "${1:-}" in
    install)
        shift
        exec "$RMM_CLI" -i "$@"
        ;;
    help)
        exec "$RMM_CLI" help
        ;;
    *)
        exec "$RMM_CLI" "$@"
        ;;
esac
