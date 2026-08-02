"""LRCLIB client — synced lyrics from https://lrclib.net

LRCLIB is a free and open-source synced lyrics database. No API key
required, just be nice (rate limit: ~1 req/sec, which we enforce).
"""
from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass
from typing import Any

import httpx
import structlog

log = structlog.get_logger()

LRCLIB_BASE = "https://lrclib.net/api"


@dataclass(slots=True)
class LyricLine:
    """A single synced lyric line."""

    time_ms: int  # 0 for unsynced lines
    text: str


class LrclibClient:
    """Async client for LRCLIB."""

    def __init__(self, rate_limit_per_sec: float = 1.0) -> None:
        self._http = httpx.AsyncClient(
            base_url=LRCLIB_BASE,
            timeout=httpx.Timeout(10.0, connect=5.0),
            headers={"User-Agent": "SonicTune/0.1 (https://github.com/CodeAbhi826/sonictune)"},
        )
        self._min_interval = 1.0 / rate_limit_per_sec
        self._last_request: float = 0.0
        self._lock = asyncio.Lock()
        self._offset_ms: int = 0  # user-adjustable offset

    async def close(self) -> None:
        await self._http.aclose()

    def set_offset(self, offset_ms: int) -> None:
        """Set a global lyric offset (ms, positive = push later)."""
        self._offset_ms = offset_ms

    async def _throttle(self) -> None:
        async with self._lock:
            now = time.monotonic()
            wait = self._min_interval - (now - self._last_request)
            if wait > 0:
                await asyncio.sleep(wait)
            self._last_request = time.monotonic()

    async def get_synced(
        self,
        track_name: str,
        artist_name: str,
        album_name: str | None = None,
        duration_ms: int | None = None,
    ) -> list[LyricLine]:
        """Fetch synced lyrics for a track.

        Returns:
            List of LyricLine objects (sorted by time). Empty if not found.
        """
        await self._throttle()

        params: dict[str, Any] = {
            "track_name": track_name,
            "artist_name": artist_name,
        }
        if album_name:
            params["album_name"] = album_name
        if duration_ms:
            params["duration"] = str(int(duration_ms / 1000))

        try:
            resp = await self._http.get("/get", params=params)
        except httpx.HTTPError as e:
            log.warning("lrclib.request_failed", error=str(e))
            return []

        if resp.status_code == 404:
            log.info("lrclib.not_found", track=track_name, artist=artist_name)
            return []
        if resp.status_code != 200:
            log.warning("lrclib.error", status=resp.status_code)
            return []

        try:
            data = resp.json()
        except ValueError:
            log.warning("lrclib.bad_json")
            return []

        synced = data.get("syncedLyrics")
        if not synced:
            # Fall back to plain lyrics
            plain = data.get("plainLyrics", "")
            return [LyricLine(time_ms=0, text=line) for line in plain.split("\n") if line.strip()]

        return self._parse_lrc(synced)

    async def search(
        self,
        query: str | None = None,
        track_name: str | None = None,
        artist_name: str | None = None,
    ) -> list[dict[str, Any]]:
        """Search LRCLIB for lyrics. Returns raw metadata list."""
        await self._throttle()
        params: dict[str, Any] = {}
        if query:
            params["q"] = query
        if track_name:
            params["track_name"] = track_name
        if artist_name:
            params["artist_name"] = artist_name

        try:
            resp = await self._http.get("/search", params=params)
        except httpx.HTTPError as e:
            log.warning("lrclib.search_failed", error=str(e))
            return []

        if resp.status_code != 200:
            return []
        try:
            return resp.json() or []
        except ValueError:
            return []

    def _parse_lrc(self, lrc_text: str) -> list[LyricLine]:
        """Parse LRC format into LyricLine list.

        LRC lines look like: [mm:ss.xx]lyric text
        Multiple timestamps on one line are allowed: [00:01.00][00:05.00]text
        """
        lines: list[LyricLine] = []
        for raw_line in lrc_text.split("\n"):
            # Strip ID tags like [ar:Artist], [al:Album] — they have non-numeric content
            stripped = raw_line.strip()
            if not stripped:
                continue

            # Find all [mm:ss.xx] prefixes
            i = 0
            timestamps: list[int] = []
            while stripped[i:i + 1] == "[":
                end = stripped.find("]", i)
                if end == -1:
                    break
                tag = stripped[i + 1:end]
                # Try to parse as timestamp
                ts = self._parse_timestamp(tag)
                if ts is not None:
                    timestamps.append(ts)
                i = end + 1

            if not timestamps:
                # Plain line without timestamp (likely metadata or unsynced)
                continue

            text = stripped[i:]
            for ts in timestamps:
                adjusted = max(0, ts + self._offset_ms)
                lines.append(LyricLine(time_ms=adjusted, text=text))

        lines.sort(key=lambda l: l.time_ms)
        return lines

    @staticmethod
    def _parse_timestamp(tag: str) -> int | None:
        """Parse [mm:ss.xx] or [mm:ss] → milliseconds. Returns None if not a timestamp."""
        parts = tag.split(":")
        if len(parts) != 2:
            return None
        try:
            minutes = int(parts[0])
            seconds = float(parts[1])
            return int(minutes * 60_000 + seconds * 1000)
        except (ValueError, IndexError):
            return None


__all__ = ["LrclibClient", "LyricLine"]
