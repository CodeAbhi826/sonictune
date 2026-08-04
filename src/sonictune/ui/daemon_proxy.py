"""Direct Python proxy for QML — replaces the D-Bus client.

Same API as the old DaemonClient, but calls services directly.
No D-Bus, no Variant wrapping, no async bridges.
"""
from __future__ import annotations

import asyncio
import json
from typing import Any

import structlog
from PySide6.QtCore import QObject, Signal, Slot

from sonictune.config import QUALITY_ITAG_MAP, resolve_high_quality
from sonictune.library.models import Track
from sonictune.player.queue import RepeatMode
from sonictune.player.types import PlayerEvent, TrackInfo

log = structlog.get_logger()


class DaemonProxy(QObject):
    """Direct Python proxy — QML calls this, it calls services directly."""

    connectionChanged = Signal(bool)

    # Local library signals
    localTracksReceived = Signal(list)
    localTracksError = Signal(str)
    localScanProgress = Signal(str, int, int)
    localScanCompleted = Signal()

    # Player signals
    stateChanged = Signal(str)
    positionChanged = Signal(int, int)
    trackChanged = Signal(dict)
    queueChanged = Signal(list)
    authChanged = Signal(bool)
    errorOccurred = Signal(str)
    error = errorOccurred
    audioQualityChanged = Signal(str)
    currentAudioItagChanged = Signal(int)

    # API response signals
    statusReceived = Signal(dict)
    queueReceived = Signal(list)
    searchCompleted = Signal(list)
    searchError = Signal(str)
    searchSongsCompleted = Signal(list)
    librarySongsReceived = Signal(list)
    libraryAlbumsReceived = Signal(list)
    libraryPlaylistsReceived = Signal(list)
    startOAuthCompleted = Signal(str)
    pollOAuthCompleted = Signal(str)
    importCookiesCompleted = Signal(bool)
    statsReceived = Signal(dict)
    syncLibraryCompleted = Signal()
    searchHistoryReceived = Signal(list)
    lyricsReceived = Signal(dict)
    homeReceived = Signal(list)

    def __init__(
        self,
        player: Any,
        queue: Any,
        library: Any,
        oauth: Any,
        lyrics: Any,
        stats: Any,
        art_cache: Any,
        audio_cache: Any,
        db: Any,
        sync: Any,
        config: Any,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._player = player
        self._queue = queue
        self._library = library
        self._oauth = oauth
        self._lyrics = lyrics
        self._stats = stats
        self._art_cache = art_cache
        self._audio_cache = audio_cache
        self._db = db
        self._sync = sync
        self._config = config
        self._connected = True  # always true — we're in the same process
        self._url_cache: dict[str, str] = {}
        self._prefetch_task: asyncio.Task | None = None
        self._prefetch_scheduled_for: str | None = None
        self._ytm: Any = getattr(library, "_ytm", None)
        self._current_itag: int = 0
        self._local_scanner = None

        # Initialize local scanner if available
        try:
            from sonictune.library.local_scanner import LocalScanner
            self._local_scanner = LocalScanner()
        except ImportError as e:
            log.warning("local_scanner_init_failed", error=str(e))
        except Exception as e:
            log.warning("local_scanner_init_failed", error=str(e))

        # Wire player events to signals
        self._player.add_listener(self._on_player_event)

        # Emit connectionChanged (always True now)
        self.connectionChanged.emit(True)

    @property
    def connected(self) -> bool:
        return True  # always connected in unified mode

    @Slot(result=bool)
    def isConnected(self) -> bool:
        return True  # always connected in unified mode (single process)

    def _on_player_event(self, event: PlayerEvent, data: dict[str, Any]) -> None:
        """Forward player events as Qt signals."""
        if event == PlayerEvent.STATE_CHANGED:
            self.stateChanged.emit(data.get("state", "unknown"))
        elif event == PlayerEvent.POSITION_CHANGED:
            self.positionChanged.emit(
                int(data.get("position_ms", 0)),
                int(data.get("duration_ms", 0)),
            )
            # BUGFIX: prefetch used to be scheduled once, synchronously, on
            # TRACK_CHANGED — but at that exact moment the player hasn't
            # reported the *new* track's duration/position yet (mpv updates
            # those asynchronously once it loads metadata), so the "80%
            # through" calculation was computed against the *previous*
            # track's numbers. POSITION_CHANGED events carry live,
            # already-current data for the track that's actually playing,
            # so we schedule from here instead, once per track.
            self._maybe_schedule_prefetch(data)
        elif event == PlayerEvent.TRACK_CHANGED:
            track = data.get("track")
            if track:
                self.trackChanged.emit(self._track_to_dict(track))
                self._prefetch_scheduled_for = None
                if self._prefetch_task and not self._prefetch_task.done():
                    self._prefetch_task.cancel()
        elif event == PlayerEvent.END_REACHED:
            # Auto-advance + stats recording
            asyncio.create_task(self._on_end_reached(data))
        elif event == PlayerEvent.ERROR:
            self.errorOccurred.emit(str(data.get("error", "Playback error")))

    async def _on_end_reached(self, data: dict[str, Any]) -> None:
        """Handle end-of-track: advance queue, record stats, play next."""
        video_id = data.get("video_id", "")
        status = self._player.get_status()
        position_ms = int(status.get("position_ms", 0))
        duration_ms = int(status.get("duration_ms", 0))
        completion_pct = min(position_ms / max(duration_ms, 1) * 100, 100.0)

        if video_id:
            await self._stats.record_play(
                video_id,
                position_ms,
                completion_pct,
                started_at=self._player._iso_started_at(),
            )

        next_track = await self._queue.advance()
        if next_track:
            await self._play_track(next_track)

    def _track_to_dict(self, track: Any) -> dict[str, Any]:
        """Convert a Track/TrackInfo to a plain dict for QML."""
        return {
            "video_id": track.video_id,
            "title": track.title,
            "artist": getattr(track, "artist", ""),
            "album": getattr(track, "album", ""),
            "duration_ms": getattr(track, "duration_ms", 0),
            "thumbnail_url": getattr(track, "thumbnail_url", ""),
        }

    # === Player transport ===

    @Slot()
    def play(self) -> None:
        asyncio.create_task(self._player.play())

    @Slot()
    def pause(self) -> None:
        asyncio.create_task(self._player.pause())

    @Slot()
    def playPause(self) -> None:
        asyncio.create_task(self._player.play_pause())

    @Slot()
    def stop(self) -> None:
        asyncio.create_task(self._player.stop())

    @Slot()
    def next(self) -> None:
        async def _do():
            next_track = await self._queue.advance()
            if next_track:
                await self._play_track(next_track)
        asyncio.create_task(_do())

    @Slot()
    def previous(self) -> None:
        async def _do():
            prev_track = await self._queue.go_back()
            if prev_track:
                await self._play_track(prev_track)
        asyncio.create_task(_do())

    @Slot(int)
    def seek(self, position_ms: int) -> None:
        asyncio.create_task(self._player.seek(position_ms))

    @Slot(int)
    def seekRelative(self, delta_ms: int) -> None:
        asyncio.create_task(self._player.seek_relative(delta_ms))

    @Slot(int)
    def setVolume(self, volume: int) -> None:
        asyncio.create_task(self._player.set_volume(volume))

    @Slot()
    def getStatus(self) -> None:
        status = dict(self._player.get_status())
        # BUGFIX: shuffle/repeat live on the queue, not the player, so
        # get_status() never included them — any QML binding to
        # status.shuffle/status.repeat would silently be undefined forever.
        queue_status = self._queue.get_status()
        status["shuffle"] = queue_status.get("shuffle", False)
        status["repeat"] = queue_status.get("repeat", "off")
        self.statusReceived.emit(status)

    @Slot(str)
    def playTrack(self, video_id: str) -> None:
        async def _do():
            try:
                track = await self._library.get_track(video_id)
                await self._queue.clear()
                await self._queue.add_track(track)
                await self._play_track(track)
            except Exception as e:
                self.errorOccurred.emit(str(e))
        asyncio.create_task(_do())

    # === Audio quality ===

    @Slot(result=str)
    def audioQuality(self) -> str:
        """Current audio quality level: 'low' | 'standard' | 'high'."""
        return getattr(self._config.audio, "quality", "standard")

    @Slot(str)
    def setAudioQuality(self, quality: str) -> None:
        """Set audio quality (only the 3 spec levels are accepted)."""
        if quality not in QUALITY_ITAG_MAP:
            return
        self._config.audio.quality = quality
        self._config.audio.itag = QUALITY_ITAG_MAP[quality]
        if hasattr(self._config, "save"):
            try:
                self._config.save()
            except Exception as e:
                log.warning("config.save_failed", error=str(e))
        self.audioQualityChanged.emit(quality)

    @Slot(result=int)
    def currentAudioItag(self) -> int:
        """Last resolved itag for 'high' quality (0 if unset)."""
        return self._current_itag

    # === Crossfade + playback speed ===

    @Slot(int)
    def setCrossfade(self, seconds: int) -> None:
        asyncio.create_task(self._player.set_crossfade(seconds))

    @Slot(result=int)
    def crossfade(self) -> int:
        return getattr(self._config.audio, "crossfade_seconds", 0)

    @Slot(float)
    def setSpeed(self, speed: float) -> None:
        asyncio.create_task(self._player.set_speed(speed))

    @Slot(result=float)
    def speed(self) -> float:
        return getattr(self._config.audio, "speed", 1.0)

    @Slot(str, bool)
    def addToQueue(self, video_id: str, play_next: bool) -> None:
        async def _do():
            try:
                track = await self._library.get_track(video_id)
                await self._queue.add_track(track, at_end=not play_next)
                self.queueChanged.emit(self._queue.get_status())
            except Exception as e:
                self.errorOccurred.emit(str(e))
        asyncio.create_task(_do())

    @Slot(int)
    def removeFromQueue(self, index: int) -> None:
        asyncio.create_task(self._queue.remove_at(index))
        self.queueChanged.emit(self._queue.get_status())

    @Slot()
    def clearQueue(self) -> None:
        asyncio.create_task(self._queue.clear())
        self.queueChanged.emit(self._queue.get_status())

    @Slot(int)
    def jumpTo(self, index: int) -> None:
        async def _do():
            track = await self._queue.jump_to(index)
            if track:
                await self._play_track(track)
        asyncio.create_task(_do())

    @Slot(bool)
    def setShuffle(self, enabled: bool) -> None:
        asyncio.create_task(self._queue.set_shuffle(enabled))
        self.queueChanged.emit(self._queue.get_status())

    @Slot(str)
    def setRepeat(self, mode: str) -> None:
        asyncio.create_task(self._queue.set_repeat(RepeatMode(mode)))
        self.queueChanged.emit(self._queue.get_status())

    @Slot()
    def getQueue(self) -> None:
        self.queueReceived.emit(self._queue.get_status())

    # === Library ===

    @Slot(str, str, int, result=list)
    def search(self, query: str, filter_: str = "", limit: int = 20) -> list[dict]:
        """Search YT Music with an error boundary.

        Returns the normalized result list synchronously (empty on failure —
        never raises). Also emits ``searchCompleted`` so the async UI path
        keeps working. When the raw ytmusicapi client is unavailable, falls
        back to the async library wrapper.
        """
        try:
            if self._ytm is not None:
                results = self._ytm.search(query, filter=filter_ or None, limit=limit or 20)
                normalized = [self._normalize_search_item(r) for r in results]
                self.searchCompleted.emit(normalized)
                return normalized
        except Exception as e:
            log.warning("proxy.search_error", error=str(e))
            self.errorOccurred.emit(f"Search failed: {e!s}")
            self.searchError.emit(str(e))
            return []

        async def _do():
            try:
                results = await self._library.search(query, filter_=filter_ or None, limit=limit or 20)
                self.searchCompleted.emit([self._normalize_search_item(r) for r in results])
            except Exception as e:
                self.searchError.emit(str(e))
                self.errorOccurred.emit(f"Search failed: {e!s}")
        asyncio.create_task(_do())
        return []

    @staticmethod
    def _get(raw: Any, key: str, default: Any = "") -> Any:
        if isinstance(raw, dict):
            return raw.get(key, default)
        return getattr(raw, key, default)

    def _normalize_search_item(self, raw: Any) -> dict[str, Any]:
        """Convert a raw ytmusicapi search hit (camelCase) into the snake_case
        shape the QML components expect (same as _normalize_home)."""
        thumbnails = self._get(raw, "thumbnails") or []
        thumb = thumbnails[-1].get("url", "") if thumbnails else ""
        artists = self._get(raw, "artists") or []
        artist_name = ", ".join(a.get("name", "") for a in artists if a.get("name"))
        album = self._get(raw, "album")
        album_name = album.get("name", "") if isinstance(album, dict) else (album or "")
        result_type = self._get(raw, "resultType", "song") or "song"
        item: dict[str, Any] = {
            "resultType": result_type,
            "title": self._get(raw, "title") or self._get(raw, "name") or "",
            "video_id": self._get(raw, "videoId") or self._get(raw, "video_id") or "",
            "browse_id": self._get(raw, "browseId") or self._get(raw, "playlistId")
            or self._get(raw, "channelId") or self._get(raw, "browse_id") or "",
            "artist": artist_name or self._get(raw, "artist"),
            "album": album_name,
            "author": self._get(raw, "author"),
            "thumbnail_url": thumb,
            "duration_ms": int(self._get(raw, "duration_seconds", 0)) * 1000
            or int(self._get(raw, "duration_ms", 0)),
            "year": self._get(raw, "year", ""),
            "item_count": self._get(raw, "itemCount", ""),
        }
        if result_type == "artist":
            item["name"] = self._get(raw, "artist") or self._get(raw, "title") or ""
        return item

    @Slot(str, int)
    def searchSongs(self, query: str, limit: int) -> None:
        async def _do():
            try:
                tracks = await self._library.search_songs(query, limit=limit or 20)
                self.searchSongsCompleted.emit([self._track_to_dict(t) for t in tracks])
            except Exception as e:
                self.searchSongsError.emit(str(e))
        asyncio.create_task(_do())

    @Slot()
    def getHome(self) -> None:
        async def _do():
            try:
                home = await self._library.get_home()
                self.homeReceived.emit(self._normalize_home(home))
            except Exception as e:
                log.warning("proxy.home_error", error=str(e))
                self.homeError.emit(str(e))
        asyncio.create_task(_do())

    def _normalize_home(self, raw: list) -> list:
        """Convert ytmusicapi get_home rows into QML-friendly sections.

        Each row: { title, contents: [track/album/artist/playlist dicts] }.
        Emits [{ title, items: [{ title, subtitle, thumbnail_url,
        browse_id, video_id }] }].
        """
        sections = []
        for row in raw or []:
            items = []
            for entry in row.get("contents", []) or []:
                thumbnails = entry.get("thumbnails") or []
                thumb = ""
                if thumbnails:
                    thumb = thumbnails[-1].get("url", "")
                artists = entry.get("artists") or []
                subtitle = ""
                if artists:
                    subtitle = ", ".join(a.get("name", "") for a in artists)
                else:
                    subtitle = entry.get("year", "") if isinstance(entry.get("year"), str) else ""
                items.append({
                    "title": entry.get("title") or entry.get("name") or "",
                    "subtitle": subtitle,
                    "thumbnail_url": thumb,
                    "browse_id": entry.get("browseId") or entry.get("playlistId") or "",
                    "video_id": entry.get("videoId") or "",
                })
            if items:
                sections.append({"title": row.get("title", ""), "items": items})
        return sections

    @Slot()
    def getLibrarySongs(self) -> None:
        async def _do():
            try:
                tracks = await self._library.get_library_songs(limit=100)
                self.librarySongsReceived.emit([self._track_to_dict(t) for t in tracks])
            except Exception as e:
                self.librarySongsError.emit(str(e))
        asyncio.create_task(_do())

    @Slot()
    def getLibraryAlbums(self) -> None:
        async def _do():
            try:
                albums = await self._library.get_library_albums(limit=50)
                self.libraryAlbumsReceived.emit([self._album_to_dict(a) for a in albums])
            except Exception as e:
                self.libraryAlbumsError.emit(str(e))
        asyncio.create_task(_do())

    @Slot()
    def getLibraryPlaylists(self) -> None:
        async def _do():
            try:
                playlists = await self._library.get_library_playlists(limit=50)
                self.libraryPlaylistsReceived.emit([self._playlist_to_dict(p) for p in playlists])
            except Exception as e:
                self.libraryPlaylistsError.emit(str(e))
        asyncio.create_task(_do())

    @Slot(str)
    def getPlaylistTracks(self, playlist_id: str) -> None:
        async def _do():
            try:
                playlist = await self._library.get_playlist(playlist_id, limit=200)
                tracks = playlist.get("tracks", [])
                self.playlistTracksReceived.emit(
                    playlist_id,
                    [self._track_to_dict(Track.from_ytmusic(t)) for t in tracks],
                )
            except Exception as e:
                self.playlistTracksError.emit(playlist_id, str(e))
        asyncio.create_task(_do())

    def _album_to_dict(self, a: Any) -> dict[str, Any]:
        return {
            "browse_id": a.browse_id,
            "title": a.title,
            "artist": a.artist,
            "year": str(a.year),
            "thumbnail_url": a.thumbnail_url,
            "track_count": str(a.track_count),
        }

    def _playlist_to_dict(self, p: Any) -> dict[str, Any]:
        return {
            "playlist_id": p.playlist_id,
            "title": p.title,
            "description": p.description,
            "thumbnail_url": p.thumbnail_url,
            "track_count": str(p.track_count),
            "owner": p.owner,
        }

    # === Auth ===

    @Slot(result=bool)
    def isAuthenticated(self) -> bool:
        # BUGFIX: self._oauth.is_authenticated only reflects whether an
        # OAuth token is on file — a user who signed in via cookie import
        # would be reported as "not authenticated" forever. library tracks
        # what the client was actually built with (OAuth or cookies).
        return self._library.is_authenticated

    @Slot(str, str)
    def startOAuth(self, client_id: str, client_secret: str) -> None:
        async def _do():
            try:
                session = await self._oauth.start_oauth(client_id, client_secret)
                self.startOAuthCompleted.emit({
                    "user_code": session.user_code,
                    "verification_url": session.verification_url,
                    "device_code": session.device_code,
                    "expires_in": str(session.expires_in),
                    "interval": str(session.interval),
                })
            except Exception as e:
                self.startOAuthError.emit(str(e))
        asyncio.create_task(_do())

    @Slot()
    def pollOAuth(self) -> None:
        async def _do():
            try:
                success = await self._oauth.poll_oauth()
                self.pollOAuthCompleted.emit(success)
                if success:
                    await self._library.init()  # re-init with new token
                    self.authChanged.emit(self._library.is_authenticated)
            except Exception as e:
                self.pollOAuthError.emit(str(e))
        asyncio.create_task(_do())

    @Slot()
    def logout(self) -> None:
        async def _do():
            await self._oauth.logout()
            await self._library.init()
            self.authChanged.emit(False)
        asyncio.create_task(_do())

    @Slot(str, result=bool)
    def importCookies(self, source_path: str) -> bool:
        from sonictune.auth.cookies import import_browser_cookies
        success = import_browser_cookies(source_path, self._config.cookies_path)
        if success:
            async def _reinit():
                await self._library.init()
                # BUGFIX: was `self._oauth.is_authenticated`, which is
                # always False for a cookie-only login — the UI would show
                # "signed in" for a split second then flip back.
                self.authChanged.emit(self._library.is_authenticated)
            asyncio.create_task(_reinit())
        return success

    # === Stats ===

    @Slot()
    def getStats(self) -> None:
        async def _do():
            try:
                s = await self._stats.get_stats()
                self.statsReceived.emit({
                    "total_plays": str(s.total_plays),
                    "total_listen_ms": str(s.total_listen_ms),
                    "unique_tracks": str(s.unique_tracks),
                    "unique_artists": str(s.unique_artists),
                    "top_tracks_json": json.dumps(s.top_tracks or []),
                    "top_artists_json": json.dumps(s.top_artists or []),
                    "listening_by_hour_json": json.dumps(s.listening_by_hour or []),
                    "listening_by_day_json": json.dumps(s.listening_by_day or []),
                    "last_30_days_json": json.dumps(s.last_30_days or []),
                })
            except Exception as e:
                self.statsError.emit(str(e))
        asyncio.create_task(_do())

    # === Report history ===

    @Slot(result=bool)
    def reportHistory(self) -> bool:
        return self._config.ui.report_history

    @Slot(bool)
    def setReportHistory(self, value: bool) -> None:
        self._config.ui.report_history = value
        self._persist_config()

    # === Search history ===

    @Slot(str, int)
    def recordSearch(self, query: str, result_count: int) -> None:
        asyncio.create_task(self._db.record_search(query, result_count))

    @Slot(result=list)
    def getSearchHistory(self) -> None:
        async def _do():
            try:
                history = await self._db.get_search_history(limit=10)
                self.searchHistoryReceived.emit(history)
            except Exception as e:
                self.searchHistoryError.emit(str(e))
        asyncio.create_task(_do())

    # === Library sync ===

    @Slot()
    def syncLibrary(self) -> None:
        async def _do():
            try:
                summary = await self._sync.sync_all()
                self.syncLibraryCompleted.emit({
                    "songs": str(summary["songs"]),
                    "albums": str(summary["albums"]),
                    "artists": str(summary["artists"]),
                    "playlists": str(summary["playlists"]),
                })
            except Exception as e:
                self.syncLibraryError.emit(str(e))
        asyncio.create_task(_do())

    # === Lyrics ===

    @Slot(str, str, str, int)
    def getLyrics(self, track: str, artist: str, album: str, duration_ms: int) -> None:
        async def _do():
            try:
                lines = await self._lyrics.get_synced(
                    track_name=track,
                    artist_name=artist,
                    album_name=album or None,
                    duration_ms=duration_ms or None,
                )
                self.lyricsReceived.emit([
                    {"time_ms": line.time_ms, "text": line.text}
                    for line in lines
                ])
            except Exception as e:
                self.lyricsError.emit(str(e))
        asyncio.create_task(_do())

    # === Cache ===

    @Slot()
    def getAudioCacheSize(self) -> None:
        async def _do():
            try:
                size = await self._audio_cache.get_size_bytes()
                self.audioCacheSizeReceived.emit(float(size))
            except Exception as e:
                self.audioCacheSizeError.emit(str(e))
        asyncio.create_task(_do())

    @Slot()
    def clearAudioCache(self) -> None:
        async def _do():
            try:
                await self._audio_cache.clear()
                self.audioCacheCleared.emit()
            except Exception as e:
                self.audioCacheSizeError.emit(str(e))
        asyncio.create_task(_do())

    # === Local Library ===

    @Slot(str)
    def scanLocalLibrary(self, path: str) -> None:
        """Scan a local directory for audio files."""
        if not self._local_scanner:
            self.localTracksError.emit("Local scanner not available")
            return

        async def _do():
            try:
                # Notify UI that scanning is starting
                self.localScanProgress.emit(path, 0, 0)

                # Scan the directory
                tracks = await self._local_scanner.scan_directory(path)
                
                # Convert tracks to QML-friendly format
                qml_tracks = []
                for track in tracks:
                    qml_tracks.append({
                        "id": track.get("id", ""),
                        "title": track.get("title", ""),
                        "artist": track.get("artist", "Unknown Artist"),
                        "album": track.get("album", "Unknown Album"),
                        "duration_ms": track.get("duration_ms", 0),
                        "thumbnail_url": "",  # Local tracks don't have thumbnails initially
                        "path": track.get("path", ""),
                        "uri": track.get("uri", ""),
                        "is_local": True,
                        "track_number": track.get("track_number", 0),
                        "disc_number": track.get("disc_number", 0),
                        "genre": track.get("genre", ""),
                        "year": track.get("year", 0),
                    })
                
                self.localTracksReceived.emit(qml_tracks)
                self.localScanCompleted.emit()
            except Exception as e:
                self.localTracksError.emit(str(e))

        asyncio.create_task(_do())

    @Slot(str, result=bool)
    def playLocalTrack(self, track_id: str) -> bool:
        """Play a local track by ID."""
        # TODO: Implement local track playback
        self.errorOccurred.emit("Local track playback not yet implemented")
        return False

    @Slot(str, bool, result=bool)
    def addLocalTrackToQueue(self, track_id: str, play_next: bool) -> bool:
        """Add a local track to the queue."""
        # TODO: Implement local track queueing
        self.errorOccurred.emit("Local track queueing not yet implemented")
        return False

    def _persist_config(self) -> None:
        """Write current config back to disk as TOML."""
        import re

        config_dir = getattr(self._config, "config_dir", None)
        if config_dir is None:
            return
        path = config_dir / "config.toml"
        if not path.exists():
            return
        try:
            text = path.read_text()
        except OSError:
            return
        value = "true" if self._config.ui.report_history else "false"
        line = f"report_history = {value}"
        if re.search(r"^report_history\s*=", text, flags=re.MULTILINE):
            text = re.sub(
                r"^report_history\s*=.*$",
                line,
                text,
                flags=re.MULTILINE,
            )
        else:
            # Insert into the [ui] section so it round-trips through load_config.
            ui_match = re.search(r"^\[ui\]\s*$", text, flags=re.MULTILINE)
            if ui_match:
                insert_at = ui_match.end()
                text = text[:insert_at] + f"\n{line}" + text[insert_at:]
            else:
                text = text.rstrip() + f"\n[ui]\n{line}\n"
        path.write_text(text)

    # === Internal ===

    def _maybe_schedule_prefetch(self, data: dict[str, Any]) -> None:
        """Pre-fetch next track URL when 80% through the current track.

        Called on every POSITION_CHANGED tick; only actually schedules once
        per track (guarded by `_prefetch_scheduled_for`) using whatever the
        first live, non-zero duration reading for that track is.
        """
        current_track = self._player.current_track
        video_id = getattr(current_track, "video_id", "") if current_track else ""
        if not video_id or video_id == self._prefetch_scheduled_for:
            return

        duration_ms = int(data.get("duration_ms", 0))
        if duration_ms <= 0:
            return  # player hasn't reported real duration yet — wait for next tick

        self._prefetch_scheduled_for = video_id
        delay_ms = int(duration_ms * 0.8)
        current_pos = int(data.get("position_ms", 0))
        wait_ms = max(0, delay_ms - current_pos)

        if self._prefetch_task and not self._prefetch_task.done():
            self._prefetch_task.cancel()

        async def _do_prefetch() -> None:
            await asyncio.sleep(wait_ms / 1000)
            next_track = self._queue.next_track()
            if next_track and next_track.video_id not in self._url_cache:
                try:
                    url = await self._library.get_stream_url(
                        next_track.video_id, self._config.audio.itag
                    )
                    self._url_cache[next_track.video_id] = url
                    log.debug("player.prefetched", video_id=next_track.video_id)
                except Exception:
                    log.debug("player.prefetch_failed", video_id=next_track.video_id)

        self._prefetch_task = asyncio.create_task(_do_prefetch())

    async def _resolve_stream_for_track(self, video_id: str) -> str:
        """Resolve the stream URL honoring the current audio quality.

        For 'high' quality this auto-resolves 141 -> 774 -> 251 and emits the
        resolved itag so the UI can show what is actually playing.
        """
        quality = getattr(self._config.audio, "quality", "standard")
        if quality == "high":
            itag = await resolve_high_quality(video_id, self._ytm)
        else:
            itag = QUALITY_ITAG_MAP.get(quality, getattr(self._config.audio, "itag", 0) or 250)
        self._current_itag = itag
        self.currentAudioItagChanged.emit(itag)
        return await self._library.get_stream_url(video_id, itag)

    async def _play_track(self, track: Any) -> None:
        """Resolve stream URL and load into player."""
        try:
            if track.video_id in self._url_cache:
                url = self._url_cache.pop(track.video_id)
            else:
                url = await self._resolve_stream_for_track(track.video_id)
            info = TrackInfo(
                video_id=track.video_id,
                title=track.title,
                artist=getattr(track, "artist", ""),
                album=getattr(track, "album", ""),
                duration_ms=getattr(track, "duration_ms", 0),
                thumbnail_url=getattr(track, "thumbnail_url", ""),
            )
            await self._player.load_url(url, info)
        except Exception as e:
            log.exception("proxy.play_failed", video_id=track.video_id)
            self.errorOccurred.emit(str(e))
            self.errorOccurred.emit(str(e))


__all__ = ["DaemonProxy"]
