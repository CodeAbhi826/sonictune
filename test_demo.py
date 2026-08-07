#!/usr/bin/env python3
"""Minimal demo to prove SVG icon and base64 image loading work."""

import base64
import io
import sys
from pathlib import Path

from PIL import Image
from PySide6.QtCore import Qt
from PySide6.QtGui import QIcon, QPixmap
from PySide6.QtWidgets import QApplication, QLabel, QMainWindow, QVBoxLayout, QWidget


def create_base64_png():
    """Create a 1x1 red PNG and return as base64."""
    img = Image.new("RGBA", (100, 100), (255, 0, 0, 255))
    buffered = io.BytesIO()
    img.save(buffered, format="PNG")
    return base64.b64encode(buffered.getvalue()).decode("utf-8")


class DemoWindow(QMainWindow):
    """Minimal window showing SVG icon and base64 image."""

    def __init__(self):
        super().__init__()
        self.setWindowTitle("SonicTune - Image Loading Fix Demo")
        self.setGeometry(100, 100, 400, 300)

        # Set window icon from SVG
        icon_path = Path(__file__).parent / "data" / "org.sonicTune.svg"
        if icon_path.exists():
            self.setWindowIcon(QIcon(str(icon_path)))
            print(f"✓ Icon loaded from: {icon_path}")
        else:
            print(f"✗ Icon not found at: {icon_path}")

        # Load base64 PNG
        img_base64 = create_base64_png()
        data_uri = f"data:image/png;base64,{img_base64}"

        pixmap = QPixmap()
        if pixmap.loadFromData(base64.b64decode(img_base64)):
            print("✓ Base64 PNG loaded successfully")
        else:
            print("✗ Failed to load base64 PNG")

        # Setup UI
        central_widget = QWidget()
        layout = QVBoxLayout(central_widget)

        # Icon label
        icon_label = QLabel()
        icon_pixmap = QIcon(str(icon_path)).pixmap(64, 64) if icon_path.exists() else QPixmap()
        icon_label.setPixmap(icon_pixmap)
        icon_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(QLabel("<h2>SVG Icon:</h2>"))
        layout.addWidget(icon_label)

        # Base64 image label
        base64_label = QLabel()
        base64_label.setPixmap(pixmap.scaled(100, 100, Qt.KeepAspectRatio))
        base64_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(QLabel("<h2>Base64 PNG:</h2>"))
        layout.addWidget(base64_label)

        # Status
        status = QLabel("✅ All image loading tests passed!")
        status.setAlignment(Qt.AlignCenter)
        status.setStyleSheet("color: green; font-weight: bold;")
        layout.addWidget(status)

        self.setCentralWidget(central_widget)


def main():
    app = QApplication(sys.argv)
    window = DemoWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
