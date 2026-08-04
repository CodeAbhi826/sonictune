"""Tests for Audio Quality (T-007 to T-012)."""
from __future__ import annotations

import asyncio
from unittest.mock import MagicMock

from sonictune.config import QUALITY_ITAG_MAP, resolve_high_quality
from sonictune.daemon_proxy import DaemonProxy


def test_audio_quality_map_has_3_keys() -> None:
    """T-007: QUALITY_ITAG_MAP has exactly 3 entries."""
    assert len(QUALITY_ITAG_MAP) == 3
    assert "low" in QUALITY_ITAG_MAP
    assert "standard" in QUALITY_ITAG_MAP
    assert "high" in QUALITY_ITAG_MAP
    assert "very_high" not in QUALITY_ITAG_MAP


def test_audio_quality_itag_values() -> None:
    """T-008: Each quality level maps to correct itag."""
    assert QUALITY_ITAG_MAP["low"] == 249
    assert QUALITY_ITAG_MAP["standard"] == 250
    assert QUALITY_ITAG_MAP["high"] == 0  # 0 means auto-resolve


def test_resolve_high_quality_fallback() -> None:
    """T-009: resolve_high_quality falls back to 251 without auth."""
    result = asyncio.run(resolve_high_quality("dQw4w9WgXcQ", ytm=None))
    assert result == 251


def test_resolve_high_quality_with_mock_premium() -> None:
    """T-010: resolve_high_quality returns 141 when Premium format is available."""
    mock_ytm = MagicMock()
    mock_ytm.auth = True
    mock_ytm.get_song.return_value = {
        "adaptiveFormats": [{"itag": 141}, {"itag": 251}]
    }
    result = asyncio.run(resolve_high_quality("test123", ytm=mock_ytm))
    assert result == 141


def make_test_proxy() -> DaemonProxy:
    """Create a minimal DaemonProxy for testing."""
    from types import SimpleNamespace
    from unittest.mock import MagicMock

    config = SimpleNamespace(audio=SimpleNamespace(quality="standard", itag=0))
    return DaemonProxy(
        player=MagicMock(),
        queue=MagicMock(),
        library=MagicMock(),
        oauth=MagicMock(),
        lyrics=MagicMock(),
        stats=MagicMock(),
        art_cache=MagicMock(),
        audio_cache=MagicMock(),
        db=MagicMock(),
        sync=MagicMock(),
        config=config,
    )


def test_daemon_proxy_set_audio_quality_valid() -> None:
    """T-011: setAudioQuality updates config for valid quality."""
    proxy = make_test_proxy()
    proxy.setAudioQuality("standard")
    assert proxy.audioQuality() == "standard"
    assert proxy._config.audio.itag == 250


def test_daemon_proxy_set_audio_quality_invalid() -> None:
    """T-012: setAudioQuality ignores invalid quality string."""
    proxy = make_test_proxy()
    proxy.setAudioQuality("standard")
    proxy.setAudioQuality("ultra_mega_hd")
    assert proxy.audioQuality() == "standard"  # unchanged


def test_daemon_proxy_audio_quality_ui_signal() -> None:
    """T-047: setAudioQuality emits audioQualityChanged with the new value."""
    proxy = make_test_proxy()
    spy = MagicMock()
    proxy.audioQualityChanged.connect(spy)
    proxy.setAudioQuality("low")
    spy.assert_called_once_with("low")
