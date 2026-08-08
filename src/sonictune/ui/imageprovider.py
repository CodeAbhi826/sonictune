"""QQuickImageProvider for album art — direct ArtCache access."""
from __future__ import annotations

import threading
import urllib.parse
from pathlib import Path

import structlog
from PIL import Image
from PySide6.QtCore import QSize
from PySide6.QtGui import QImage, QPixmap
from PySide6.QtQuick import QQuickImageProvider

log = structlog.get_logger()


class ArtImageProvider(QQuickImageProvider):
    """Provides album art to QML via `image://art/<url>`.

    ``requestImage`` must never block the render thread on a network fetch:
    disk-cached art returns instantly, uncached URLs return an empty image
    and are downloaded in a background thread so the next request hits disk.
    """

    def __init__(self, art_cache) -> None:
        super().__init__(QQuickImageProvider.ImageType.Image)
        self._cache = art_cache
        self._pixmap_cache: dict[str, QPixmap] = {}
        self._cache_order: list[str] = []
        self._max_cache = 200
        self._pending_fetches: set[str] = set()
        self._fetch_lock = threading.Lock()

    def _store_pixmap(self, url: str, pixmap: QPixmap) -> None:
        self._pixmap_cache[url] = pixmap
        self._cache_order.append(url)
        if len(self._cache_order) > self._max_cache:
            old = self._cache_order.pop(0)
            self._pixmap_cache.pop(old, None)

    def _start_background_fetch(self, url: str) -> None:
        """Download art off the render thread; skip if already in flight."""
        with self._fetch_lock:
            if url in self._pending_fetches:
                return
            self._pending_fetches.add(url)

        def _bg_fetch() -> None:
            try:
                self._cache.get_sync(url)
            except Exception as e:
                log.debug("image_provider.bg_fetch_failed", url=url, error=str(e))
            finally:
                with self._fetch_lock:
                    self._pending_fetches.discard(url)

        threading.Thread(target=_bg_fetch, daemon=True, name="art-fetch").start()

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

        # 1. Pixmap cache — instant
        if url in self._pixmap_cache:
            return self._pixmap_cache[url].toImage()

        # 2. Data URIs — instant, no network
        img = self._load_data_uri(url)
        if img is not None:
            try:
                if img.mode != "RGBA":
                    img = img.convert("RGBA")
                qimg = QImage(img.tobytes(), img.size[0], img.size[1], QImage.Format.Format_RGBA8888)
                self._store_pixmap(url, QPixmap.fromImage(qimg))
                return qimg
            except Exception:
                return QImage()

        # 3. HTTP/HTTPS URLs — must download, can't load as local files
        if url.startswith("http://") or url.startswith("https://"):
            # Check disk cache first
            try:
                path = self._cache._url_to_path(url)
                if path and Path(path).exists():
                    pixmap = QPixmap(str(path))
                    self._store_pixmap(url, pixmap)
                    return pixmap.toImage()
            except Exception:
                pass

            # Return empty immediately, background thread will fetch
            self._start_background_fetch(url)
            return QImage()

        # 4. Local file path fallback
        if Path(url).exists():
            try:
                pixmap = QPixmap(url)
                self._store_pixmap(url, pixmap)
                return pixmap.toImage()
            except Exception:
                pass

        # 5. Not cached anywhere — return empty and let background fetch
        self._start_background_fetch(url)
        return QImage()


__all__ = ["ArtImageProvider"]
