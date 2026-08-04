"""Tests for Mini Player (T-018 to T-019)."""
from __future__ import annotations

import os

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from unittest.mock import MagicMock

from PySide6.QtQml import QQmlEngine
from PySide6.QtWidgets import QApplication

from sonictune.ui.mini_player import MiniPlayerWindow


def test_mini_player_show() -> None:
    """T-018: MiniPlayerWindow.show() creates QQuickView."""
    QApplication.instance() or QApplication([])
    engine = QQmlEngine()
    daemon = MagicMock()
    mp = MiniPlayerWindow(engine, daemon)
    mp.show()
    assert mp._window is not None


def test_mini_player_toggle() -> None:
    """T-019: MiniPlayerWindow.toggle() hides when visible."""
    QApplication.instance() or QApplication([])
    engine = QQmlEngine()
    daemon = MagicMock()
    mp = MiniPlayerWindow(engine, daemon)
    mp.show()
    mp.toggle()
    assert mp.is_visible() is False
    mp.toggle()
    assert mp.is_visible() is True
