"""Tests for sonictune.library.models duration parsing (SB-7)."""
from __future__ import annotations

from sonictune.library.models import Track


def test_from_ytmusic_duration_seconds_int() -> None:
    t = Track.from_ytmusic({"videoId": "v1", "title": "T", "duration_seconds": 225})
    assert t.duration_ms == 225000


def test_from_ytmusic_duration_seconds_str() -> None:
    t = Track.from_ytmusic({"videoId": "v1", "title": "T", "duration_seconds": "3:45"})
    assert t.duration_ms == 225000


def test_from_ytmusic_duration_key_only() -> None:
    # Some endpoints omit duration_seconds but provide a plain "duration".
    t = Track.from_ytmusic({"videoId": "v1", "title": "T", "duration": 60})
    assert t.duration_ms == 60000


def test_from_ytmusic_duration_missing() -> None:
    t = Track.from_ytmusic({"videoId": "v1", "title": "T"})
    assert t.duration_ms == 0


def test_from_ytmusic_duration_iso_string() -> None:
    t = Track.from_ytmusic({"videoId": "v1", "title": "T", "duration_seconds": "PT4M5S"})
    assert t.duration_ms == 0  # unparseable -> 0, not a crash
