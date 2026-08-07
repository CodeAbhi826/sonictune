"""libmpv wrapper via python-mpv.

python-mpv provides a Pythonic wrapper around libmpv's C API. We add:
- Async-friendly methods (run sync calls in a thread where needed)
- Event callbacks for state changes (play/pause/seek/track-end)
- Audio normalization + gapless config based on user prefs
- A clean PlayerState enum

The player does NOT own the queue — that's QueueManager's job. The player
just plays whatever URL it's given.
"""
from __future__ import annotations

import asyncio
import contextlib
import threading
import time
from collections.abc import Callable
from datetime import UTC, datetime
from typing import Any

import mpv
import structlog

from sonictune.config import AudioConfig
from sonictune.player.types import PlayerEvent, PlayerState, TrackInfo

log = structlog.get_logger()


class MpvPlayer:
    """Async wrapper around libmpv via python-mpv."""

    def __init__(self, config: AudioConfig | None = None) -> None:
        self._config = config or AudioConfig()
        self._mpv: mpv.MPV | None = None
        self._state: PlayerState = PlayerState.IDLE
        self._current_track: TrackInfo = TrackInfo()
        self._position_ms: int = 0
        self._duration_ms: int = 0
        self._volume: int = 80
        self._speed: float = 1.0
        self._crossfade_seconds: int = 0
        self._play_started_at: float | None = None
        self._listeners: list[Callable[[PlayerEvent, dict[str, Any]], Any]] = []
        self._lock = threading.Lock()
        self._position_poller: asyncio.Task | None = None

    # --- Lifecycle ---------------------------------------------------------

    async def init(self) -> None:
        """Create the mpv instance with our preferred options.

        NOTE: mpv.MPV() must be created on the main thread — the C API is not
        thread-safe for handle creation. Only blocking operations like
        terminate() go through asyncio.to_thread().
        """
        self._loop = asyncio.get_running_loop()
        log.info("mpv.init_start", loop_id=id(self._loop), loop_running=self._loop.is_running())

        # CRITICAL: libmpv requires C locale for numeric parsing.
        # app.py sets LC_ALL via ctypes.setlocale() at C level before any
        # library imports. This is a defensive measure in case any imported
        # library resets the locale since startup. We set LC_ALL (not just
        # LC_NUMERIC) because mpv checks all locale categories.
        import locale
        locale.setlocale(locale.LC_ALL, "C")
        log.debug("mpv.locale_set", lc_all=locale.setlocale(locale.LC_ALL))

        self._mpv = mpv.MPV(
            # Audio-only (we don't render video in this player)
            video=False,
            # Config-driven
            gapless_audio="yes" if self._config.gapless else "no",
            # Hardware decoding (auto-safe falls back to software if HW fails)
            hwdec="auto-safe",
            # Network
            cache=True,
            demuxer_max_bytes=50 * 1024 * 1024,  # 50 MB
            demuxer_readahead_secs=20,
            # Don't show OSC / terminal output
            osc=False,
            terminal=False,
            input_default_bindings=False,
            # Volume
            volume=self._volume,
        )

        # ReplayGain for downloaded files
        if self._config.replaygain:
            self._mpv["replaygain"] = "track"
            self._mpv["replaygain-preamp"] = 0

        # YouTube Music stream URLs only serve correctly when the request
        # carries a matching Referer; without it the CDN stalls/refuses and
        # mpv sits at 0s with no audio (no error event, just silence).
        self._mpv["referrer"] = "https://music.youtube.com/"

        # Build the audio filter chain from current settings
        self._rebuild_af_chain()

        # Register event handlers (run in mpv's thread — marshal to our loop)
        def _on_event(event: Any) -> None:
            asyncio.run_coroutine_threadsafe(self._handle_mpv_event(event), self._loop)

        self._mpv.observe_property("time-pos", lambda _name, val: self._on_position(val))
        self._mpv.observe_property("duration", lambda _name, val: self._on_duration(val))
        self._mpv.observe_property("pause", lambda _name, val: self._on_pause(val))
        self._mpv.register_event_callback(_on_event)

        log.info("player.ready", gapless=self._config.gapless,
                 normalization=self._config.normalization)

        # Start position poller (5 Hz)
        self._position_poller = asyncio.create_task(self._poll_position())

    def _rebuild_af_chain(self) -> None:
        """Rebuild the mpv `af` filter chain from current settings.
        Call this any time normalization or crossfade state changes —
        never assign self._mpv.af directly from a single feature's code path.
        """
        if not self._mpv:
            return
        filters: list[str] = []
        if self._config.normalization:
            filters.append("lavfi=[loudnorm=I=-16:TP=-1.5:LRA=11]")
        # BUGFIX: lavfi acrossfade requires two input streams; mpv has
        # one audio stream, so applying this filter breaks playback entirely.
        # Leave it disabled until a proper gapless crossfade (end-file hook
        # + volume ramp) is implemented.
        # if self._crossfade_seconds > 0:
        #     filters.append(
        #         f"lavfi=[acrossfade=d={self._crossfade_seconds}:c1=tri:c2=tri]"
        #     )
        self._mpv.af = ",".join(filters)

    async def shutdown(self) -> None:
        if self._position_poller:
            self._position_poller.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._position_poller

        if self._mpv:
            await asyncio.to_thread(self._mpv.terminate)
            self._mpv = None
        log.info("player.shutdown")

    # --- Event listeners ---------------------------------------------------

    def add_listener(
        self,
        callback: Callable[[PlayerEvent, dict[str, Any]], Any],
    ) -> None:
        """Register a listener for player events."""
        self._listeners.append(callback)

    async def _emit(self, event: PlayerEvent, data: dict[str, Any] | None = None) -> None:
        data = data or {}
        for cb in list(self._listeners):
            try:
                result = cb(event, data)
                if asyncio.iscoroutine(result):
                    await result
            except Exception:
                log.exception("player.listener_error")

    # --- mpv event handling ------------------------------------------------

    async def _handle_mpv_event(self, event: Any) -> None:
        """Handle raw mpv events (end-file, error, etc.)."""
        event_id = event.get("event_id", event.get("event-id")) if isinstance(event, dict) else None
        if event_id == mpv.MpvEventID.END_FILE:
            reason = event.get("reason", "unknown")
            log.info("player.end_file", reason=str(reason))
            await self._set_state(PlayerState.STOPPED)
            await self._emit(PlayerEvent.END_REACHED, {"video_id": self._current_track.video_id})
        elif event_id == mpv.MpvEventID.ERROR:
            err = event.get("error", "unknown")
            log.error("player.mpv_error", error=err)
            await self._set_state(PlayerState.ERROR)
            await self._emit(PlayerEvent.ERROR, {"error": err})

    def _on_position(self, val: float | None) -> None:
        if val is not None:
            new_pos = int(val * 1000)
            self._loop.call_soon_threadsafe(setattr, self, "_position_ms", new_pos)

    def _on_duration(self, val: float | None) -> None:
        if val is not None:
            new_dur = int(val * 1000)
            self._loop.call_soon_threadsafe(setattr, self, "_duration_ms", new_dur)

    def _on_pause(self, val: bool | None) -> None:
        if val is None:
            return
        new_state = PlayerState.PAUSED if val else PlayerState.PLAYING
        asyncio.run_coroutine_threadsafe(
            self._set_state(new_state), self._loop
        )

    async def _set_state(self, state: PlayerState) -> None:
        if state == self._state:
            return
        self._state = state
        await self._emit(PlayerEvent.STATE_CHANGED, {"state": state.value})

    async def _poll_position(self) -> None:
        """Emit position-changed events at 5 Hz while playing."""
        try:
            while True:
                if self._state == PlayerState.PLAYING:
                    await self._emit(
                        PlayerEvent.POSITION_CHANGED,
                        {
                            "position_ms": self._position_ms,
                            "duration_ms": self._duration_ms,
                        },
                    )
                await asyncio.sleep(0.2)
        except asyncio.CancelledError:
            pass

    # --- Transport ---------------------------------------------------------

    async def load_url(self, url: str, track: TrackInfo) -> None:
        """Load a stream URL and start playing."""
        if not self._mpv:
            raise RuntimeError("Player not initialized")
        await self._set_state(PlayerState.LOADING)
        self._current_track = track
        self._play_started_at = time.time()
        # BUGFIX: position_ms/duration_ms held the *previous* track's values
        # here. TRACK_CHANGED fires immediately below, and prefetch
        # scheduling used to read these synchronously at that moment —
        # before mpv had reported real numbers for the new track — so it
        # scheduled against stale data. Resetting both here means "no data
        # yet" is represented honestly as 0.
        self._position_ms = 0
        self._duration_ms = 0
        await self._emit(PlayerEvent.TRACK_CHANGED, {"track": track})

        def _load() -> None:
            self._mpv.play(url)  # type: ignore[union-attr]

        try:
            await asyncio.to_thread(_load)
        except Exception as e:
            # BUGFIX: a failed load (bad URL, network error, unsupported
            # stream) used to leave state stuck at LOADING forever with no
            # error surfaced beyond a log line.
            log.warning("player.load_failed", video_id=track.video_id, error=str(e))
            await self._set_state(PlayerState.ERROR)
            await self._emit(PlayerEvent.ERROR, {"error": str(e), "video_id": track.video_id})
            return

        await self._set_state(PlayerState.PLAYING)
        log.info("player.loaded", video_id=track.video_id, title=track.title)

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
        if self._mpv and self._state == PlayerState.PAUSED:
            await asyncio.to_thread(setattr, self._mpv, "pause", False)
            await self._set_state(PlayerState.PLAYING)

    async def pause(self) -> None:
        if self._mpv and self._state == PlayerState.PLAYING:
            await asyncio.to_thread(setattr, self._mpv, "pause", True)
            await self._set_state(PlayerState.PAUSED)

    async def play_pause(self) -> None:
        if self._state == PlayerState.PLAYING:
            await self.pause()
        else:
            await self.play()

    async def stop(self) -> None:
        if self._mpv:
            await asyncio.to_thread(self._mpv.command, "stop")
        await self._set_state(PlayerState.STOPPED)

    async def seek(self, position_ms: int) -> None:
        """Seek to absolute position (ms)."""
        if self._mpv:
            seconds = position_ms / 1000.0
            await asyncio.to_thread(self._mpv.command, "seek", seconds, "absolute")
            self._position_ms = position_ms
            await self._emit(
                PlayerEvent.POSITION_CHANGED,
                {"position_ms": position_ms, "duration_ms": self._duration_ms},
            )

    async def seek_relative(self, delta_ms: int) -> None:
        """Seek by delta (ms, can be negative)."""
        if self._mpv:
            await asyncio.to_thread(
                self._mpv.command, "seek", delta_ms / 1000.0, "relative"
            )

    async def set_volume(self, volume: int) -> None:
        volume = max(0, min(100, volume))
        self._volume = volume
        if self._mpv:
            await asyncio.to_thread(setattr, self._mpv, "volume", volume)
        await self._emit(PlayerEvent.VOLUME_CHANGED, {"volume": volume})

    async def set_crossfade(self, seconds: int) -> None:
        """Set crossfade length (clamped to 0-12s). 0 disables."""
        self._crossfade_seconds = max(0, min(12, seconds))
        self._rebuild_af_chain()

    async def set_speed(self, speed: float) -> None:
        """Set playback speed (clamped to 0.5x-2.0x)."""
        self._speed = max(0.5, min(2.0, speed))
        if self._mpv:
            self._mpv.speed = self._speed

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


__all__ = ["MpvPlayer", "PlayerEvent", "PlayerState", "TrackInfo"]
