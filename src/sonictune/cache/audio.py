"""Audio cache — stores downloaded audio files with LRU eviction.

Used for:
1. Pre-fetched upcoming tracks (gapless playback)
2. User-initiated downloads (Phase 3)
3. Recently-played tracks (avoids re-fetching)

Files are stored as: {cache_dir}/{video_id}_{itag}.webm (or .m4a)
"""
from __future__ import annotations

import asyncio
from pathlib import Path

import structlog

log = structlog.get_logger()


class AudioCache:
    """On-disk LRU audio cache, sized by total bytes."""

    def __init__(self, cache_dir: Path, max_size_mb: int = 1024) -> None:
        self._dir = cache_dir
        self._dir.mkdir(parents=True, exist_ok=True)
        self._max_bytes = max_size_mb * 1024 * 1024
        self._lock = asyncio.Lock()

    def path_for(self, video_id: str, itag: int, ext: str = "webm") -> Path:
        return self._dir / f"{video_id}_{itag}.{ext}"

    async def get(self, video_id: str, itag: int, ext: str = "webm") -> Path | None:
        """Return cached path if present, else None."""
        path = self.path_for(video_id, itag, ext)
        if path.exists():
            # Update mtime to mark as recently used
            await asyncio.to_thread(path.touch)
            return path
        return None

    async def put(self, video_id: str, itag: int, data: bytes, ext: str = "webm") -> Path:
        """Write audio data to cache and return the path."""
        path = self.path_for(video_id, itag, ext)
        async with self._lock:
            await asyncio.to_thread(path.write_bytes, data)
            await self._enforce_budget()
        log.info("audio.cached", video_id=video_id, itag=itag, bytes=len(data))
        return path

    async def _enforce_budget(self) -> None:
        await asyncio.to_thread(self._enforce_budget_sync)

    def _enforce_budget_sync(self) -> None:
        files = list(self._dir.iterdir())
        if not files:
            return
        total = sum(f.stat().st_size for f in files if f.is_file())
        if total <= self._max_bytes:
            return
        files.sort(key=lambda f: f.stat().st_mtime)
        for f in files:
            if total <= self._max_bytes * 0.9:
                break
            if not f.is_file():
                continue
            size = f.stat().st_size
            f.unlink(missing_ok=True)
            total -= size
            log.debug("audio.evicted", file=f.name, freed_bytes=size)

    async def clear(self) -> None:
        async with self._lock:
            await asyncio.to_thread(self._clear_sync)

    def _clear_sync(self) -> None:
        for f in self._dir.iterdir():
            if f.is_file():
                f.unlink(missing_ok=True)
        log.info("audio.cache_cleared")

    async def get_size_bytes(self) -> int:
        return await asyncio.to_thread(self._get_size_sync)

    def _get_size_sync(self) -> int:
        return sum(f.stat().st_size for f in self._dir.iterdir() if f.is_file())


__all__ = ["AudioCache"]
