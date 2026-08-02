"""Stats aggregator — computes listening time, top artists, year recap.

Reads from play_history table. Aggregations are computed on-demand (cached
for 5 minutes) so we don't need a separate materialized view.
"""
from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass
from typing import Any

import structlog

from sonictune.db.database import Database

log = structlog.get_logger()


@dataclass(slots=True)
class Stats:
    """Aggregated stats snapshot."""

    total_plays: int = 0
    total_listen_ms: int = 0
    unique_tracks: int = 0
    unique_artists: int = 0
    top_tracks: list[dict[str, Any]] = None  # type: ignore[assignment]
    top_artists: list[dict[str, Any]] = None  # type: ignore[assignment]
    top_albums: list[dict[str, Any]] = None  # type: ignore[assignment]
    listening_by_hour: list[int] = None  # type: ignore[assignment]  # 24 buckets
    listening_by_day: list[int] = None  # type: ignore[assignment]  # 7 buckets (Mon-Sun)
    last_30_days: list[dict[str, Any]] = None  # type: ignore[assignment]


class StatsAggregator:
    """Computes and caches aggregated stats."""

    def __init__(self, db: Database, cache_ttl_sec: int = 300) -> None:
        self._db = db
        self._cache_ttl = cache_ttl_sec
        self._cache: tuple[float, Stats] | None = None
        self._lock = asyncio.Lock()

    async def get_stats(self, force_refresh: bool = False) -> Stats:
        async with self._lock:
            if not force_refresh and self._cache and (time.time() - self._cache[0]) < self._cache_ttl:
                return self._cache[1]

            stats = await self._compute_stats()
            self._cache = (time.time(), stats)
            return stats

    async def _compute_stats(self) -> Stats:
        """Run all aggregation queries."""
        # Total plays + listen time
        row = await self._db.fetchone(
            """
            SELECT
                COUNT(*) as plays,
                COALESCE(SUM(duration_played_ms), 0) as total_ms,
                COUNT(DISTINCT video_id) as unique_tracks
            FROM play_history
            """
        )
        total_plays = row[0] if row else 0
        total_listen_ms = row[1] if row else 0
        unique_tracks = row[2] if row else 0

        # Top tracks (last 30 days)
        top_tracks_rows = await self._db.fetchall(
            """
            SELECT
                t.video_id, t.title, t.artist, t.thumbnail_url,
                COUNT(*) as play_count,
                SUM(ph.duration_played_ms) as total_ms
            FROM play_history ph
            JOIN tracks t ON t.video_id = ph.video_id
            WHERE ph.started_at >= datetime('now', '-30 days')
            GROUP BY t.video_id
            ORDER BY total_ms DESC
            LIMIT 25
            """
        )
        top_tracks = [
            {
                "video_id": r[0],
                "title": r[1],
                "artist": r[2],
                "thumbnail_url": r[3],
                "play_count": r[4],
                "listen_ms": r[5],
            }
            for r in top_tracks_rows
        ]

        # Top artists
        top_artists_rows = await self._db.fetchall(
            """
            SELECT
                t.artist,
                COUNT(*) as play_count,
                SUM(ph.duration_played_ms) as total_ms
            FROM play_history ph
            JOIN tracks t ON t.video_id = ph.video_id
            WHERE ph.started_at >= datetime('now', '-30 days')
              AND t.artist IS NOT NULL AND t.artist != ''
            GROUP BY t.artist
            ORDER BY total_ms DESC
            LIMIT 25
            """
        )
        top_artists = [
            {"artist": r[0], "play_count": r[1], "listen_ms": r[2]}
            for r in top_artists_rows
        ]

        # Listening by hour-of-day (0-23)
        hour_rows = await self._db.fetchall(
            """
            SELECT CAST(strftime('%H', started_at) AS INTEGER) as hour,
                   SUM(duration_played_ms) as total_ms
            FROM play_history
            GROUP BY hour
            """
        )
        listening_by_hour = [0] * 24
        for h, ms in hour_rows:
            if 0 <= h < 24:
                listening_by_hour[h] = ms

        # Listening by day-of-week (0=Mon)
        day_rows = await self._db.fetchall(
            """
            SELECT CAST(strftime('%w', started_at) AS INTEGER) as dow,
                   SUM(duration_played_ms) as total_ms
            FROM play_history
            GROUP BY dow
            """
        )
        listening_by_day = [0] * 7
        for dow, ms in day_rows:
            # SQLite: 0=Sunday, we want 0=Monday
            adjusted = (dow - 1) % 7
            listening_by_day[adjusted] = ms

        # Last 30 days (time series)
        last_30_rows = await self._db.fetchall(
            """
            SELECT date(started_at) as day,
                   SUM(duration_played_ms) as total_ms,
                   COUNT(*) as plays
            FROM play_history
            WHERE started_at >= datetime('now', '-30 days')
            GROUP BY day
            ORDER BY day ASC
            """
        )
        last_30_days = [
            {"date": r[0], "listen_ms": r[1], "plays": r[2]}
            for r in last_30_rows
        ]

        unique_artists_row = await self._db.fetchone(
            """
            SELECT COUNT(DISTINCT artist) FROM tracks
            WHERE artist IS NOT NULL AND artist != ''
              AND video_id IN (SELECT video_id FROM play_history)
            """
        )
        unique_artists = unique_artists_row[0] if unique_artists_row else 0

        return Stats(
            total_plays=total_plays,
            total_listen_ms=total_listen_ms,
            unique_tracks=unique_tracks,
            unique_artists=unique_artists,
            top_tracks=top_tracks,
            top_artists=top_artists,
            top_albums=[],  # TODO: top albums query
            listening_by_hour=listening_by_hour,
            listening_by_day=listening_by_day,
            last_30_days=last_30_days,
        )

    async def record_play(
        self,
        video_id: str,
        duration_played_ms: int,
        completion_pct: float,
        started_at: str | None = None,
    ) -> None:
        """Record a play event. Called by daemon when a track ends.

        Args:
            started_at: ISO-8601 UTC start timestamp captured when the track
                began playing; ``None`` falls back to ``datetime('now')`` in
                the database (used when the start time is unknown).
        """
        await self._db.record_play(video_id, duration_played_ms, completion_pct, started_at)
        # Invalidate cache
        async with self._lock:
            self._cache = None
        log.debug("stats.recorded", video_id=video_id, ms=duration_played_ms)


__all__ = ["Stats", "StatsAggregator"]
