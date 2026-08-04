"""Tests for Last.fm (T-028 to T-029)."""
from __future__ import annotations

import asyncio

from sonictune.integrations.lastfm import LastFmScrobbler


def test_lastfm_sign() -> None:
    """T-028: LastFmScrobbler._sign produces consistent MD5."""
    scrobbler = LastFmScrobbler("key", "secret", "session")
    sig1 = scrobbler._sign({"a": "1", "b": "2"})
    sig2 = scrobbler._sign({"a": "1", "b": "2"})
    assert sig1 == sig2
    assert len(sig1) == 32  # MD5 hex length


def test_lastfm_disabled() -> None:
    """T-029: LastFmScrobbler.scrobble returns False when disabled."""
    scrobbler = LastFmScrobbler("key", "secret", "")  # empty session = disabled
    result = asyncio.run(scrobbler.scrobble("Artist", "Title", 123456))
    assert result is False


def test_lastfm_now_playing_disabled() -> None:
    """T-050: now_playing returns False when disabled."""
    scrobbler = LastFmScrobbler("key", "secret", "")
    result = asyncio.run(scrobbler.now_playing("Artist", "Title"))
    assert result is False
