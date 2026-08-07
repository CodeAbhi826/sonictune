"""Null player — stub used when libmpv is not available.

Provides the same interface as MpvPlayer but does nothing. Useful for:
- Testing the daemon without libmpv installed
- Running the daemon in "library only" mode (browse, search, stats work;
  playback doesn't)
- CI environments
"""
from __future__ import annotations

import asyncio
import time
from collections.abc import Callable
from datetime import UTC, datetime
from typing import Any

import structlog

from sonictune.player.types import PlayerEvent, PlayerState, TrackInfo

log = structlog.get_logger()


class NullPlayer:
    """Drop-in replacement for MpvPlayer when libmpv isn't available."""

    def __init__(self, config: Any = None) -> None:
        self._state: PlayerState = PlayerState.IDLE
        self._current_track: TrackInfo = TrackInfo()
        self._position_ms: int = 0
        self._duration_ms: int = 0
        self._volume: int = 80
        self._speed: float = 1.0
        self._crossfade_seconds: int = 0
        self._play_started_at: float | None = None
        self._listeners: list[Callable[[PlayerEvent, dict[str, Any]], Any]] = []

    async def init(self) -> None:
        log.warning("null_player.init")

    async def shutdown(self) -> None:
        log.info("null_player.shutdown")

    # --- Listener API ------------------------------------------------------

    def add_listener(
        self, callback: Callable[[PlayerEvent, dict[str, Any]], Any]
    ) -> None:
        self._listeners.append(callback)

    async def _emit(
        self, event: PlayerEvent, data: dict[str, Any] | None = None
    ) -> None:
        data = data or {}
        for cb in list(self._listeners):
            try:
                result = cb(event, data)
                if asyncio.iscoroutine(result):
                    await result
            except Exception:
                log.exception("null_player.listener_error")

    # --- Transport (all no-ops) --------------------------------------------

    async def load_url(self, url: str, track: TrackInfo) -> None:
        log.warning("null_player.load_ignored", url=url[:80], video_id=track.video_id)
        self._current_track = track
        self._play_started_at = time.time()
        self._position_ms = 0
        await self._set_state(PlayerState.ERROR)
        await self._emit(
            PlayerEvent.ERROR,
            {"error": "libmpv not available — install libmpv to enable playback"},
        )

    @property
    def play_started_at(self) -> float | None:
        """Epoch seconds when the current track started playing, if any."""
        return self._play_started_at

    def _iso_started_at(self) -> str | None:
        """ISO-8601 UTC string for the current play start time, if any."""
        if self._play_started_at is None:
            return None
        return datetime.fromtimestamp(self._play_started_at, tz=UTC).isoformat()

    async def play(self) -> None:
        pass

    async def pause(self) -> None:
        pass

    async def play_pause(self) -> None:
        pass

    async def stop(self) -> None:
        await self._set_state(PlayerState.STOPPED)

    async def seek(self, position_ms: int) -> None:
        self._position_ms = position_ms

    async def seek_relative(self, delta_ms: int) -> None:
        self._position_ms = max(0, self._position_ms + delta_ms)

    async def set_volume(self, volume: int) -> None:
        self._volume = max(0, min(100, volume))

    async def set_speed(self, speed: float) -> None:
        self._speed = max(0.5, min(2.0, speed))

    async def set_crossfade(self, seconds: int) -> None:
        self._crossfade_seconds = max(0, min(12, seconds))

    async def _set_state(self, state: PlayerState) -> None:
        if state == self._state:
            return
        self._state = state
        await self._emit(PlayerEvent.STATE_CHANGED, {"state": state.value})

    # --- Getters -----------------------------------------------------------

    @property
    def state(self) -> PlayerState:
        return self._state

    @property
    def current_track(self) -> TrackInfo:
        return self._current_track

    @property
    def position_ms(self) -> int:
        return self._position_ms

    @property
    def duration_ms(self) -> int:
        return self._duration_ms

    @property
    def volume(self) -> int:
        return self._volume

    def get_status(self) -> dict[str, Any]:
        return {
            "state": self._state.value,
            "position_ms": self._position_ms,
            "duration_ms": self._duration_ms,
            "volume": self._volume,
            "track": {
                "video_id": self._current_track.video_id,
                "title": self._current_track.title,
                "artist": self._current_track.artist,
                "album": self._current_track.album,
                "thumbnail_url": self._current_track.thumbnail_url,
            },
        }


__all__ = ["NullPlayer"]
