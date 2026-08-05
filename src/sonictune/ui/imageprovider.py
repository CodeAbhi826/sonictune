"""QQuickImageProvider for album art — direct ArtCache access."""
from __future__ import annotations

import urllib.parse
from pathlib import Path

import structlog
from PIL import Image
from PySide6.QtCore import QSize
from PySide6.QtGui import QImage, QPixmap
from PySide6.QtQuick import QQuickImageProvider

log = structlog.get_logger()


class ArtImageProvider(QQuickImageProvider):
    """Provides album art to QML via `image://art/<url>`."""

    def __init__(self, art_cache) -> None:
        super().__init__(QQuickImageProvider.ImageType.Image)
        self._cache = art_cache
        self._pixmap_cache: dict[str, QPixmap] = {}
        self._cache_order: list[str] = []
        self._max_cache = 200

    def _load_data_uri(self, url: str) -> Image.Image | None:
        """Load an image from a data URI (e.g., data:image/png;base64,...)."""
        if not url.startswith("data:image/"):
            return None

        try:
            # Extract base64 data
            header, data = url.split(",", 1)
            if ";base64" in header:
                import base64
                import io

                from PIL import Image

                # Decode base64 and load via PIL
                img_data = base64.b64decode(data)
                return Image.open(io.BytesIO(img_data))
        except Exception as e:
            log.debug("image_provider.data_uri_failed", url=url, error=str(e))
            return None

    def requestImage(self, id_: str, size: QSize, requestedSize: QSize) -> QImage:
        url = urllib.parse.unquote(id_)
        if not url:
            return QImage()

        # Check pixmap cache
        if url in self._pixmap_cache:
            return self._pixmap_cache[url].toImage()

        # Handle data URIs
        img = self._load_data_uri(url)
        if img is not None:
            try:
                # Convert to QImage
                if img.mode != "RGBA":
                    img = img.convert("RGBA")
                qimg = QImage(
                    img.tobytes(),
                    img.size[0],
                    img.size[1],
                    QImage.Format.Format_RGBA8888
                )

                # Cache the pixmap
                pixmap = QPixmap.fromImage(qimg)
                self._pixmap_cache[url] = pixmap
                self._cache_order.append(url)
                if len(self._cache_order) > self._max_cache:
                    old = self._cache_order.pop(0)
                    self._pixmap_cache.pop(old, None)
                return qimg
            except Exception as e:
                log.debug("image_provider.data_uri_convert_failed", url=url, error=str(e))
                return QImage()

        # Fetch via ArtCache (sync — ArtCache handles its own threading)
        try:
            path = self._cache.get_sync(url)
            if path and Path(path).exists():
                pixmap = QPixmap(str(path))
                self._pixmap_cache[url] = pixmap
                self._cache_order.append(url)
                if len(self._cache_order) > self._max_cache:
                    old = self._cache_order.pop(0)
                    self._pixmap_cache.pop(old, None)
                return pixmap.toImage()
        except Exception as e:
            log.debug("image_provider.fetch_failed", url=url, error=str(e))

        return QImage()


__all__ = ["ArtImageProvider"]
