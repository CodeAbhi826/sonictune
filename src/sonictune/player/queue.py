"""Queue management — owns the play queue, shuffle, repeat, history.

The QueueManager is the source of truth for "what's playing next". The
Player just plays whatever URL the queue hands it. When the player emits
END_REACHED, the daemon asks the queue for the next track.

Design:
- _tracks: list of Track objects, in queue order
- _current_index: index of the currently-playing track
- _shuffled: when shuffle is on, this is a permutation of _tracks indices
- _repeat: OFF | ALL | ONE
"""
from __future__ import annotations

import asyncio
import enum
import random
from collections.abc import Callable
from dataclasses import dataclass, field
from typing import Any

import structlog

from sonictune.library.models import Track

log = structlog.get_logger()


class RepeatMode(str, enum.Enum):
    OFF = "off"
    ALL = "all"
    ONE = "one"


@dataclass
class QueueEvent:
    """Events emitted by QueueManager."""

    type: str  # "track_added" | "track_removed" | "queue_cleared" | "current_changed" | "shuffled" | "repeat_changed"
    payload: dict[str, Any] = field(default_factory=dict)


class QueueManager:
    """Manages the play queue, shuffle state, repeat mode, and history."""

    def __init__(self) -> None:
        self._tracks: list[Track] = []
        self._shuffled_order: list[int] = []  # indices into _tracks
        self._shuffled_position: int = -1  # position within _shuffled_order
        self._shuffle: bool = False
        self._repeat: RepeatMode = RepeatMode.OFF
        self._history: list[int] = []  # indices of previously-played tracks
        self._current_index: int = -1  # explicit current position (-1 = nothing playing yet)
        self._listeners: list[Callable[[QueueEvent], Any]] = []
        self._lock = asyncio.Lock()

    # --- Listener API ------------------------------------------------------

    def add_listener(self, callback: Callable[[QueueEvent], Any]) -> None:
        self._listeners.append(callback)

    async def _emit(self, event: QueueEvent) -> None:
        for cb in list(self._listeners):
            try:
                result = cb(event)
                if asyncio.iscoroutine(result):
                    await result
            except Exception:
                log.exception("queue.listener_error")

    # --- Mutators ----------------------------------------------------------

    async def add_track(self, track: Track, at_end: bool = True) -> int:
        """Add a track to the queue. Returns its index."""
        async with self._lock:
            if at_end or not self._tracks:
                self._tracks.append(track)
                index = len(self._tracks) - 1
                # First track added becomes the current
                if self._current_index < 0:
                    self._current_index = 0
            else:
                # Insert after current
                pos = self._current_play_index() + 1
                self._tracks.insert(pos, track)
                index = pos
                # Rebuild shuffle order if active
                if self._shuffle:
                    self._rebuild_shuffle()
        await self._emit(QueueEvent("track_added", {"index": index, "track": track}))
        return index

    async def add_tracks(self, tracks: list[Track], at_end: bool = True) -> list[int]:
        """Add multiple tracks. Returns list of indices."""
        indices = []
        for t in tracks:
            indices.append(await self.add_track(t, at_end=at_end))
        return indices

    async def remove_at(self, index: int) -> Track | None:
        async with self._lock:
            if index < 0 or index >= len(self._tracks):
                return None
            track = self._tracks.pop(index)
            if self._shuffle:
                # Adjust the shuffled order: drop the removed index and
                # decrement every index above it, keeping _shuffled_position
                # pointed at the current track.
                removed_at = None
                for i, idx in enumerate(self._shuffled_order):
                    if idx == index:
                        removed_at = i
                        break
                if removed_at is not None:
                    self._shuffled_order.pop(removed_at)
                    if removed_at < self._shuffled_position:
                        self._shuffled_position -= 1
                self._shuffled_order = [
                    i - 1 if i > index else i for i in self._shuffled_order
                ]
                if self._shuffled_position >= len(self._shuffled_order):
                    self._shuffled_position = max(len(self._shuffled_order) - 1, -1)
                self._current_index = (
                    self._shuffled_order[self._shuffled_position]
                    if 0 <= self._shuffled_position < len(self._shuffled_order)
                    else -1
                )
            else:
                # Adjust current index if we removed something before/at it
                if self._current_index > index:
                    self._current_index -= 1
                elif self._current_index == index:
                    # Current was removed — clamp to valid range
                    self._current_index = min(index, len(self._tracks) - 1)
                    if not self._tracks:
                        self._current_index = -1
        await self._emit(QueueEvent("track_removed", {"index": index}))
        return track

    async def clear(self) -> None:
        async with self._lock:
            self._tracks.clear()
            self._shuffled_order.clear()
            self._shuffled_position = -1
            self._history.clear()
            self._current_index = -1
        await self._emit(QueueEvent("queue_cleared"))

    async def move(self, from_index: int, to_index: int) -> None:
        async with self._lock:
            if from_index == to_index:
                return
            if not (0 <= from_index < len(self._tracks)):
                return
            if not (0 <= to_index < len(self._tracks)):
                return
            track = self._tracks.pop(from_index)
            self._tracks.insert(to_index, track)
            if self._shuffle:
                self._rebuild_shuffle()
        await self._emit(QueueEvent("track_moved", {"from": from_index, "to": to_index}))

    # --- Shuffle / Repeat --------------------------------------------------

    async def set_shuffle(self, enabled: bool) -> None:
        async with self._lock:
            self._shuffle = enabled
            if enabled:
                self._rebuild_shuffle()
            else:
                self._shuffled_order.clear()
                self._shuffled_position = -1
        await self._emit(QueueEvent("shuffled", {"enabled": enabled}))

    async def set_repeat(self, mode: RepeatMode) -> None:
        self._repeat = mode
        await self._emit(QueueEvent("repeat_changed", {"mode": mode.value}))

    def _rebuild_shuffle(self) -> None:
        """Rebuild the shuffled order, keeping the current track at position 0."""
        if not self._tracks:
            return
        current = self._current_play_index()
        indices = list(range(len(self._tracks)))
        if current in indices:
            indices.remove(current)
        random.shuffle(indices)
        if current >= 0:
            self._shuffled_order = [current] + indices
        else:
            self._shuffled_order = indices
        self._shuffled_position = 0 if current >= 0 else -1

    # --- Navigation --------------------------------------------------------

    def _current_play_index(self) -> int:
        """Index into _tracks that's currently playing (or about to)."""
        if self._shuffle and 0 <= self._shuffled_position < len(self._shuffled_order):
            return self._shuffled_order[self._shuffled_position]
        # Linear mode — use explicit current index, defaulting to first track
        # when nothing has played yet but tracks exist.
        if self._current_index >= 0:
            return self._current_index
        return 0 if self._tracks else -1

    def current_index(self) -> int:
        return self._current_play_index()

    def current_track(self) -> Track | None:
        idx = self._current_play_index()
        if 0 <= idx < len(self._tracks):
            return self._tracks[idx]
        return None

    def next_track(self) -> Track | None:
        """Compute the next track to play. Honors repeat + shuffle.

        Returns None if the queue is empty or at the end with repeat=OFF.

        NOTE: synchronous read of internal state — only call from the event
        loop thread, or hold `_lock` (see `can_go_next()`).
        """
        if not self._tracks:
            return None
        # Repeat-one: return current
        if self._repeat == RepeatMode.ONE:
            return self.current_track()

        if self._shuffle:
            next_pos = self._shuffled_position + 1
            if next_pos < len(self._shuffled_order):
                return self._tracks[self._shuffled_order[next_pos]]
            # End of shuffle
            if self._repeat == RepeatMode.ALL:
                # Reshuffle and start over
                self._rebuild_shuffle()
                self._shuffled_position = 0
                return self._tracks[self._shuffled_order[0]] if self._shuffled_order else None
            return None

        # Linear
        current = self._current_play_index()
        if current + 1 < len(self._tracks):
            return self._tracks[current + 1]
        # End of queue
        if self._repeat == RepeatMode.ALL and self._tracks:
            return self._tracks[0]
        return None

    def prev_track(self) -> Track | None:
        """Compute the previous track to play."""
        if not self._tracks:
            return None
        if self._shuffle:
            prev_pos = self._shuffled_position - 1
            if prev_pos >= 0:
                return self._tracks[self._shuffled_order[prev_pos]]
            return None
        current = self._current_play_index()
        if current > 0:
            return self._tracks[current - 1]
        if self._repeat == RepeatMode.ALL:
            return self._tracks[-1]
        return None

    async def advance(self) -> Track | None:
        """Mark current as played, advance to next. Returns next track or None."""
        async with self._lock:
            current = self._current_play_index()
            if current >= 0:
                self._history.append(current)
            if self._shuffle:
                self._shuffled_position += 1
                if self._shuffled_position >= len(self._shuffled_order):
                    if self._repeat == RepeatMode.ALL:
                        self._rebuild_shuffle()
                    else:
                        return None
                self._current_index = self._shuffled_order[self._shuffled_position]
            else:
                # Linear: compute next index directly
                cur = self._current_index if self._current_index >= 0 else -1
                next_idx = cur + 1
                if next_idx >= len(self._tracks):
                    if self._repeat == RepeatMode.ALL and self._tracks:
                        next_idx = 0
                    else:
                        return None
                self._current_index = next_idx
            next_t = self.current_track()
        if next_t:
            await self._emit(QueueEvent("current_changed", {"track": next_t}))
        return next_t

    async def go_back(self) -> Track | None:
        async with self._lock:
            if not self._history:
                return None
            prev_idx = self._history.pop()
            if self._shuffle:
                self._shuffled_position = max(0, self._shuffled_position - 1)
            if 0 <= prev_idx < len(self._tracks):
                self._current_index = prev_idx
                track = self._tracks[prev_idx]
            else:
                track = None
        if track:
            await self._emit(QueueEvent("current_changed", {"track": track}))
        return track

    async def can_go_next(self) -> bool:
        """Thread-safe `next_track() is not None`, guarded by the queue lock."""
        async with self._lock:
            return self.next_track() is not None

    async def can_go_previous(self) -> bool:
        """Thread-safe `prev_track() is not None`, guarded by the queue lock."""
        async with self._lock:
            return self.prev_track() is not None

    # --- Setters for direct jump (used when user clicks a track) ----------

    async def jump_to(self, index: int) -> Track | None:
        async with self._lock:
            if not (0 <= index < len(self._tracks)):
                return None
            if self._shuffle:
                # Push the current track onto history so Previous can
                # return to it. Linear "range" history makes no sense in
                # shuffle mode — the shuffle order is arbitrary.
                current = self._current_play_index()
                if current >= 0 and current != index:
                    self._history.append(current)
                # Move index to front of shuffle order
                if index in self._shuffled_order:
                    self._shuffled_order.remove(index)
                self._shuffled_order.insert(0, index)
                self._shuffled_position = 0
                self._current_index = index
            else:
                # Linear mode: mark everything between old current and new
                # index as history
                old_current = self._current_index
                if old_current >= 0 and old_current < index:
                    self._history.extend(range(old_current, index))
                elif old_current < 0:
                    self._history.extend(range(index))
                self._current_index = index
            track = self._tracks[index]
        await self._emit(QueueEvent("current_changed", {"track": track}))
        return track

    # --- Getters -----------------------------------------------------------

    @property
    def shuffle(self) -> bool:
        return self._shuffle

    @property
    def repeat(self) -> RepeatMode:
        return self._repeat

    def __len__(self) -> int:
        return len(self._tracks)

    def get_tracks(self) -> list[Track]:
        return list(self._tracks)

    def get_status(self) -> dict[str, Any]:
        return {
            "tracks": [
                {
                    "video_id": t.video_id,
                    "title": t.title,
                    "artist": t.artist,
                    "album": t.album,
                    "duration_ms": t.duration_ms,
                    "thumbnail_url": t.thumbnail_url,
                }
                for t in self._tracks
            ],
            "current_index": self.current_index(),
            "shuffle": self._shuffle,
            "repeat": self._repeat.value,
            "length": len(self._tracks),
        }


__all__ = ["QueueEvent", "QueueManager", "RepeatMode"]
