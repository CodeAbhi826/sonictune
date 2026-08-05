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


# ---- Wiring tests (G2): prove SponsorBlock is connected to the player --------


def _make_wired_app():
    """Build a lightweight fake app with the real SponsorBlock wiring bound."""
    import asyncio

    from sonictune.app import SonicTuneApp
    from sonictune.library.models import Track
    from sonictune.player.types import PlayerEvent

    class _FakePlayer:
        def __init__(self) -> None:
            self.listener = None
            self.seeks: list[int] = []
            self.current_track = Track(
                video_id="spvid", title="Song", artist="Artist", duration_ms=180000
            )

        def add_listener(self, cb) -> None:
            self.listener = cb

        async def seek(self, ms: int) -> None:
            self.seeks.append(ms)

    player = _FakePlayer()
    sb = SponsorBlock()
    app = type("App", (), {"player": player, "sponsorblock": sb})()

    async def _run() -> None:
        SonicTuneApp._wire_sponsorblock(app)
        player.listener(PlayerEvent.POSITION_CHANGED, {"position_ms": 12000, "duration_ms": 180000})
        await asyncio.sleep(0)

    asyncio.run(_run())
    return app


def test_sponsorblock_wired_pos_changed_seeks() -> None:
    """G2: a POSITION_CHANGED event through the app wiring seeks past a segment."""
    app = _make_wired_app()
    sb = app.sponsorblock
    sb._cache["spvid"] = [(10.0, 15.0)]

    player = app.player
    # Re-drive the position tick now that a segment is cached.
    from sonictune.player.types import PlayerEvent

    async def _tick() -> None:
        player.listener(PlayerEvent.POSITION_CHANGED, {"position_ms": 12000, "duration_ms": 180000})
        await asyncio.sleep(0)

    asyncio.run(_tick())
    assert player.seeks == [15000]


def test_sponsorblock_wired_outside_segment_no_seek() -> None:
    """G2: a position outside any segment does not seek."""
    app = _make_wired_app()
    app.sponsorblock._cache["spvid"] = [(10.0, 15.0)]
    from sonictune.player.types import PlayerEvent

    async def _tick() -> None:
        app.player.listener(PlayerEvent.POSITION_CHANGED, {"position_ms": 20000, "duration_ms": 180000})
        await asyncio.sleep(0)

    asyncio.run(_tick())
    assert app.player.seeks == []


def test_sponsorblock_wired_track_change_fetches() -> None:
    """G2: a TRACK_CHANGED event through the app wiring fetches segments."""
    from sonictune.app import SonicTuneApp
    from sonictune.player.types import PlayerEvent

    app = _make_wired_app()
    app._fetch_sponsorblock_segments = SonicTuneApp._fetch_sponsorblock_segments.__get__(
        app, type(app)
    )
    fetched: list[str] = []

    async def fake_get_segments(video_id: str):
        fetched.append(video_id)
        return []

    app.sponsorblock.get_segments = fake_get_segments

    async def _tick() -> None:
        app.player.listener(PlayerEvent.TRACK_CHANGED, {"track": app.player.current_track})
        await asyncio.sleep(0)

    asyncio.run(_tick())
    assert fetched == ["spvid"]
