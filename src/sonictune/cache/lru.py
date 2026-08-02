"""Generic in-memory LRU cache. Used for URL→path resolution."""
from __future__ import annotations

from collections import OrderedDict
from collections.abc import Callable
from threading import Lock
from typing import Generic, TypeVar

K = TypeVar("K")
V = TypeVar("V")


class LRUCache(Generic[K, V]):
    """Thread-safe LRU cache."""

    def __init__(self, max_entries: int = 1024) -> None:
        self._max = max_entries
        self._data: OrderedDict[K, V] = OrderedDict()
        self._lock = Lock()
        self._on_evict: Callable[[K, V], None] | None = None

    def set_eviction_callback(self, cb: Callable[[K, V], None]) -> None:
        self._on_evict = cb

    def get(self, key: K) -> V | None:
        with self._lock:
            if key not in self._data:
                return None
            # Mark as recently used
            self._data.move_to_end(key)
            return self._data[key]

    def put(self, key: K, value: V) -> None:
        with self._lock:
            if key in self._data:
                self._data.move_to_end(key)
                self._data[key] = value
                return
            self._data[key] = value
            if len(self._data) > self._max:
                # Evict oldest
                evicted_key, evicted_val = self._data.popitem(last=False)
                if self._on_evict:
                    try:
                        self._on_evict(evicted_key, evicted_val)
                    except Exception:
                        pass

    def remove(self, key: K) -> V | None:
        with self._lock:
            return self._data.pop(key, None)

    def clear(self) -> None:
        with self._lock:
            self._data.clear()

    def __len__(self) -> int:
        return len(self._data)

    def __contains__(self, key: object) -> bool:
        with self._lock:
            return key in self._data


__all__ = ["LRUCache"]
