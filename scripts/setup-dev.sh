#!/usr/bin/env bash
# scripts/setup-dev.sh — one-shot setup for SonicTune development.
#
# Installs:
#   - System dependencies (via apt/dnf/pacman)
#   - Python dependencies (via uv if available, else pip)
#   - Creates initial config dirs
#
# Usage:
#   ./scripts/setup-dev.sh          # full setup
#   ./scripts/setup-dev.sh --skip-system  # skip system packages

set -euo pipefail

SKIP_SYSTEM=0
for arg in "$@"; do
    case "$arg" in
        --skip-system) SKIP_SYSTEM=1 ;;
        *) echo "Unknown arg: $arg"; exit 1 ;;
    esac
done

echo "=== SonicTune dev setup ==="

# --- Detect distro ---------------------------------------------------------

DISTRO=""
if [[ -f /etc/fedora-release ]]; then
    DISTRO="fedora"
elif [[ -f /etc/debian_version ]]; then
    DISTRO="debian"
elif [[ -f /etc/arch-release ]]; then
    DISTRO="arch"
else
    echo "Warning: Could not detect distro. Skipping system package install."
    SKIP_SYSTEM=1
fi

# --- Install system packages ----------------------------------------------

if [[ $SKIP_SYSTEM -eq 0 ]]; then
    echo ""
    echo "=== Installing system packages ($DISTRO) ==="

    case "$DISTRO" in
        fedora)
            sudo dnf install -y \
                python3-devel \
                qt6-qtbase-devel \
                qt6-qtdeclarative-devel \
                qt6-qtquickcontrols2-devel \
                mpv-libs-devel \
                pipewire-devel \
                meson \
                ninja-build \
                pkgconf-pkg-config
            ;;
        debian)
            sudo apt update
            sudo apt install -y \
                python3-dev \
                python3-venv \
                qt6-base-dev \
                qt6-declarative-dev \
                qt6-quickcontrols2-dev \
                libmpv-dev \
                libmpv2 \
                meson \
                ninja-build \
                pkg-config
            ;;
        arch)
            sudo pacman -S --needed \
                python \
                python-pip \
                qt6-base \
                qt6-declarative \
                qt6-quickcontrols2 \
                mpv \
                meson \
                ninja \
                pkgconf
            ;;
    esac
    echo "✓ System packages installed"
fi

# --- Install uv (if not present) -------------------------------------------

if ! command -v uv &>/dev/null; then
    echo ""
    echo "=== Installing uv (fast Python package manager) ==="
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Add to PATH for this session
    export PATH="$HOME/.local/bin:$PATH"
    echo "✓ uv installed"
fi

# --- Install Python dependencies -------------------------------------------

echo ""
echo "=== Installing Python dependencies ==="
uv sync --dev
echo "✓ Python dependencies installed"

# --- Create config dirs ----------------------------------------------------

echo ""
echo "=== Creating config directories ==="
mkdir -p \
    "$HOME/.config/sonictune" \
    "$HOME/.cache/sonictune/audio" \
    "$HOME/.cache/sonictune/art" \
    "$HOME/.local/share/sonictune/logs"
echo "✓ Config dirs created at ~/.config/sonictune/"

# --- Verify ----------------------------------------------------------------

echo ""
echo "=== Verification ==="
echo "Python: $(python3 --version)"
echo "uv:     $(uv --version)"
if command -v mpv &>/dev/null; then
    echo "mpv:    $(mpv --version | head -1)"
else
    echo "mpv:    not found in PATH (may still be available as a library)"
fi

echo ""
echo "✓ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Start SonicTune:  ./scripts/run.sh --verbose"
echo "  2. Read docs/SETUP.md for OAuth credentials setup"
