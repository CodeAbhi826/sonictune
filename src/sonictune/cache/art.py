"""Album art cache — fetches, downscales, and stores thumbnails on disk.

Two-tier cache:
1. In-memory: small dict keyed by URL (max 256 entries)
2. On-disk: actual image bytes, LRU by total size

Images are stored as WebP (smaller than JPEG for the same quality).
"""
from __future__ import annotations

import asyncio
import hashlib
import io
from pathlib import Path

import httpx
import structlog
from PIL import Image

from sonictune.cache.lru import LRUCache

log = structlog.get_logger()


class ArtCache:
    """Two-tier album art cache."""

    def __init__(self, cache_dir: Path, max_size_mb: int = 256) -> None:
        self._dir = cache_dir
        self._dir.mkdir(parents=True, exist_ok=True)
        self._max_bytes = max_size_mb * 1024 * 1024
        self._mem_cache: LRUCache[str, Path] = LRUCache(max_entries=256)
        self._lock = asyncio.Lock()
        self._http = httpx.AsyncClient(
            timeout=httpx.Timeout(10.0, connect=5.0),
            follow_redirects=True,
        )

    async def close(self) -> None:
        await self._http.aclose()

    async def get_path(self, url: str) -> Path | None:
        """Return a local Path to the cached art, fetching if needed."""
        # In-memory hit?
        cached = self._mem_cache.get(url)
        if cached and cached.exists():
            return cached

        async with self._lock:
            # Re-check inside lock
            cached = self._mem_cache.get(url)
            if cached and cached.exists():
                return cached

            disk_path = self._url_to_path(url)
            if disk_path.exists():
                self._mem_cache.put(url, disk_path)
                return disk_path

            # Fetch
            try:
                resp = await self._http.get(url)
                resp.raise_for_status()
                raw = resp.content
            except httpx.HTTPError as e:
                log.warning("art.fetch_failed", url=url, error=str(e))
                return None

            # Convert + downscale to WebP
            try:
                img = Image.open(io.BytesIO(raw))
                # Cap at 600x600 (sufficient for HiDPI)
                img.thumbnail((600, 600), Image.Resampling.LANCZOS)
                buf = io.BytesIO()
                img.save(buf, format="WEBP", quality=85)
                disk_path.write_bytes(buf.getvalue())
            except Exception as e:
                log.warning("art.process_failed", url=url, error=str(e))
                return None

            self._mem_cache.put(url, disk_path)
            # Enforce size budget
            await self._enforce_budget()
            return disk_path

    def _url_to_path(self, url: str) -> Path:
        """Hash URL → stable filename."""
        h = hashlib.sha256(url.encode("utf-8")).hexdigest()[:16]
        return self._dir / f"{h}.webp"

    def get_sync(self, url: str) -> Path | None:
        """Synchronous variant of get_path — for the Qt image provider thread.

        Uses a blocking httpx client and bypasses the asyncio lock (the image
        provider runs on Qt's image thread, outside the event loop).
        """
        cached = self._mem_cache.get(url)
        if cached and cached.exists():
            return cached

        disk_path = self._url_to_path(url)
        if disk_path.exists():
            self._mem_cache.put(url, disk_path)
            return disk_path

        try:
            import httpx as _httpx

            with _httpx.Client(timeout=10.0, follow_redirects=True) as http:
                resp = http.get(url)
                resp.raise_for_status()
                raw = resp.content

            img = Image.open(io.BytesIO(raw))
            img.thumbnail((600, 600), Image.Resampling.LANCZOS)
            buf = io.BytesIO()
            img.save(buf, format="WEBP", quality=85)
            disk_path.write_bytes(buf.getvalue())
        except Exception as e:
            log.warning("art.get_sync_failed", url=url, error=str(e))
            return None

        self._mem_cache.put(url, disk_path)
        return disk_path

    async def _enforce_budget(self) -> None:
        """If total size exceeds max, evict oldest files by mtime."""
        await asyncio.to_thread(self._enforce_budget_sync)

    def _enforce_budget_sync(self) -> None:
        files = list(self._dir.glob("*.webp"))
        if not files:
            return
        total = sum(f.stat().st_size for f in files)
        if total <= self._max_bytes:
            return
        # Sort by mtime ascending (oldest first)
        files.sort(key=lambda f: f.stat().st_mtime)
        for f in files:
            if total <= self._max_bytes * 0.9:  # evict down to 90% of cap
                break
            size = f.stat().st_size
            f.unlink(missing_ok=True)
            total -= size
            log.debug("art.evicted", file=f.name, freed_bytes=size)


__all__ = ["ArtCache"]
