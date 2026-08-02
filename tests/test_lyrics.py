"""Tests for sonictune.lyrics.lrclib (LRC parsing only)."""
from __future__ import annotations

from sonictune.lyrics.lrclib import LrclibClient


def test_parse_simple_lrc() -> None:
    client = LrclibClient()
    lrc = """
[00:01.00]First line
[00:03.50]Second line
[00:07.00]Third line
"""
    lines = client._parse_lrc(lrc)
    assert len(lines) == 3
    assert lines[0].time_ms == 1000
    assert lines[0].text == "First line"
    assert lines[1].time_ms == 3500
    assert lines[2].time_ms == 7000


def test_parse_lrc_skips_metadata_tags() -> None:
    client = LrclibClient()
    lrc = """
[ar:Queen]
[al:A Night at the Opera]
[00:01.00]Is this the real life?
[00:05.00]Is this just fantasy?
"""
    lines = client._parse_lrc(lrc)
    # Metadata tags should be skipped
    assert len(lines) == 2
    assert lines[0].text == "Is this the real life?"


def test_parse_lrc_multi_timestamps() -> None:
    """Multiple timestamps on one line should produce multiple LyricLines."""
    client = LrclibClient()
    lrc = "[00:01.00][00:05.00]Repeated line"
    lines = client._parse_lrc(lrc)
    assert len(lines) == 2
    assert lines[0].time_ms == 1000
    assert lines[1].time_ms == 5000
    assert lines[0].text == "Repeated line"


def test_parse_lrc_offset() -> None:
    client = LrclibClient()
    client.set_offset(500)  # +500ms
    lrc = "[00:01.00]Line"
    lines = client._parse_lrc(lrc)
    assert lines[0].time_ms == 1500  # 1000 + 500 offset


def test_parse_lrc_negative_offset_doesnt_go_below_zero() -> None:
    client = LrclibClient()
    client.set_offset(-2000)  # -2s
    lrc = "[00:01.00]Line"
    lines = client._parse_lrc(lrc)
    assert lines[0].time_ms == 0  # clamped


def test_parse_lrc_empty() -> None:
    client = LrclibClient()
    assert client._parse_lrc("") == []
    assert client._parse_lrc("\n\n") == []


def test_parse_timestamp() -> None:
    assert LrclibClient._parse_timestamp("01:30") == 90_000
    assert LrclibClient._parse_timestamp("01:30.50") == 90_500
    assert LrclibClient._parse_timestamp("0:05") == 5_000
    assert LrclibClient._parse_timestamp("not a timestamp") is None
    assert LrclibClient._parse_timestamp("ar:Queen") is None
