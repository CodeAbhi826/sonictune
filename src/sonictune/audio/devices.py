# src/sonictune/audio/devices.py
"""Output device detection + switching via PulseAudio (pactl)."""
from __future__ import annotations

import subprocess
from dataclasses import dataclass


@dataclass
class AudioDevice:
    id: str
    name: str
    is_default: bool = False


def get_pulseaudio_devices() -> list[AudioDevice]:
    try:
        result = subprocess.run(
            ["pactl", "list", "sinks"],
            capture_output=True, text=True, timeout=5
        )
        devices = []
        current_id = ""
        current_name = ""
        current_default = False

        for line in result.stdout.split("\n"):
            if line.startswith("Sink #"):
                if current_id:
                    devices.append(AudioDevice(current_id, current_name, current_default))
                current_id = line.replace("Sink #", "").strip()
                current_name = ""
                current_default = False
            elif "Name:" in line and current_id:
                current_name = line.split(":", 1)[1].strip()
            elif "Default Sink:" in line and current_id:
                current_default = True

        if current_id:
            devices.append(AudioDevice(current_id, current_name, current_default))
        return devices
    except Exception:
        return []


def set_pulseaudio_device(device_id: str) -> bool:
    try:
        subprocess.run(["pactl", "set-default-sink", device_id], check=True, timeout=5)
        return True
    except Exception:
        return False
