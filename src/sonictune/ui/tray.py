"""System tray icon — allows minimize-to-tray."""
from __future__ import annotations

import structlog
from PySide6.QtGui import QAction, QIcon
from PySide6.QtWidgets import QMenu, QSystemTrayIcon

log = structlog.get_logger()


class TrayIcon:
    """System tray icon with show/hide/quit actions."""

    def __init__(self, app, window) -> None:
        self._app = app
        self._window = window

        self._tray = QSystemTrayIcon(QIcon.fromTheme("org.sonicTune"), app)
        self._tray.setToolTip("SonicTune")

        menu = QMenu()
        show_action = QAction("Show", menu)
        show_action.triggered.connect(self._show_window)
        menu.addAction(show_action)

        quit_action = QAction("Quit", menu)
        quit_action.triggered.connect(app.quit)
        menu.addAction(quit_action)

        self._tray.setContextMenu(menu)
        self._tray.activated.connect(self._on_activated)

    def show(self) -> None:
        self._tray.show()

    def _on_activated(self, reason) -> None:
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            self._show_window()

    def _show_window(self) -> None:
        self._window.show()
        self._window.raise_()
        self._window.activateWindow()


__all__ = ["TrayIcon"]
