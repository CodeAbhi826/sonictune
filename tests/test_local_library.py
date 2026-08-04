"""Tests for Local Library (T-026 to T-027)."""
from __future__ import annotations

import tempfile
from pathlib import Path

from sonictune.library.local import LocalLibrary


def test_local_library_scan() -> None:
    """T-026: LocalLibrary.scan returns list of Track objects."""
    with tempfile.TemporaryDirectory() as tmpdir:
        lib = LocalLibrary(music_dir=Path(tmpdir))
        tracks = lib.scan()
        assert isinstance(tracks, list)


def test_local_library_get_stream_url() -> None:
    """T-027: LocalLibrary.get_stream_url returns path for local track."""
    import tempfile
    from pathlib import Path
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "testsong.mp3"
        test_file.write_bytes(b"fake mp3 data")
        lib = LocalLibrary(music_dir=Path(tmpdir))
        url = lib.get_stream_url("local:testsong")
        assert url == str(test_file)


def test_local_library_non_local_id() -> None:
    """T-049: get_stream_url returns empty for non-local video_id."""
    lib = LocalLibrary()
    assert lib.get_stream_url("youtube:abc123") == ""


def test_local_library_scan_missing_dir() -> None:
    """scan returns an empty list when the music dir does not exist."""
    import tempfile
    from pathlib import Path
    with tempfile.TemporaryDirectory() as tmpdir:
        missing = Path(tmpdir) / "nope"
        lib = LocalLibrary(music_dir=missing)
        tracks = lib.scan()
        assert tracks == []
