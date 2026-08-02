"""Tests for sonictune.player.queue."""
from __future__ import annotations

import pytest

from sonictune.library.models import Track
from sonictune.player.queue import QueueManager, RepeatMode


def make_track(video_id: str, title: str = "Test") -> Track:
    return Track(video_id=video_id, title=title, artist="Artist")


@pytest.fixture
def queue() -> QueueManager:
    return QueueManager()


async def test_queue_add_and_get_current(queue: QueueManager) -> None:
    t1 = make_track("vid1", "Track 1")
    t2 = make_track("vid2", "Track 2")

    await queue.add_track(t1)
    await queue.add_track(t2)

    assert len(queue) == 2
    assert queue.current_track() is not None
    assert queue.current_track().video_id == "vid1"


async def test_queue_next_in_linear_mode(queue: QueueManager) -> None:
    t1 = make_track("vid1")
    t2 = make_track("vid2")
    t3 = make_track("vid3")

    await queue.add_tracks([t1, t2, t3])

    # Initially current = first; next should be second
    next_t = queue.next_track()
    assert next_t is not None
    assert next_t.video_id == "vid2"


async def test_queue_advance(queue: QueueManager) -> None:
    t1 = make_track("vid1")
    t2 = make_track("vid2")
    await queue.add_tracks([t1, t2])

    # Advance should return t2
    next_t = await queue.advance()
    assert next_t is not None
    assert next_t.video_id == "vid2"


async def test_queue_repeat_all_wraps_around(queue: QueueManager) -> None:
    t1 = make_track("vid1")
    t2 = make_track("vid2")
    await queue.add_tracks([t1, t2])
    await queue.set_repeat(RepeatMode.ALL)

    # Advance past end — should wrap to t1
    await queue.advance()
    next_t = await queue.advance()
    assert next_t is not None
    assert next_t.video_id == "vid1"


async def test_queue_repeat_one_returns_current(queue: QueueManager) -> None:
    t1 = make_track("vid1")
    t2 = make_track("vid2")
    await queue.add_tracks([t1, t2])
    await queue.set_repeat(RepeatMode.ONE)

    next_t = queue.next_track()
    assert next_t is not None
    assert next_t.video_id == "vid1"  # same as current


async def test_queue_clear(queue: QueueManager) -> None:
    await queue.add_track(make_track("vid1"))
    await queue.clear()
    assert len(queue) == 0
    assert queue.current_track() is None


async def test_queue_remove_at(queue: QueueManager) -> None:
    t1, t2, t3 = make_track("vid1"), make_track("vid2"), make_track("vid3")
    await queue.add_tracks([t1, t2, t3])

    removed = await queue.remove_at(1)
    assert removed is not None
    assert removed.video_id == "vid2"
    assert len(queue) == 2


async def test_queue_jump_to(queue: QueueManager) -> None:
    t1, t2, t3 = make_track("vid1"), make_track("vid2"), make_track("vid3")
    await queue.add_tracks([t1, t2, t3])

    track = await queue.jump_to(2)
    assert track is not None
    assert track.video_id == "vid3"
    assert queue.current_index() == 2


async def test_queue_shuffle_keeps_all_tracks(queue: QueueManager) -> None:
    tracks = [make_track(f"vid{i}", f"Track {i}") for i in range(10)]
    await queue.add_tracks(tracks)

    await queue.set_shuffle(True)
    assert queue.shuffle is True

    # All tracks should still be present
    queue_tracks = queue.get_tracks()
    assert len(queue_tracks) == 10
    assert {t.video_id for t in queue_tracks} == {f"vid{i}" for i in range(10)}


async def test_queue_status_payload(queue: QueueManager) -> None:
    t1 = make_track("vid1", "Track 1")
    await queue.add_track(t1)

    status = queue.get_status()
    assert status["length"] == 1
    assert status["shuffle"] is False
    assert status["repeat"] == "off"
    assert len(status["tracks"]) == 1
    assert status["tracks"][0]["video_id"] == "vid1"


async def test_queue_jump_to_shuffle_pushes_current_to_history(queue: QueueManager) -> None:
    t1, t2, t3 = make_track("vid1"), make_track("vid2"), make_track("vid3")
    await queue.add_tracks([t1, t2, t3])
    await queue.set_shuffle(True)

    # Start at t1 (index 0), jump to t3 (index 2) — t1 must go to history.
    await queue.jump_to(2)
    assert queue.current_index() == 2

    prev = await queue.go_back()
    assert prev is not None
    assert prev.video_id == "vid1"


async def test_queue_jump_to_shuffle_resets_position(queue: QueueManager) -> None:
    t1, t2, t3 = make_track("vid1"), make_track("vid2"), make_track("vid3")
    await queue.add_tracks([t1, t2, t3])
    await queue.set_shuffle(True)

    await queue.advance()
    await queue.jump_to(0)
    # Jumped track is now at the front of the shuffle order.
    assert queue.current_track() is not None
    assert queue.current_track().video_id == "vid1"


async def test_queue_remove_at_adjusts_shuffled_position(queue: QueueManager) -> None:
    tracks = [make_track(f"vid{i}", f"Track {i}") for i in range(5)]
    await queue.add_tracks(tracks)
    await queue.set_shuffle(True)

    current_before = queue.current_track()
    assert current_before is not None

    # Remove a track that is NOT current; state must stay consistent.
    removed = await queue.remove_at(3)
    assert removed is not None
    assert len(queue) == 4
    assert queue.current_track() is not None
    assert queue.current_index() in range(4)


async def test_queue_remove_at_after_current_index_linear(queue: QueueManager) -> None:
    t1, t2, t3 = make_track("vid1"), make_track("vid2"), make_track("vid3")
    await queue.add_tracks([t1, t2, t3])

    await queue.advance()  # current -> t2 (index 1)
    await queue.remove_at(2)  # remove t3 after current
    assert len(queue) == 2
    assert queue.current_index() == 1
    assert queue.current_track().video_id == "vid2"
