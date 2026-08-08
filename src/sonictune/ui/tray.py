"""System tray icon — allows minimize-to-tray."""
from __future__ import annotations

from pathlib import Path

import structlog
from PySide6.QtCore import QCoreApplication
from PySide6.QtGui import QAction, QIcon
from PySide6.QtWidgets import QMenu, QSystemTrayIcon

log = structlog.get_logger()


def _tray_icon() -> QIcon:
    """Resolve the tray icon: theme icon first, then SVG rendered to pixmap."""
    icon = QIcon.fromTheme("org.sonicTune")
    if not icon.isNull():
        return icon

    # SVG requires QSvgRenderer → QPixmap → QIcon
    from PySide6.QtSvg import QSvgRenderer
    from PySide6.QtGui import QPixmap, QPainter

    paths = [
        Path(__file__).resolve().parents[2] / "data" / "icons" / "hicolor" / "scalable" / "apps" / "org.sonicTune.svg",
        Path(__file__).resolve().parents[2] / "data" / "org.sonicTune.svg",
    ]
    for icon_path in paths:
        if icon_path.exists():
            renderer = QSvgRenderer(str(icon_path))
            pixmap = QPixmap(64, 64)
            pixmap.fill(0)  # transparent
            painter = QPainter(pixmap)
            renderer.render(painter)
            painter.end()
            return QIcon(pixmap)

    return QIcon()


class TrayIcon:
    """System tray icon with show/hide/quit actions."""

    def __init__(self, app, window) -> None:
        self._app = app
        self._window = window
        self._loop = getattr(app, 'loop', None)

        self._tray = QSystemTrayIcon(_tray_icon(), app)
        self._tray.setToolTip("SonicTune")

        menu = QMenu()
        show_action = QAction("Show", menu)
        show_action.triggered.connect(self._show_window)
        menu.addAction(show_action)

        quit_action = QAction("Quit", menu)
        quit_action.triggered.connect(self._quit_app)
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

    def _quit_app(self) -> None:
        """Properly shut down the app and stop the event loop."""
        self._tray.hide()
        if self._loop and self._loop.is_running():
            self._loop.call_soon_threadsafe(self._loop.stop)
        QCoreApplication.quit()


__all__ = ["TrayIcon"]
