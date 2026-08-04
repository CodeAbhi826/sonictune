"""Tests for Performance detection (T-005 to T-006)."""
from __future__ import annotations

from unittest.mock import MagicMock, patch

from sonictune.performance import PerformanceProfile, detect_performance_tier


def test_performance_low_end_detection() -> None:
    """T-005: detect_performance_tier returns low-end profile for 2GB RAM."""
    mock_mem = MagicMock()
    mock_mem.total = 2 * 1024**3  # 2GB

    with patch("psutil.virtual_memory", return_value=mock_mem), patch("psutil.cpu_count", return_value=1):
            profile = detect_performance_tier()
            assert profile.reduced_motion is True
            assert profile.low_end_mode is True
            assert profile.disable_shadows is True
            assert profile.audio_cache_mb == 200
            assert profile.preload_enabled is False


def test_performance_profile_round_trip() -> None:
    """T-006: PerformanceProfile serializes and deserializes correctly."""
    p = PerformanceProfile(reduced_motion=True, audio_cache_mb=500)
    d = p.to_dict()
    p2 = PerformanceProfile.from_dict(d)
    assert p2.reduced_motion is True
    assert p2.audio_cache_mb == 500
    assert p2.low_end_mode is False
