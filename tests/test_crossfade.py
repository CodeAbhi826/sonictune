"""Tests for Crossfade (T-020 to T-021)."""
from __future__ import annotations

import asyncio
from unittest.mock import MagicMock

from sonictune.player.mpv_player import MpvPlayer


def test_crossfade_clamp_high() -> None:
    """T-020: set_crossfade clamps values above 12 to 12."""
    player = MpvPlayer()
    player._mpv = MagicMock()
    asyncio.run(player.set_crossfade(20))
    assert player._crossfade_seconds == 12


def test_crossfade_disable() -> None:
    """T-021: set_crossfade(0) disables crossfade."""
    player = MpvPlayer()
    player._mpv = MagicMock()
    asyncio.run(player.set_crossfade(0))
    assert player._crossfade_seconds == 0
    assert player._mpv.af == ""
