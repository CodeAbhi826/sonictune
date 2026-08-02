#!/usr/bin/env bash
# scripts/run.sh — run the unified SonicTune application (UI + services).
#
# Forwards all args to sonictune. Common flags:
#   --verbose       Enable debug logging
#   --no-mpris      Disable MPRIS integration
#   --no-discord    Disable Discord RPC

set -euo pipefail

cd "$(dirname "$0")/.."

# Make sure WAYLAND_DISPLAY is set if we're on Wayland
if [[ -z "${WAYLAND_DISPLAY:-}" && -n "${XDG_SESSION_TYPE:-}" ]]; then
    if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        export QT_QPA_PLATFORM=wayland
    fi
fi

if command -v uv &>/dev/null; then
    exec uv run python -m sonictune.app "$@"
else
    exec python3 -m sonictune.app "$@"
fi
