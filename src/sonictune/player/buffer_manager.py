# src/sonictune/player/buffer_manager.py
"""AudioBufferManager -- Zero-stutter prefetching with disk-based LRU cache."""

from __future__ import annotations

import asyncio
import hashlib
import stat
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING

import aiohttp
import structlog

if TYPE_CHECKING:
    from sonictune.library.models import Track
    from sonictune.player.mpv_player import MpvPlayer

log = structlog.get_logger()


@dataclass(frozen=True)
class CacheEntry:
    video_id: str
    path: Path
    size_bytes: int
    last_accessed: float


class AudioBufferManager:
    """Manages audio stream prefetching and disk caching.

    Cache directory: ~/.cache/sonictune/audio/ (0700 permissions).
    """

    def __init__(
        self,
        player: MpvPlayer,
        cache_dir: Path,
        max_cache_mb: int = 500,
        preload_threshold_percent: float = 0.5,
    ) -> None:
        self._player = player
        self._cache_dir = cache_dir
        self._max_cache_bytes = max_cache_mb * 1024 * 1024
        self._preload_threshold = preload_threshold_percent

        self._cache_dir.mkdir(parents=True, exist_ok=True)
        self._pending: set[str] = set()
        self._lock = asyncio.Lock()
        self._cache_dir.chmod(stat.S_IRWXU)

    async def schedule_prefetch(self, track: Track) -> None:
        """Start downloading track into cache if not already cached."""
        if track.video_id.startswith("local:"):
            return
        if track.video_id in self._pending:
            return
        cache_path = self._cache_path(track.video_id)
        if cache_path.exists() and cache_path.stat().st_size > 4096:
            cache_path.touch()
            return
        asyncio.create_task(self._prefetch(track, cache_path))

    def get_cached_path(self, video_id: str) -> Path | None:
        """Return cached file path if available and valid."""
        path = self._cache_path(video_id)
        if path.exists() and path.stat().st_size > 4096:
            path.touch()
            return path
        return None

    def trim_cache(self) -> None:
        """Evict oldest entries until total size <= max_cache_bytes."""
        files = sorted(self._cache_dir.glob("*.opus"), key=lambda p: p.stat().st_atime)
        total = sum(f.stat().st_size for f in files)
        while total > self._max_cache_bytes and files:
            oldest = files.pop(0)
            total -= oldest.stat().st_size
            try:
                oldest.unlink()
                log.debug("cache.evict", path=str(oldest), reason="lru")
            except OSError as e:
                log.warning("cache.evict_failed", path=str(oldest), error=str(e))

    def clear_cache(self) -> None:
        """Remove all cached audio files."""
        for f in self._cache_dir.glob("*.opus"):
            try:
                f.unlink()
            except OSError:
                pass
        log.info("cache.cleared")

    def cache_stats(self) -> dict[str, int | float]:
        """Return cache statistics."""
        files = list(self._cache_dir.glob("*.opus"))
        total_bytes = sum(f.stat().st_size for f in files)
        return {
            "file_count": len(files),
            "total_mb": round(total_bytes / (1024 * 1024), 2),
            "max_mb": self._max_cache_bytes // (1024 * 1024),
        }

    def _cache_path(self, video_id: str) -> Path:
        safe_id = hashlib.sha256(video_id.encode()).hexdigest()[:16]
        return self._cache_dir / f"{safe_id}.opus"

    async def _prefetch(self, track: Track, path: Path) -> None:
        async with self._lock:
            if track.video_id in self._pending:
                return
            self._pending.add(track.video_id)

        try:
            log.debug("prefetch.start", video_id=track.video_id, title=track.title)
            url = await self._resolve_stream_url(track.video_id)
            if not url:
                log.debug("prefetch.no_url", video_id=track.video_id)
                return

            timeout = aiohttp.ClientTimeout(total=60, connect=10)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url, ssl=True) as resp:
                    if resp.status != 200:
                        log.warning("prefetch.http_error", video_id=track.video_id, status=resp.status)
                        return
                    with open(path, "wb") as f:
                        async for chunk in resp.content.iter_chunked(64 * 1024):
                            f.write(chunk)

            path.chmod(stat.S_IRUSR | stat.S_IWUSR)
            log.info("prefetch.complete", video_id=track.video_id, size_mb=round(path.stat().st_size / (1024 * 1024), 2))
            self.trim_cache()

        except asyncio.CancelledError:
            raise
        except Exception as e:
            log.warning("prefetch.failed", video_id=track.video_id, error=str(e))
            if path.exists():
                try:
                    path.unlink()
                except OSError:
                    pass
        finally:
            self._pending.discard(track.video_id)

    async def _resolve_stream_url(self, video_id: str) -> str | None:
        try:
            return await self._player.resolve_stream_url(video_id)
        except Exception as e:
            log.warning("prefetch.resolve_failed", video_id=video_id, error=str(e))
            return None

    async def on_position_update(self, position_ms: int, duration_ms: int, next_track: Track | None) -> None:
        if not next_track or duration_ms <= 0:
            return
        progress = position_ms / duration_ms
        if progress >= self._preload_threshold:
            await self.schedule_prefetch(next_track)
