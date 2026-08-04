# src/sonictune/performance.py
from __future__ import annotations

from dataclasses import asdict, dataclass

import psutil


@dataclass
class PerformanceProfile:
    reduced_motion: bool = False
    low_end_mode: bool = False
    disable_shadows: bool = False
    disable_image_cache: bool = False
    image_source_size: int = 512
    list_cache_buffer: int = 200
    smooth_scrolling: bool = True
    default_audio_quality: str = "standard"
    audio_cache_mb: int = 1000
    preload_enabled: bool = True

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, d: dict) -> PerformanceProfile:
        return cls(**d)


def detect_performance_tier() -> PerformanceProfile:
    mem_gb = psutil.virtual_memory().total / (1024**3)
    cpu_count = psutil.cpu_count()

    cpu_info = ""
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if "model name" in line:
                    cpu_info = line.split(":")[1].strip()
                    break
    except Exception:
        pass

    is_low_end = (
        mem_gb < 3
        or cpu_count <= 2
        or "celeron" in cpu_info.lower()
        or "pentium" in cpu_info.lower()
        or "atom" in cpu_info.lower()
    )

    if is_low_end:
        return PerformanceProfile(
            reduced_motion=True,
            low_end_mode=True,
            disable_shadows=True,
            disable_image_cache=True,
            image_source_size=256,
            list_cache_buffer=0,
            smooth_scrolling=False,
            default_audio_quality="standard",
            audio_cache_mb=200,
            preload_enabled=False,
        )
    elif mem_gb < 6:
        return PerformanceProfile(
            default_audio_quality="standard",
            audio_cache_mb=1000,
        )
    else:
        return PerformanceProfile(
            default_audio_quality="high",
            audio_cache_mb=2000,
        )
