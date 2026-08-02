"""Clipboard helper for QML.

QML doesn't have a built-in clipboard API, so we expose Qt's clipboard
via a QObject with a Slot.
"""
from __future__ import annotations

from PySide6.QtCore import QObject, Slot
from PySide6.QtGui import QGuiApplication


class ClipboardHelper(QObject):
    """Exposes Qt clipboard to QML."""

    @Slot(str)
    def copy(self, text: str) -> None:
        """Copy text to the system clipboard."""
        QGuiApplication.clipboard().setText(text)
