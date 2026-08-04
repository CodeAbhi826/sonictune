"""History back-sync to YT Music — Phase 2.

YouTube Music Recap requires plays to be reported back to YT's servers.
This module rate-limits and dispatches those reports.

Implementation note: ytmusicapi.add_history_item() exists but is undocumented
and subject to rate-limiting. Use with care.
"""
from __future__ import annotations

import asyncio
import contextlib
import time
from collections import deque

import structlog

log = structlog.get_logger()


class HistorySync:
    """Rate-limited back-sync of plays to YouTube Music."""

    def __init__(self, library, min_interval_sec: float = 10.0) -> None:
        self._library = library
        self._min_interval = min_interval_sec
        self._pending: deque[tuple[str, float]] = deque()  # (video_id, played_at)
        self._last_sync: float = 0.0
        self._lock = asyncio.Lock()
        self._task: asyncio.Task | None = None

    async def start(self) -> None:
        self._task = asyncio.create_task(self._run())
        log.info("history_sync.started")

    async def stop(self) -> None:
        if self._task:
            self._task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._task
            self._task = None
        log.info("history_sync.stopped")

    async def report_play(self, video_id: str) -> None:
        async with self._lock:
            self._pending.append((video_id, time.time()))
        log.debug("history_sync.queued", video_id=video_id, queue=len(self._pending))

    async def _run(self) -> None:
        try:
            while True:
                await asyncio.sleep(self._min_interval)
                await self._flush()
        except asyncio.CancelledError:
            # Final flush on shutdown
            await self._flush()

    async def _flush(self) -> None:
        async with self._lock:
            if not self._pending:
                return
            batch = list(self._pending)
            self._pending.clear()

        for video_id, _played_at in batch:
            try:
                await self._library.add_to_history(video_id)
            except Exception:
                log.exception("history_sync.failed", video_id=video_id)


__all__ = ["HistorySync"]
