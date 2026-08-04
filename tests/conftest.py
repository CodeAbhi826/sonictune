"""Shared fixtures for the SonicTest suite.

Kept self-contained so each test module stays readable. Tests never touch a
real network, a real D-Bus session, or real libmpv.
"""
from __future__ import annotations

from pathlib import Path

import pytest

from sonictune.db.database import Database
from sonictune.library.models import Track
from sonictune.player.null_player import NullPlayer
from sonictune.player.queue import QueueManager


@pytest.fixture(scope="session")
def qapp():
    """QApplication instance for Qt-based tests."""
    from PySide6.QtWidgets import QApplication

    app = QApplication.instance() or QApplication([])
    yield app



@pytest.fixture
async def db(tmp_path: Path):
    d = Database(tmp_path / "test.db")
    await d.init()
    yield d
    await d.close()


@pytest.fixture
def queue() -> QueueManager:
    return QueueManager()


@pytest.fixture
def null_player() -> NullPlayer:
    return NullPlayer()


@pytest.fixture
def fake_track() -> Track:
    return Track(
        video_id="test123",
        title="Test Song",
        artist="Test Artist",
        album="Test Album",
        duration_ms=180000,
        thumbnail_url="https://example.com/art.jpg",
    )
