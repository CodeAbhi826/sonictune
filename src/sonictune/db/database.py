"""Async SQLite database wrapper with WAL mode and migration support."""
from __future__ import annotations

from pathlib import Path
from typing import Any

import aiosqlite
import structlog

log = structlog.get_logger()


SCHEMA = """
-- Schema version (single source of truth for migrations)
CREATE TABLE IF NOT EXISTS schema_version (
    version     INTEGER PRIMARY KEY,
    applied_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Tracks we know about (cached YTM metadata)
CREATE TABLE IF NOT EXISTS tracks (
    video_id        TEXT PRIMARY KEY,
    title           TEXT NOT NULL,
    artist          TEXT,
    album           TEXT,
    duration_ms     INTEGER,
    thumbnail_url   TEXT,
    itag            INTEGER,
    is_explicit     INTEGER DEFAULT 0,
    first_seen_at   TEXT NOT NULL DEFAULT (datetime('now')),
    last_played_at  TEXT
);
CREATE INDEX IF NOT EXISTS idx_tracks_artist ON tracks(artist);
CREATE INDEX IF NOT EXISTS idx_tracks_album  ON tracks(album);
CREATE INDEX IF NOT EXISTS idx_tracks_last_played ON tracks(last_played_at);

-- Albums (denormalized for fast browsing)
CREATE TABLE IF NOT EXISTS albums (
    browse_id       TEXT PRIMARY KEY,
    title           TEXT NOT NULL,
    artist          TEXT,
    year            INTEGER,
    thumbnail_url   TEXT,
    track_count     INTEGER DEFAULT 0,
    cached_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Artists
CREATE TABLE IF NOT EXISTS artists (
    channel_id      TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    thumbnail_url   TEXT,
    subscriber_count INTEGER,
    cached_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Playlists (user library)
CREATE TABLE IF NOT EXISTS playlists (
    playlist_id     TEXT PRIMARY KEY,
    title           TEXT NOT NULL,
    description     TEXT,
    thumbnail_url   TEXT,
    track_count     INTEGER DEFAULT 0,
    owner           TEXT,
    cached_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Listening history (local)
CREATE TABLE IF NOT EXISTS play_history (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    video_id        TEXT NOT NULL,
    started_at      TEXT NOT NULL DEFAULT (datetime('now')),
    ended_at        TEXT,
    duration_played_ms INTEGER DEFAULT 0,
    completion_pct  REAL DEFAULT 0,
    FOREIGN KEY (video_id) REFERENCES tracks(video_id)
);
CREATE INDEX IF NOT EXISTS idx_history_started ON play_history(started_at);
CREATE INDEX IF NOT EXISTS idx_history_video   ON play_history(video_id);

-- Cached search queries (for fast re-query & suggestions)
CREATE TABLE IF NOT EXISTS search_history (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    query           TEXT NOT NULL UNIQUE,
    last_used_at    TEXT NOT NULL DEFAULT (datetime('now')),
    result_count    INTEGER DEFAULT 0
);

-- Downloaded files (local cache mapping)
CREATE TABLE IF NOT EXISTS downloads (
    video_id        TEXT PRIMARY KEY,
    file_path       TEXT NOT NULL,
    file_size_bytes INTEGER NOT NULL,
    itag            INTEGER NOT NULL,
    format          TEXT NOT NULL,  -- 'aac' | 'opus' | 'mp3'
    downloaded_at   TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (video_id) REFERENCES tracks(video_id)
);

-- Settings key-value store (for things that don't fit elsewhere)
CREATE TABLE IF NOT EXISTS kv_store (
    key             TEXT PRIMARY KEY,
    value           TEXT NOT NULL,
    updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);
"""

EXPECTED_VERSION = 1


class Database:
    """Async SQLite wrapper. Use as an async context manager or call init/close."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self._conn: aiosqlite.Connection | None = None

    async def init(self) -> None:
        """Open the connection, enable WAL mode, run migrations."""
        log.info("db.init", path=str(self.path))
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = await aiosqlite.connect(str(self.path))

        # Performance pragmas — WAL mode allows concurrent reads while writing
        await self._conn.execute("PRAGMA journal_mode=WAL;")
        await self._conn.execute("PRAGMA synchronous=NORMAL;")
        await self._conn.execute("PRAGMA foreign_keys=ON;")
        await self._conn.execute("PRAGMA temp_store=MEMORY;")
        await self._conn.execute("PRAGMA mmap_size=268435456;")  # 256 MB

        await self._migrate()
        await self._conn.commit()

    async def _migrate(self) -> None:
        """Apply schema migrations."""
        assert self._conn is not None
        await self._conn.executescript(SCHEMA)

        cur = await self._conn.execute("SELECT MAX(version) FROM schema_version;")
        row = await cur.fetchone()
        current = row[0] if row and row[0] else 0

        if current < EXPECTED_VERSION:
            await self._conn.execute(
                "INSERT INTO schema_version (version) VALUES (?);",
                (EXPECTED_VERSION,),
            )
            log.info("db.migrated", from_version=current, to_version=EXPECTED_VERSION)

    async def close(self) -> None:
        if self._conn:
            await self._conn.close()
            self._conn = None
            log.info("db.closed")

    # --- Generic helpers ---------------------------------------------------

    async def execute(self, sql: str, params: tuple[Any, ...] = ()) -> aiosqlite.Cursor:
        """Execute a single SQL statement. Caller is responsible for commit."""
        assert self._conn is not None
        return await self._conn.execute(sql, params)

    async def executemany(self, sql: str, params: list[tuple[Any, ...]]) -> aiosqlite.Cursor:
        assert self._conn is not None
        return await self._conn.executemany(sql, params)

    async def fetchall(self, sql: str, params: tuple[Any, ...] = ()) -> list[tuple[Any, ...]]:
        assert self._conn is not None
        cur = await self._conn.execute(sql, params)
        return await cur.fetchall()

    async def fetchone(self, sql: str, params: tuple[Any, ...] = ()) -> tuple[Any, ...] | None:
        assert self._conn is not None
        cur = await self._conn.execute(sql, params)
        return await cur.fetchone()

    async def commit(self) -> None:
        assert self._conn is not None
        await self._conn.commit()

    # --- Domain-specific helpers -------------------------------------------

    async def upsert_track(
        self,
        video_id: str,
        title: str,
        artist: str | None = None,
        album: str | None = None,
        duration_ms: int | None = None,
        thumbnail_url: str | None = None,
        itag: int | None = None,
    ) -> None:
        await self.execute(
            """
            INSERT INTO tracks (video_id, title, artist, album, duration_ms,
                                thumbnail_url, itag, last_played_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
            ON CONFLICT(video_id) DO UPDATE SET
                title=excluded.title,
                artist=excluded.artist,
                album=excluded.album,
                duration_ms=excluded.duration_ms,
                thumbnail_url=excluded.thumbnail_url,
                itag=excluded.itag,
                last_played_at=datetime('now')
            """,
            (video_id, title, artist, album, duration_ms, thumbnail_url, itag),
        )
        await self.commit()

    async def record_play(
        self,
        video_id: str,
        duration_played_ms: int,
        completion_pct: float,
        started_at: str | None = None,
    ) -> None:
        await self.execute(
            """
            INSERT INTO play_history (video_id, started_at, ended_at, duration_played_ms, completion_pct)
            VALUES (?, COALESCE(?, datetime('now')), datetime('now'), ?, ?)
            """,
            (video_id, started_at, duration_played_ms, completion_pct),
        )
        await self.commit()

    async def upsert_album(
        self,
        browse_id: str,
        title: str,
        artist: str | None = None,
        year: int | None = None,
        thumbnail_url: str | None = None,
        track_count: int | None = None,
    ) -> None:
        await self.execute(
            """
            INSERT INTO albums (browse_id, title, artist, year, thumbnail_url, track_count)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(browse_id) DO UPDATE SET
                title=excluded.title, artist=excluded.artist, year=excluded.year,
                thumbnail_url=excluded.thumbnail_url, track_count=excluded.track_count,
                cached_at=datetime('now')
            """,
            (browse_id, title, artist, year, thumbnail_url, track_count),
        )
        await self.commit()

    async def upsert_artist(
        self,
        channel_id: str,
        name: str,
        thumbnail_url: str | None = None,
        subscriber_count: int | None = None,
    ) -> None:
        await self.execute(
            """
            INSERT INTO artists (channel_id, name, thumbnail_url, subscriber_count)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(channel_id) DO UPDATE SET
                name=excluded.name, thumbnail_url=excluded.thumbnail_url,
                subscriber_count=excluded.subscriber_count, cached_at=datetime('now')
            """,
            (channel_id, name, thumbnail_url, subscriber_count),
        )
        await self.commit()

    async def upsert_playlist(
        self,
        playlist_id: str,
        title: str,
        description: str | None = None,
        thumbnail_url: str | None = None,
        track_count: int | None = None,
        owner: str | None = None,
    ) -> None:
        await self.execute(
            """
            INSERT INTO playlists (playlist_id, title, description, thumbnail_url, track_count, owner)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(playlist_id) DO UPDATE SET
                title=excluded.title, description=excluded.description,
                thumbnail_url=excluded.thumbnail_url, track_count=excluded.track_count,
                owner=excluded.owner, cached_at=datetime('now')
            """,
            (playlist_id, title, description, thumbnail_url, track_count, owner),
        )
        await self.commit()

    async def record_search(self, query: str, result_count: int = 0) -> None:
        await self.execute(
            """
            INSERT INTO search_history (query, last_used_at, result_count)
            VALUES (?, datetime('now'), ?)
            ON CONFLICT(query) DO UPDATE SET
                last_used_at=datetime('now'),
                result_count=excluded.result_count
            """,
            (query, result_count),
        )
        await self.commit()

    async def get_search_history(self, limit: int = 10) -> list[dict[str, Any]]:
        rows = await self.fetchall(
            "SELECT query, last_used_at, result_count FROM search_history"
            " ORDER BY last_used_at DESC LIMIT ?",
            (limit,),
        )
        return [
            {"query": r[0], "last_used_at": r[1], "result_count": r[2]}
            for r in rows
        ]

    async def kv_get(self, key: str, default: str | None = None) -> str | None:
        row = await self.fetchone("SELECT value FROM kv_store WHERE key = ?", (key,))
        return row[0] if row else default

    async def kv_set(self, key: str, value: str) -> None:
        await self.execute(
            """
            INSERT INTO kv_store (key, value, updated_at)
            VALUES (?, ?, datetime('now'))
            ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=datetime('now')
            """,
            (key, value),
        )
        await self.commit()


__all__ = ["Database"]
