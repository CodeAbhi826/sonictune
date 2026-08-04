# src/sonictune/ui/mini_player.py
"""Compact floating mini player window (320x80, always on top)."""
from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt, QUrl
from PySide6.QtQuick import QQuickView
from PySide6.QtWidgets import QApplication

_MINI_PLAYER_QML = Path(__file__).resolve().parent / "qml" / "MiniPlayer.qml"


class MiniPlayerWindow:
    def __init__(self, engine, daemon_proxy) -> None:
        self._window: QQuickView | None = None
        self._engine = engine
        self._daemon = daemon_proxy

    def show(self) -> None:
        if self._window:
            self._window.show()
            self._window.raise_()
            self._window.requestActivate()
            return

        self._window = QQuickView(self._engine, None)
        self._engine.addImportPath(str(Path(__file__).resolve().parent / "qml"))
        if _MINI_PLAYER_QML.exists():
            self._window.setSource(QUrl.fromLocalFile(str(_MINI_PLAYER_QML)))
        else:
            self._window.setSource(QUrl("qrc:/qml/MiniPlayer.qml"))
        self._window.setFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
        )
        from PySide6.QtCore import QSize
        self._window.setMinimumSize(QSize(320, 80))
        self._window.setMaximumSize(QSize(400, 80))
        screen = QApplication.primaryScreen().geometry()
        self._window.setPosition(screen.width() - 420, screen.height() - 120)
        self._window.show()

    def hide(self) -> None:
        if self._window:
            self._window.hide()

    def toggle(self) -> None:
        if self._window and self._window.isVisible():
            self.hide()
        else:
            self.show()

    def is_visible(self) -> bool:
        return self._window is not None and self._window.isVisible()
