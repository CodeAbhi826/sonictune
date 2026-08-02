"""Tests for sonictune.mpris.server (category H — MPRIS).

Uses a NullPlayer-like stub so real D-Bus / libmpv are never touched.
"""
from __future__ import annotations

import asyncio

from sonictune.library.models import Track
from sonictune.mpris.server import MprisPlayerInterface, MprisRootInterface
from sonictune.player.null_player import NullPlayer
from sonictune.player.queue import QueueManager, RepeatMode


class _FakeLibrary:
    async def get_stream_url(self, video_id: str, itag: int = 0) -> str:
        return f"https://stream/{video_id}"


class _FakeConfig:
    class Audio:
        itag = 141

    audio = Audio()


def _make_interfaces() -> tuple[MprisPlayerInterface, MprisRootInterface, QueueManager, NullPlayer]:
    player = NullPlayer()
    queue = QueueManager()
    config = _FakeConfig()
    root = MprisRootInterface(player, queue, _FakeLibrary(), config)
    player_iface = MprisPlayerInterface(player, queue, _FakeLibrary(), config)
    return player_iface, root, queue, player


def test_mpris_root_identity() -> None:
    player = NullPlayer()
    root = MprisRootInterface(player, QueueManager(), None, None)
    assert root.Identity == "SonicTune"
    assert root.DesktopEntry == "org.sonicTune"
    assert root.CanRaise is True


async def test_mpris_player_properties() -> None:
    player = NullPlayer()
    q = QueueManager()
    iface = MprisPlayerInterface(player, q, None, None)
    assert iface.PlaybackStatus in ("Stopped", "Paused", "Playing")
    assert iface.Volume >= 0.0
    assert iface.CanControl is True


async def test_mpris_volume_setter() -> None:
    player = NullPlayer()
    iface = MprisPlayerInterface(player, QueueManager(), None, None)
    iface.Volume = 0.5
    await asyncio.sleep(0.05)
    assert player.volume == 50


async def test_mpris_loop_setter() -> None:
    q = QueueManager()
    iface = MprisPlayerInterface(NullPlayer(), q, None, None)
    iface.LoopStatus = "Playlist"
    await asyncio.sleep(0.05)
    assert q.repeat == RepeatMode.ALL


async def test_mpris_shuffle_setter() -> None:
    q = QueueManager()
    iface = MprisPlayerInterface(NullPlayer(), q, None, None)
    iface.Shuffle = True
    await asyncio.sleep(0.05)
    assert q.shuffle is True


async def test_mpris_next_advances_queue() -> None:
    q = QueueManager()
    await q.add_tracks([Track("a", "A"), Track("b", "B"), Track("c", "C")])
    iface = MprisPlayerInterface(NullPlayer(), q, None, None)
    iface.Next()
    await asyncio.sleep(0.05)
    assert q.current_track().video_id == "b"
    iface.Next()
    await asyncio.sleep(0.05)
    assert q.current_track().video_id == "c"


async def test_mpris_previous_goes_back() -> None:
    q = QueueManager()
    await q.add_tracks([Track("a", "A"), Track("b", "B"), Track("c", "C")])
    await q.advance()
    await q.advance()  # current -> c
    iface = MprisPlayerInterface(NullPlayer(), q, None, None)
    iface.Previous()
    await asyncio.sleep(0.05)
    assert q.current_track().video_id == "b"


def test_mpris_metadata_has_trackid() -> None:
    player = NullPlayer()
    player._current_track = Track("v1", "Song", "Artist", duration_ms=180000)
    async def _build():
        iface = MprisPlayerInterface(player, QueueManager(), None, None)
        return iface.Metadata
    meta = _run(_build())
    assert "mpris:trackid" in meta
    assert meta["mpris:trackid"].value == "/org/sonictune/track/v1"
    assert meta["xesam:title"].value == "Song"


async def test_mpris_metadata_empty_when_no_track() -> None:
    player = NullPlayer()
    iface = MprisPlayerInterface(player, QueueManager(), None, None)
    assert iface.Metadata == {}


def test_mpris_can_control_true() -> None:
    async def _build():
        iface = MprisPlayerInterface(NullPlayer(), QueueManager(), None, None)
        return iface
    iface = __import__("asyncio").run(_build())
    assert iface.CanControl is True
    assert iface.CanPlay is True
    assert iface.CanPause is True


def _run(coro):
    import asyncio
    return asyncio.run(coro)
