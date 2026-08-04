# src/sonictune/ui/performance_flags.py

from __future__ import annotations

from PySide6.QtCore import Property, QObject, Signal

from sonictune.performance import PerformanceProfile


class PerformanceFlags(QObject):
    changed = Signal()

    def __init__(self, profile: PerformanceProfile) -> None:
        super().__init__()
        self._profile = profile

    @Property(bool, notify=changed)
    def reducedMotion(self) -> bool:
        return self._profile.reduced_motion

    @Property(bool, notify=changed)
    def lowEndMode(self) -> bool:
        return self._profile.low_end_mode

    @Property(bool, notify=changed)
    def disableShadows(self) -> bool:
        return self._profile.disable_shadows

    @Property(bool, notify=changed)
    def disableImageCache(self) -> bool:
        return self._profile.disable_image_cache

    @Property(int, notify=changed)
    def imageSourceSize(self) -> int:
        return self._profile.image_source_size

    @Property(int, notify=changed)
    def listCacheBuffer(self) -> int:
        return self._profile.list_cache_buffer

    @Property(bool, notify=changed)
    def smoothScrolling(self) -> bool:
        return self._profile.smooth_scrolling

    @Property(bool, notify=changed)
    def preloadEnabled(self) -> bool:
        return self._profile.preload_enabled

    @Property(int, notify=changed)
    def audioCacheMb(self) -> int:
        return self._profile.audio_cache_mb

    def update(self, profile: PerformanceProfile) -> None:
        self._profile = profile
        self.changed.emit()
