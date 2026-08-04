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

# Start Xvfb in the background
Xvfb :1 -screen 0 1024x768x24 &
export DISPLAY=:1

# Verify setup
echo "Dev container setup complete!"