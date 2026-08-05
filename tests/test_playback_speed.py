"""Tests for Playback Speed (T-022)."""
from __future__ import annotations

import asyncio
from unittest.mock import MagicMock

import pytest

mpv = pytest.importorskip("mpv")
from sonictune.player.mpv_player import MpvPlayer  # noqa: E402


def test_playback_speed_clamp() -> None:
    """T-022: set_speed clamps to [0.5, 2.0]."""
    player = MpvPlayer()
    player._mpv = MagicMock()
    asyncio.run(player.set_speed(5.0))
    assert player._speed == 2.0
    asyncio.run(player.set_speed(0.1))
    assert player._speed == 0.5
