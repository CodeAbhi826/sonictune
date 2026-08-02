"""MPRIS v2 server — exposes org.mpris.MediaPlayer2.* on the session bus.

Lets KDE Plasma's media controller, GNOME shell, lockscreen, hardware
media keys, etc. control SonicTune.

Per the MPRIS v2 spec, org.mpris.MediaPlayer2 and org.mpris.MediaPlayer2.Player
MUST be separate ServiceInterface subclasses. Both are exported at the same
object path (/org/mpris/MediaPlayer2).
"""
from __future__ import annotations

import asyncio
from typing import Any

import structlog
from dbus_next import Variant
from dbus_next.aio import MessageBus
from dbus_next.service import PropertyAccess, ServiceInterface, dbus_property, method, signal

from sonictune.config import DaemonConfig
from sonictune.library.models import Track
from sonictune.library.ytmusic import YTMusicLibrary
from sonictune.player.queue import QueueManager, RepeatMode
from sonictune.player.types import PlayerEvent, PlayerState

log = structlog.get_logger()

MPRIS_BASE_PATH = "/org/mpris/MediaPlayer2"


def _metadata_from_track(track: Any) -> dict[str, Variant]:
    """Build MPRIS metadata dict from a track object."""
    length = getattr(track, "duration_ms", 0) * 1000
    return {
        "mpris:trackid": Variant("o", f"/org/sonictune/track/{track.video_id}"),
        "mpris:length": Variant("x", length),
        "xesam:title": Variant("s", track.title),
        "xesam:artist": Variant("as", [track.artist] if track.artist else []),
        "xesam:album": Variant("s", track.album or ""),
        "xesam:url": Variant("s", ""),
        "xesam:trackNumber": Variant("i", 0),
    }


class MprisRootInterface(ServiceInterface):
    """org.mpris.MediaPlayer2 — root interface (Identity, Raise, etc.)."""

    def __init__(
        self,
        player: Any,
        queue: QueueManager,
        library: YTMusicLibrary,
        config: DaemonConfig | None = None,
    ) -> None:
        super().__init__("org.mpris.MediaPlayer2")
        self._player = player
        self._queue = queue
        self._library = library
        self._config = config

    # --- Properties ---------------------------------------------------------

    @dbus_property(access=PropertyAccess.READ)
    def Identity(self) -> s:
        return "SonicTune"

    @dbus_property(access=PropertyAccess.READ)
    def DesktopEntry(self) -> s:
        return "org.sonicTune"

    @dbus_property(access=PropertyAccess.READ)
    def SupportedUriSchemes(self) -> "as":
        return ["youtube", "ytmusic", "file", "http", "https"]

    @dbus_property(access=PropertyAccess.READ)
    def SupportedMimeTypes(self) -> "as":
        return [
            "audio/aac", "audio/m4a", "audio/webm",
            "audio/ogg", "audio/flac", "audio/mp3",
        ]

    @dbus_property(access=PropertyAccess.READ)
    def CanRaise(self) -> b:
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanQuit(self) -> b:
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanSetFullscreen(self) -> b:
        return False

    @dbus_property()
    def Fullscreen(self) -> b:
        return False

    @Fullscreen.setter
    def Fullscreen(self, value: bool) -> None:
        pass

    # --- Methods ------------------------------------------------------------

    @method()
    def Raise(self):
        log.info("mpris.raise_requested")

    @method()
    def Quit(self):
        log.info("mpris.quit_requested")


class MprisPlayerInterface(ServiceInterface):
    """org.mpris.MediaPlayer2.Player — playback control."""

    def __init__(
        self,
        player: Any,
        queue: QueueManager,
        library: YTMusicLibrary,
        config: DaemonConfig | None = None,
    ) -> None:
        super().__init__("org.mpris.MediaPlayer2.Player")
        self._player = player
        self._queue = queue
        self._library = library
        self._config = config
        self._loop = asyncio.get_running_loop()
        self._last_seeked_pos: int = 0

        player.add_listener(self._on_player_event)

    # --- Event handler ------------------------------------------------------

    def _on_player_event(self, event: Any, data: dict[str, Any]) -> None:
        """Listen to player events and emit MPRIS property changes."""
        if event == PlayerEvent.STATE_CHANGED:
            self.emit_properties_changed({
                "PlaybackStatus": self.PlaybackStatus,
            })
        elif event == PlayerEvent.TRACK_CHANGED:
            self.emit_properties_changed({
                "Metadata": self.Metadata,
                "PlaybackStatus": self.PlaybackStatus,
            })
        elif event == PlayerEvent.POSITION_CHANGED:
            pos = int(data.get("position_ms", 0))
            if abs(pos - self._last_seeked_pos) > 500:
                self._last_seeked_pos = pos
                self.Seeked(pos * 1000)
        elif event == PlayerEvent.VOLUME_CHANGED:
            self.emit_properties_changed({
                "Volume": self.Volume,
            })

    @signal()
    def Seeked(self, position: x):
        pass

    # --- Properties ---------------------------------------------------------

    @dbus_property(access=PropertyAccess.READ)
    def PlaybackStatus(self) -> s:
        return {
            PlayerState.PLAYING: "Playing",
            PlayerState.PAUSED: "Paused",
            PlayerState.LOADING: "Paused",
            PlayerState.STOPPED: "Stopped",
            PlayerState.IDLE: "Stopped",
            PlayerState.ERROR: "Stopped",
        }.get(self._player.state, "Stopped")

    @dbus_property()
    def LoopStatus(self) -> s:
        return {
            RepeatMode.OFF: "None",
            RepeatMode.ALL: "Playlist",
            RepeatMode.ONE: "Track",
        }.get(self._queue.repeat, "None")

    @LoopStatus.setter
    def LoopStatus(self, value: str) -> None:
        mode = {"None": RepeatMode.OFF, "Playlist": RepeatMode.ALL, "Track": RepeatMode.ONE}.get(value, RepeatMode.OFF)
        asyncio.create_task(self._queue.set_repeat(mode))

    @dbus_property()
    def Rate(self) -> d:
        return 1.0

    @Rate.setter
    def Rate(self, value: float) -> None:
        pass

    @dbus_property()
    def Shuffle(self) -> b:
        return self._queue.shuffle

    @Shuffle.setter
    def Shuffle(self, value: bool) -> None:
        asyncio.create_task(self._queue.set_shuffle(value))

    @dbus_property()
    def Volume(self) -> d:
        return self._player.volume / 100.0

    @Volume.setter
    def Volume(self, value: float) -> None:
        asyncio.ensure_future(self._player.set_volume(int(value * 100)))

    @dbus_property(access=PropertyAccess.READ)
    def Position(self) -> x:
        return self._player.position_ms * 1000

    @dbus_property(access=PropertyAccess.READ)
    def Metadata(self) -> "a{sv}":
        track = self._player.current_track
        if not track or not track.video_id:
            return {}
        return _metadata_from_track(track)

    @dbus_property(access=PropertyAccess.READ)
    def MinimumRate(self) -> d:
        return 1.0

    @dbus_property(access=PropertyAccess.READ)
    def MaximumRate(self) -> d:
        return 1.0

    @dbus_property(access=PropertyAccess.READ)
    async def CanGoNext(self) -> b:
        return await self._queue.can_go_next()

    @dbus_property(access=PropertyAccess.READ)
    async def CanGoPrevious(self) -> b:
        return await self._queue.can_go_previous()

    @dbus_property(access=PropertyAccess.READ)
    def CanPlay(self) -> b:
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanPause(self) -> b:
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanSeek(self) -> b:
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanControl(self) -> b:
        return True

    # --- Methods ------------------------------------------------------------

    @method()
    def Next(self):
        async def _do():
            next_track = await self._queue.advance()
            if next_track:
                await self._play_track(next_track)
        asyncio.create_task(_do())

    @method()
    def Previous(self):
        async def _do():
            prev_track = await self._queue.go_back()
            if prev_track:
                await self._play_track(prev_track)
        asyncio.create_task(_do())

    @method()
    def Pause(self):
        asyncio.ensure_future(self._player.pause())

    @method()
    def PlayPause(self):
        asyncio.ensure_future(self._player.play_pause())

    @method()
    def Stop(self):
        asyncio.ensure_future(self._player.stop())

    @method()
    def Play(self):
        asyncio.ensure_future(self._player.play())

    @method()
    def Seek(self, offset: x):
        asyncio.ensure_future(self._player.seek_relative(offset // 1000))

    @method()
    def SetPosition(self, track_id: o, position: x):
        asyncio.ensure_future(self._player.seek(position // 1000))

    @method()
    def OpenUri(self, uri: s):
        log.info("mpris.open_uri", uri=uri)

    # --- Internal helpers ---------------------------------------------------

    async def _play_track(self, track: Track) -> None:
        """Helper to resolve URL and load into player."""
        try:
            from sonictune.player.types import TrackInfo
            itag = self._config.audio.itag if self._config else 141
            url = await self._library.get_stream_url(track.video_id, itag)

            info = TrackInfo(
                video_id=track.video_id,
                title=track.title,
                artist=track.artist,
                album=track.album,
                duration_ms=track.duration_ms,
                thumbnail_url=track.thumbnail_url,
            )
            await self._player.load_url(url, info)
        except Exception:
            log.exception("mpris.play_track_failed")


class MprisServer:
    """Owns the MPRIS D-Bus name and exports both interfaces."""

    def __init__(
        self,
        player: Any,
        queue: QueueManager,
        library: YTMusicLibrary,
        config: DaemonConfig | None = None,
        instance_name: str = "sonictune",
    ) -> None:
        self._player = player
        self._queue = queue
        self._library = library
        self._config = config
        self._instance = instance_name
        self._bus: MessageBus | None = None
        self._root_iface: MprisRootInterface | None = None
        self._player_iface: MprisPlayerInterface | None = None

    async def register(self) -> None:
        self._bus = await MessageBus().connect()
        self._root_iface = MprisRootInterface(self._player, self._queue, self._library, self._config)
        self._player_iface = MprisPlayerInterface(self._player, self._queue, self._library, self._config)
        self._bus.export(MPRIS_BASE_PATH, self._root_iface)
        self._bus.export(MPRIS_BASE_PATH, self._player_iface)
        await self._bus.request_name(f"org.mpris.MediaPlayer2.{self._instance}")
        log.info("mpris.registered", name=f"org.mpris.MediaPlayer2.{self._instance}")

    async def unregister(self) -> None:
        log.info("mpris.unregistering")


__all__ = ["MprisPlayerInterface", "MprisRootInterface", "MprisServer"]
