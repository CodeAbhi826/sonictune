"""Tests for Audio Devices (T-025)."""
from __future__ import annotations

import subprocess

import pytest

from sonictune.audio.devices import AudioDevice, get_pulseaudio_devices


def test_pulseaudio_devices_list() -> None:
    """T-025: get_pulseaudio_devices returns list of AudioDevice."""
    # Check if pactl is available
    try:
        subprocess.run(["pactl", "info"], check=True, capture_output=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        pytest.skip("PulseAudio not available")

    devices = get_pulseaudio_devices()
    assert isinstance(devices, list)
    for d in devices:
        assert isinstance(d, AudioDevice)
        assert len(d.id) > 0
        assert len(d.name) > 0
