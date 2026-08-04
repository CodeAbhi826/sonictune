# src/sonictune/ui/shortcuts.py
"""Configurable keyboard shortcuts (9 total)."""
from __future__ import annotations

from PySide6.QtCore import QObject
from PySide6.QtGui import QKeySequence, QShortcut


class ShortcutManager(QObject):
    def __init__(self, window, daemon_proxy) -> None:
        super().__init__(window)
        self._window = window
        self._daemon = daemon_proxy
        self._shortcuts: list[QShortcut] = []

    def register(self, config) -> None:
        for sc in self._shortcuts:
            sc.setEnabled(False)
            sc.deleteLater()
        self._shortcuts.clear()

        mappings = [
            (config.play_pause, self._daemon.playPause),
            (config.next, self._daemon.next),
            (config.previous, self._daemon.previous),
            (config.volume_up, lambda: self._daemon.setVolume(min(100, self._daemon.volume() + 5))),
            (config.volume_down, lambda: self._daemon.setVolume(max(0, self._daemon.volume() - 5))),
            (config.toggle_lyrics, self._daemon.toggleLyrics),
            (config.toggle_queue, self._daemon.toggleQueue),
            (config.toggle_mini_player, self._daemon.toggleMiniPlayer),
            (config.focus_search, self._daemon.focusSearch),
        ]

        for seq_str, callback in mappings:
            if seq_str:
                sc = QShortcut(QKeySequence(seq_str), self._window, callback)
                self._shortcuts.append(sc)
