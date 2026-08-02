"""Library sync — fetches all user library data from YTM and upserts into DB."""
from __future__ import annotations

from collections.abc import Callable
from datetime import datetime
from typing import Any

import structlog

from sonictune.auth.oauth import OAuthManager
from sonictune.db.database import Database
from sonictune.library.ytmusic import YTMusicLibrary

log = structlog.get_logger()


class LibrarySync:
    """Async library sync with progress callbacks."""

    def __init__(
        self,
        library: YTMusicLibrary,
        db: Database,
        oauth: OAuthManager,
    ) -> None:
        self._library = library
        self._db = db
        self._oauth = oauth
        self._progress_cb: Callable[[str, int, int], None] | None = None

    def set_progress_callback(self, cb: Callable[[str, int, int], None]) -> None:
        self._progress_cb = cb

    async def sync_all(self) -> dict[str, int]:
        if not self._oauth.is_authenticated:
            log.warning("sync.not_authenticated")
            return {"songs": 0, "albums": 0, "artists": 0, "playlists": 0}

        summary: dict[str, int] = {"songs": 0, "albums": 0, "artists": 0, "playlists": 0}

        songs = await self._library.get_library_songs(limit=1000)
        for i, song in enumerate(songs):
            await self._db.upsert_track(
                video_id=song.video_id,
                title=song.title,
                artist=song.artist,
                album=song.album,
                duration_ms=song.duration_ms,
                thumbnail_url=song.thumbnail_url,
            )
            if self._progress_cb:
                self._progress_cb("songs", i + 1, len(songs))
        summary["songs"] = len(songs)
        log.info("sync.songs_done", count=len(songs))

        albums = await self._library.get_library_albums(limit=200)
        for i, album in enumerate(albums):
            await self._db.upsert_album(
                browse_id=album.browse_id,
                title=album.title,
                artist=album.artist,
                year=album.year,
                thumbnail_url=album.thumbnail_url,
                track_count=album.track_count,
            )
            if self._progress_cb:
                self._progress_cb("albums", i + 1, len(albums))
        summary["albums"] = len(albums)
        log.info("sync.albums_done", count=len(albums))

        artists = await self._library.get_library_artists(limit=200)
        for i, artist in enumerate(artists):
            await self._db.upsert_artist(
                channel_id=artist.channel_id,
                name=artist.name,
                thumbnail_url=artist.thumbnail_url,
                subscriber_count=artist.subscriber_count,
            )
            if self._progress_cb:
                self._progress_cb("artists", i + 1, len(artists))
        summary["artists"] = len(artists)
        log.info("sync.artists_done", count=len(artists))

        playlists = await self._library.get_library_playlists(limit=200)
        for i, playlist in enumerate(playlists):
            await self._db.upsert_playlist(
                playlist_id=playlist.playlist_id,
                title=playlist.title,
                description=playlist.description,
                thumbnail_url=playlist.thumbnail_url,
                track_count=playlist.track_count,
                owner=playlist.owner,
            )
            if self._progress_cb:
                self._progress_cb("playlists", i + 1, len(playlists))
        summary["playlists"] = len(playlists)
        log.info("sync.playlists_done", count=len(playlists))

        await self._db.kv_set("last_sync_at", datetime.now().isoformat())
        log.info("sync.complete", summary=summary)
        return summary
