"""Tests for Audio Buffer Prefetch (T-034 to T-036, T-044, T-046)."""
from __future__ import annotations

import asyncio
import stat
import tempfile
import time
from pathlib import Path
from unittest.mock import MagicMock

from sonictune.library.models import Track
from sonictune.player.buffer_manager import AudioBufferManager


def test_audio_buffer_cache_path_deterministic() -> None:
    """T-034: _cache_path returns same path for same video_id."""
    with tempfile.TemporaryDirectory() as tmpdir:
        mgr = AudioBufferManager(player=MagicMock(), cache_dir=Path(tmpdir))
        p1 = mgr._cache_path("abc123")
        p2 = mgr._cache_path("abc123")
        assert p1 == p2
        assert p1.suffix == ".opus"


def test_audio_buffer_cache_stats() -> None:
    """T-035: cache_stats returns correct structure."""
    with tempfile.TemporaryDirectory() as tmpdir:
        mgr = AudioBufferManager(player=MagicMock(), cache_dir=Path(tmpdir))
        stats = mgr.cache_stats()
        assert "file_count" in stats
        assert "total_mb" in stats
        assert "max_mb" in stats
        assert isinstance(stats["file_count"], int)
        assert isinstance(stats["total_mb"], float)


def test_audio_buffer_lru_eviction() -> None:
    """T-036: trim_cache removes oldest files when over limit."""
    with tempfile.TemporaryDirectory() as tmpdir:
        mgr = AudioBufferManager(player=MagicMock(), cache_dir=Path(tmpdir), max_cache_mb=1)
        # Create two files, 1MB each
        f1 = Path(tmpdir) / "a.opus"
        f1.write_bytes(b"x" * (1024 * 1024))
        time.sleep(0.1)
        f2 = Path(tmpdir) / "b.opus"
        f2.write_bytes(b"y" * (1024 * 1024))
        mgr.trim_cache()
        assert f1.exists() is False  # oldest evicted
        assert f2.exists() is True   # newest kept


def test_audio_buffer_silent_failure() -> None:
    """T-044: _prefetch does not raise when stream resolution fails."""
    with tempfile.TemporaryDirectory() as tmpdir:
        mgr = AudioBufferManager(player=MagicMock(), cache_dir=Path(tmpdir))
        mgr._player.resolve_stream_url = MagicMock(side_effect=Exception("network error"))
        track = Track(
            video_id="fail_test",
            title="Test",
            artist="Artist",
            album="",
            duration_ms=0,
            thumbnail_url="",
        )
        asyncio.run(mgr._prefetch(track, Path(tmpdir) / "test.opus"))


def test_audio_buffer_cache_directory_permissions() -> None:
    """T-046: Audio cache directory has 0700 permissions."""
    with tempfile.TemporaryDirectory() as tmpdir:
        cache = Path(tmpdir) / "audio"
        AudioBufferManager(player=MagicMock(), cache_dir=cache)
        mode = stat.S_IMODE(cache.stat().st_mode)
        assert mode == 0o700


def test_audio_buffer_skips_local_tracks() -> None:
    """Local tracks are never scheduled for prefetch."""
    with tempfile.TemporaryDirectory() as tmpdir:
        mgr = AudioBufferManager(player=MagicMock(), cache_dir=Path(tmpdir))
        local = Track(
            video_id="local:foo",
            title="Local",
            artist="A",
            album="",
            duration_ms=0,
            thumbnail_url="",
        )
        mgr.schedule_prefetch(local)
        assert mgr._pending == set()


def test_audio_buffer_get_cached_path_missing() -> None:
    """get_cached_path returns None for uncached tracks."""
    with tempfile.TemporaryDirectory() as tmpdir:
        mgr = AudioBufferManager(player=MagicMock(), cache_dir=Path(tmpdir))
        assert mgr.get_cached_path("missing_video") is None


def test_audio_buffer_clear_cache() -> None:
    """clear_cache removes all cached audio files."""
    with tempfile.TemporaryDirectory() as tmpdir:
        mgr = AudioBufferManager(player=MagicMock(), cache_dir=Path(tmpdir))
        p = mgr._cache_path("abc123")
        p.write_bytes(b"x" * 5000)
        assert p.exists()
        mgr.clear_cache()
        assert p.exists() is False
