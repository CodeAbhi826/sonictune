#!/usr/bin/env bash
# scripts/build-flatpak.sh — build the SonicTune Flatpak bundle.
#
# Output: sonictune.flatpak in the project root.
# Requires: flatpak + flatpak-builder installed.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flatpak-builder &>/dev/null; then
    echo "Error: flatpak-builder not installed."
    echo "  Fedora:    sudo dnf install flatpak-builder"
    echo "  Ubuntu:    sudo apt install flatpak-builder"
    echo "  Arch:      sudo pacman -S flatpak-builder"
    exit 1
fi

# Ensure GNOME runtime is installed
echo "=== Ensuring Flatpak runtimes ==="
flatpak install --user -y flathub org.gnome.Platform//46 org.gnome.Sdk//46 || true

echo ""
echo "=== Building Flatpak ==="
flatpak-builder \
    --user \
    --install \
    --force-clean \
    build-dir \
    flatpak/org.sonicTune.json

echo ""
echo "=== Building bundle ==="
flatpak build-bundle \
    ~/.local/share/flatpak/repo \
    sonictune.flatpak \
    org.sonicTune \
    stable

echo ""
echo "✓ Built sonictune.flatpak"
echo "  Install with: flatpak install --user sonictune.flatpak"
echo "  Run with:     flatpak run org.sonicTune"
