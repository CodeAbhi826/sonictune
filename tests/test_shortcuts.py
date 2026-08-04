"""Tests for Shortcut Manager (T-016 to T-017)."""
from __future__ import annotations

import os

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from unittest.mock import MagicMock

from PySide6.QtWidgets import QApplication, QWidget

from sonictune.config import ShortcutsConfig
from sonictune.ui.shortcuts import ShortcutManager


def test_shortcut_manager_registration() -> None:
    """T-016: ShortcutManager registers all 9 shortcuts."""
    QApplication.instance() or QApplication([])
    window = QWidget()
    daemon = MagicMock()
    mgr = ShortcutManager(window, daemon)
    cfg = ShortcutsConfig()
    mgr.register(cfg)
    assert len(mgr._shortcuts) == 9


def test_shortcut_manager_no_duplicates() -> None:
    """T-017: ShortcutManager replaces old shortcuts on re-register."""
    QApplication.instance() or QApplication([])
    window = QWidget()
    daemon = MagicMock()
    mgr = ShortcutManager(window, daemon)
    cfg = ShortcutsConfig()
    mgr.register(cfg)
    first_count = len(mgr._shortcuts)
    mgr.register(cfg)
    assert len(mgr._shortcuts) == 9
    assert len(mgr._shortcuts) == first_count
