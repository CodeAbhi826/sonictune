"""Tests for SponsorBlock (T-023 to T-024)."""
from __future__ import annotations

import asyncio

from sonictune.player.sponsorblock import SponsorBlock


def test_sponsorblock_should_skip() -> None:
    """T-023: SponsorBlock.should_skip returns correct end time."""
    sb = SponsorBlock()
    sb._cache["test_vid"] = [(10.0, 15.0), (30.0, 35.0)]
    assert sb.should_skip("test_vid", 12000) == 15000
    assert sb.should_skip("test_vid", 20000) is None
    assert sb.should_skip("missing", 10000) is None


def test_sponsorblock_fetch() -> None:
    """T-024: SponsorBlock.get_segments returns list."""
    sb = SponsorBlock(enabled=True)
    result = asyncio.run(sb.get_segments("dQw4w9WgXcQ"))
    assert isinstance(result, list)


def test_sponsorblock_skip_at_segment_start() -> None:
    """should_skip skips exactly at the segment start boundary."""
    sb = SponsorBlock()
    sb._cache["vid"] = [(10.0, 15.0)]
    assert sb.should_skip("vid", 10000) == 15000


def test_sponsorblock_disabled_never_skips() -> None:
    """should_skip returns None when disabled."""
    sb = SponsorBlock(enabled=False)
    sb._cache["vid"] = [(10.0, 15.0)]
    assert sb.should_skip("vid", 12000) is None
