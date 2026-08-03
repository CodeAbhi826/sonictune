"""Tests for sonictune.utils.helpers."""
from __future__ import annotations

from sonictune.utils.helpers import (
    format_duration,
    humanize_bytes,
    is_valid_video_id,
    parse_duration,
    truncate,
)


def test_format_duration_basic() -> None:
    assert format_duration(0) == "0:00"
    assert format_duration(1000) == "0:01"
    assert format_duration(60_000) == "1:00"
    assert format_duration(65_000) == "1:05"
    assert format_duration(3_600_000) == "1:00:00"
    assert format_duration(3_661_000) == "1:01:01"


def test_parse_duration_round_trip() -> None:
    for ms in [0, 1000, 60_000, 65_000, 3_600_000, 3_661_000]:
        assert parse_duration(format_duration(ms)) == ms


def test_parse_duration_invalid() -> None:
    assert parse_duration("not a duration") == 0
    assert parse_duration("") == 0


def test_is_valid_video_id() -> None:
    # 11-char base64-urlsafe
    assert is_valid_video_id("dQw4w9WgXcQ") is True
    assert is_valid_video_id("abc-_123ABC") is True

    # Wrong length
    assert is_valid_video_id("short") is False
    assert is_valid_video_id("thisiswaytoolongidentifier") is False

    # Invalid chars
    assert is_valid_video_id("dQw4w9WgXc!") is False
    assert is_valid_video_id("dQw4w9WgXc ") is False


def test_humanize_bytes() -> None:
    assert humanize_bytes(0) == "0 B"
    assert humanize_bytes(1023) == "1023 B"
    assert humanize_bytes(1024) == "1.0 KB"
    assert humanize_bytes(1536) == "1.5 KB"
    assert humanize_bytes(1024 * 1024) == "1.0 MB"
    assert humanize_bytes(1024 ** 3) == "1.0 GB"


def test_truncate() -> None:
    assert truncate("hello", 10) == "hello"
    assert truncate("hello world", 8) == "hello w…"
    assert truncate("hello", 5) == "hello"
    assert truncate("hello", 4) == "hel…"
