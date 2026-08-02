"""Tests for sonictune.player (categories D — Player).
"""
from __future__ import annotations

from sonictune.player.queue import RepeatMode
from sonictune.player.types import PlayerEvent, PlayerState

# ---- NullPlayer ---------------------------------------------------------------


def test_null_player_initial_state(null_player) -> None:
    assert null_player.state == PlayerState.IDLE
    assert null_player.current_track.video_id == ""
    assert null_player.volume == 80


async def test_null_player_load_url_emits_error(null_player) -> None:
    errors: list[dict] = []

    async def _listener(event: PlayerEvent, data: dict) -> None:
        if event == PlayerEvent.ERROR:
            errors.append(data)

    null_player.add_listener(_listener)
    await null_player.load_url("https://example.com/stream", null_player.current_track)
    assert null_player.state == PlayerState.ERROR
    assert errors and "libmpv not available" in errors[0]["error"]


async def test_null_player_set_volume_clamps(null_player) -> None:
    await null_player.set_volume(150)
    assert null_player.volume == 100
    await null_player.set_volume(-10)
    assert null_player.volume == 0


async def test_null_player_seek_relative(null_player) -> None:
    await null_player.seek(1000)
    await null_player.seek_relative(-500)
    assert null_player.position_ms == 500


async def test_null_player_stop_sets_stopped(null_player) -> None:
    await null_player.stop()
    assert null_player.state == PlayerState.STOPPED


def test_player_state_values() -> None:
    assert PlayerState.IDLE.value == "idle"
    assert PlayerState.PLAYING.value == "playing"
    assert PlayerState.PAUSED.value == "paused"


def test_repeat_mode_values() -> None:
    assert RepeatMode.OFF.value == "off"
    assert RepeatMode.ALL.value == "all"
    assert RepeatMode.ONE.value == "one"
