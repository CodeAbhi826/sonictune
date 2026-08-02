"""Tests for sonictune.db.database."""
from __future__ import annotations

from pathlib import Path

import pytest

from sonictune.db.database import Database


@pytest.fixture
async def db(tmp_path: Path) -> Database:
    db = Database(tmp_path / "test.db")
    await db.init()
    yield db  # type: ignore[misc]
    await db.close()


async def test_db_init_creates_schema(db: Database) -> None:
    # Check tables exist
    tables = await db.fetchall(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
    )
    table_names = {t[0] for t in tables}
    assert "tracks" in table_names
    assert "albums" in table_names
    assert "artists" in table_names
    assert "playlists" in table_names
    assert "play_history" in table_names
    assert "kv_store" in table_names
    assert "schema_version" in table_names


async def test_db_upsert_track(db: Database) -> None:
    await db.upsert_track(
        video_id="vid1",
        title="Test Track",
        artist="Test Artist",
        album="Test Album",
        duration_ms=180000,
        thumbnail_url="https://example.com/thumb.jpg",
        itag=141,
    )

    row = await db.fetchone("SELECT title, artist, album FROM tracks WHERE video_id = ?", ("vid1",))
    assert row is not None
    assert row[0] == "Test Track"
    assert row[1] == "Test Artist"
    assert row[2] == "Test Album"


async def test_db_upsert_track_idempotent(db: Database) -> None:
    """Re-upserting the same video_id should update, not duplicate."""
    await db.upsert_track(video_id="vid1", title="Old Title")
    await db.upsert_track(video_id="vid1", title="New Title")

    rows = await db.fetchall("SELECT title FROM tracks WHERE video_id = ?", ("vid1",))
    assert len(rows) == 1
    assert rows[0][0] == "New Title"


async def test_db_record_play(db: Database) -> None:
    await db.upsert_track(video_id="vid1", title="Test")

    await db.record_play("vid1", duration_played_ms=120000, completion_pct=0.95)

    rows = await db.fetchall("SELECT video_id, duration_played_ms, completion_pct FROM play_history")
    assert len(rows) == 1
    assert rows[0][0] == "vid1"
    assert rows[0][1] == 120000
    assert rows[0][2] == 0.95


async def test_db_kv_store(db: Database) -> None:
    # Default for missing key
    assert await db.kv_get("missing") is None
    assert await db.kv_get("missing", default="fallback") == "fallback"

    # Set + get
    await db.kv_set("key1", "value1")
    assert await db.kv_get("key1") == "value1"

    # Update existing
    await db.kv_set("key1", "value2")
    assert await db.kv_get("key1") == "value2"


async def test_db_wal_mode_enabled(db: Database) -> None:
    """WAL mode should be enabled for concurrent read access."""
    row = await db.fetchone("PRAGMA journal_mode")
    assert row is not None
    assert row[0].lower() == "wal"
