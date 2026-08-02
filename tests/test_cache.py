"""Tests for sonictune.cache.lru."""
from __future__ import annotations

from sonictune.cache.lru import LRUCache


def test_lru_basic_get_put() -> None:
    cache: LRUCache[str, int] = LRUCache(max_entries=3)
    cache.put("a", 1)
    cache.put("b", 2)
    cache.put("c", 3)

    assert cache.get("a") == 1
    assert cache.get("b") == 2
    assert cache.get("c") == 3
    assert cache.get("missing") is None


def test_lru_eviction() -> None:
    """Oldest entry should be evicted when capacity is exceeded."""
    cache: LRUCache[str, int] = LRUCache(max_entries=2)
    cache.put("a", 1)
    cache.put("b", 2)
    cache.put("c", 3)  # should evict "a"

    assert cache.get("a") is None
    assert cache.get("b") == 2
    assert cache.get("c") == 3


def test_lru_access_promotes() -> None:
    """Accessing an entry should move it to the back (most recently used)."""
    cache: LRUCache[str, int] = LRUCache(max_entries=2)
    cache.put("a", 1)
    cache.put("b", 2)

    # Access "a" — it should now be the most recently used
    assert cache.get("a") == 1

    # Add "c" — should evict "b" (the least recently used), not "a"
    cache.put("c", 3)
    assert cache.get("a") == 1
    assert cache.get("b") is None
    assert cache.get("c") == 3


def test_lru_put_updates_existing() -> None:
    cache: LRUCache[str, int] = LRUCache(max_entries=2)
    cache.put("a", 1)
    cache.put("a", 100)
    assert cache.get("a") == 100
    assert len(cache) == 1


def test_lru_remove() -> None:
    cache: LRUCache[str, int] = LRUCache(max_entries=3)
    cache.put("a", 1)
    assert cache.remove("a") == 1
    assert cache.get("a") is None
    assert len(cache) == 0


def test_lru_clear() -> None:
    cache: LRUCache[str, int] = LRUCache(max_entries=3)
    cache.put("a", 1)
    cache.put("b", 2)
    cache.clear()
    assert len(cache) == 0
    assert "a" not in cache


def test_lru_eviction_callback() -> None:
    evicted: list[tuple[str, int]] = []
    cache: LRUCache[str, int] = LRUCache(max_entries=2)
    cache.set_eviction_callback(lambda k, v: evicted.append((k, v)))

    cache.put("a", 1)
    cache.put("b", 2)
    cache.put("c", 3)  # evicts "a"

    assert evicted == [("a", 1)]


def test_lru_contains() -> None:
    cache: LRUCache[str, int] = LRUCache(max_entries=3)
    cache.put("a", 1)
    assert "a" in cache
    assert "b" not in cache
