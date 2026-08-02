"""ytmusicapi wrapper — async-friendly thin layer over the sync ytmusicapi.

ytmusicapi is synchronous (uses `requests` under the hood). We wrap every
call in `asyncio.to_thread()` so it doesn't block our event loop.
"""
from __future__ import annotations

import asyncio
import time
from collections import OrderedDict
from pathlib import Path
from typing import Any

import structlog
from ytmusicapi import YTMusic

from sonictune.auth.oauth import OAuthManager
from sonictune.library.models import Album, Artist, Playlist, Track

log = structlog.get_logger()


class YTMusicLibrary:
    """Async wrapper around ytmusicapi.YTMusic."""

    def __init__(
        self,
        oauth: OAuthManager,
        cookies_path: Path | None = None,
    ) -> None:
        self._oauth = oauth
        self._cookies_path = cookies_path
        self._ytm: YTMusic | None = None
        self._url_cache: dict[str, tuple[str, float]] = {}
        # BUGFIX: this used to be a plain dict that grew by one Lock per
        # distinct video_id for the life of the process (unbounded memory
        # growth on a long-running session). Now bounded + LRU-evicted.
        self._url_locks: OrderedDict[str, asyncio.Lock] = OrderedDict()
        self._max_url_locks = 512
        self._min_url_interval = 2.0
        self._last_ytdlp_call: float = 0.0
        self._global_lock = asyncio.Lock()
        self._authenticated: bool = False

    async def init(self) -> None:
        """Initialize the underlying YTMusic client."""
        # Run in thread because YTMusic() may do a network call on first use
        self._ytm = await asyncio.to_thread(
            self._oauth.build_ytmusic,
            self._cookies_path,
        )
        # BUGFIX: `self._oauth.is_authenticated` only reflects whether an
        # OAuth token is on file — it says nothing about cookie-based auth.
        # A user who only imported cookies would be reported as "not
        # authenticated" forever, even though library calls work fine.
        # Track what build_ytmusic() actually did instead.
        self._authenticated = bool(
            self._oauth.is_authenticated
            or (self._cookies_path and self._cookies_path.exists())
        )
        log.info("library.ready", authenticated=self._authenticated)

    @property
    def is_authenticated(self) -> bool:
        """True if the underlying client was built with real credentials
        (OAuth token or imported cookies), as opposed to anonymous mode."""
        return self._authenticated

    async def close(self) -> None:
        self._ytm = None

    def _require(self) -> YTMusic:
        if self._ytm is None:
            raise RuntimeError("Library not initialized — call init() first")
        return self._ytm

    async def _ensure_token(self) -> None:
        """Refresh OAuth token before an API call if it is expiring."""
        await self._oauth.ensure_valid_token()

    # --- Search ------------------------------------------------------------

    async def search(
        self,
        query: str,
        filter_: str | None = None,
        limit: int = 20,
    ) -> dict[str, Any]:
        """Search YT Music. Returns categorized results.

        Args:
            query: Search string.
            filter_: Optional filter — 'songs', 'albums', 'artists',
                'playlists', 'videos', 'community_playlists', 'featured_playlists'.
                If None, returns mixed results.
            limit: Max results per category.
        """
        await self._ensure_token()
        ytm = self._require()
        result = await asyncio.to_thread(
            ytm.search, query, filter=filter_, limit=limit
        )
        log.info("library.search", query=query, filter=filter_, count=len(result))
        return result

    async def search_songs(self, query: str, limit: int = 20) -> list[Track]:
        """Convenience: search songs only, return typed Track list."""
        results = await self.search(query, filter_="songs", limit=limit)
        return [Track.from_ytmusic(r) for r in results if "videoId" in r]

    # --- Browse ------------------------------------------------------------

    async def get_home(self) -> dict[str, Any]:
        """YT Music home feed."""
        await self._ensure_token()
        ytm = self._require()
        return await asyncio.to_thread(ytm.get_home)

    async def get_charts(self, country: str = "ZZ") -> dict[str, Any]:
        """YT Music charts. country='ZZ' for global."""
        await self._ensure_token()
        ytm = self._require()
        return await asyncio.to_thread(ytm.get_charts, country=country)

    async def get_library_songs(self, limit: int = 100) -> list[Track]:
        """User's liked/uploaded songs."""
        await self._ensure_token()
        ytm = self._require()
        result = await asyncio.to_thread(
            ytm.get_library_songs, limit=limit
        )
        return [Track.from_ytmusic(r) for r in result.get("songs", [])]

    async def get_library_albums(self, limit: int = 50) -> list[Album]:
        await self._ensure_token()
        ytm = self._require()
        result = await asyncio.to_thread(
            ytm.get_library_albums, limit=limit
        )
        return [Album.from_ytmusic(r) for r in result]

    async def get_library_artists(self, limit: int = 50) -> list[Artist]:
        await self._ensure_token()
        ytm = self._require()
        result = await asyncio.to_thread(
            ytm.get_library_artists, limit=limit
        )
        return [Artist.from_ytmusic(r) for r in result]

    async def get_library_playlists(self, limit: int = 50) -> list[Playlist]:
        await self._ensure_token()
        ytm = self._require()
        result = await asyncio.to_thread(
            ytm.get_library_playlists, limit=limit
        )
        return [Playlist.from_ytmusic(r) for r in result]

    # --- Details -----------------------------------------------------------

    async def get_track(self, video_id: str) -> Track:
        """Fetch full details for a single track (incl. streaming URL)."""
        await self._ensure_token()
        ytm = self._require()
        result = await asyncio.to_thread(ytm.get_song, video_id)
        # Extract streaming data
        streaming_data = result.get("streamingData", {})
        adaptive_formats = streaming_data.get("adaptiveFormats", [])
        return Track.from_ytmusic({
            **result.get("videoDetails", {}),
            "streamingData": streaming_data,
            "adaptiveFormats": adaptive_formats,
        })

    async def get_album(self, browse_id: str) -> Album:
        await self._ensure_token()
        ytm = self._require()
        result = await asyncio.to_thread(ytm.get_album, browse_id)
        album = Album.from_ytmusic(result)
        album.tracks = [
            Track.from_ytmusic({**t, "album": {"name": album.title, "id": album.browse_id}})
            for t in result.get("tracks", [])
        ]
        return album

    async def get_artist(self, channel_id: str) -> dict[str, Any]:
        await self._ensure_token()
        ytm = self._require()
        return await asyncio.to_thread(ytm.get_artist, channel_id)

    async def get_playlist(self, playlist_id: str, limit: int = 100) -> dict[str, Any]:
        await self._ensure_token()
        ytm = self._require()
        return await asyncio.to_thread(ytm.get_playlist, playlist_id, limit=limit)

    # --- Streaming URL -----------------------------------------------------

    async def get_stream_url(self, video_id: str, itag: int) -> str:
        """Resolve a streaming URL for a given video_id + itag.

        Uses yt-dlp under the hood. Rate-limited to 1 call per 2s globally,
        with per-video caching (5 min TTL) and dedup locks.
        """
        now = time.time()
        if video_id in self._url_cache:
            url, fetched_at = self._url_cache[video_id]
            if now - fetched_at < 300:
                return url

        if video_id in self._url_locks:
            self._url_locks.move_to_end(video_id)
        else:
            self._url_locks[video_id] = asyncio.Lock()
            if len(self._url_locks) > self._max_url_locks:
                # Evict the least-recently-used lock. Safe as long as it's
                # not currently held — the oldest entries are the ones least
                # likely to be mid-use.
                self._url_locks.popitem(last=False)

        async with self._url_locks[video_id]:
            if video_id in self._url_cache:
                url, fetched_at = self._url_cache[video_id]
                if now - fetched_at < 300:
                    return url

            async with self._global_lock:
                elapsed = time.time() - self._last_ytdlp_call
                if elapsed < self._min_url_interval:
                    await asyncio.sleep(self._min_url_interval - elapsed)
                self._last_ytdlp_call = time.time()

            from yt_dlp import YoutubeDL

            def _extract() -> str:
                # BUGFIX: the configured itag (default aac_256 -> 141) is
                # Premium-only. On free accounts requesting it makes yt-dlp
                # fail with "Requested format is not available" for *every*
                # video. Try the requested itag first, then fall back through
                # the free formats (251 = opus 160k, 140 = aac 128k), then
                # any best-audio format — so playback works on any account.
                fallback = "bestaudio/best"
                fmt_chain = {
                    141: "141/251/140",
                    251: "251/140",
                    140: "140",
                }.get(itag, str(itag))
                opts = {
                    "format": f"{fmt_chain}/{fallback}",
                    "quiet": True,
                    "no_warnings": True,
                    "skip_download": True,
                    "noplaylist": True,
                }
                with YoutubeDL(opts) as ydl:
                    info = ydl.extract_info(
                        f"https://music.youtube.com/watch?v={video_id}",
                        download=False,
                    )
                    if info and info.get("url"):
                        return info["url"]
                    for f in info.get("formats", []) if info else []:
                        if f.get("url"):
                            return f["url"]
                    raise RuntimeError(f"No playable URL for itag {itag}")

            url = await asyncio.to_thread(_extract)
            self._url_cache[video_id] = (url, time.time())
            log.info("library.stream_url", video_id=video_id, itag=itag)
            return url

    # --- History back-sync (Phase 2) --------------------------------------

    async def add_to_history(self, video_id: str) -> bool:
        """Report a play back to YT Music (for YouTube Recap).

        Returns True if accepted. Rate-limited: max 1 call / 10s per video.
        """
        # TODO: Phase 2 — ytmusicapi.add_history_item() is undocumented and
        # requires careful rate-limiting. For now we just log locally.
        log.info("library.history_sync_pending", video_id=video_id)
        return False


__all__ = ["YTMusicLibrary"]
