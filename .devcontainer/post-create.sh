#!/bin/bash

# Install system dependencies
sudo apt-get update && \
    sudo apt-get install -y \
    xvfb \
    libxcb-xinerama0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-render-util0 \
    libxcb-util1 \
    libxkbcommon-x11-0 \
    libxcb-cursor0

# Install Python dependencies
pip install --upgrade pip
pip install -e .
pip install pytest-playwright pytest-qt
playwright install

# Persist DISPLAY for all interactive shells (plain `export` here would die
# with this script; profile.d survives across execs and restarts).
sudo tee /etc/profile.d/sonictune-dev.sh >/dev/null <<'EOF'
export DISPLAY=:1
EOF

# Verify setup
echo "Dev container setup complete!"