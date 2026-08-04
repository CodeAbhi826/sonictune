"""Tests for Social features (T-037 to T-039)."""
from __future__ import annotations

import asyncio
from unittest.mock import AsyncMock

from sonictune.social.feed import ActivityEvent
from sonictune.social.profile import UserProfile
from sonictune.social.sync import ListeningRoom


def test_user_profile_dataclass() -> None:
    """T-037: UserProfile initializes with defaults."""
    p = UserProfile(user_id="u1", display_name="Test")
    assert p.user_id == "u1"
    assert p.display_name == "Test"
    assert p.is_public is True
    assert p.total_plays == 0
    assert isinstance(p.top_tracks, list)


def test_activity_event_dataclass() -> None:
    """T-038: ActivityEvent initializes with defaults."""
    e = ActivityEvent(user_id="u1", user_name="Test", event_type="play")
    assert e.user_id == "u1"
    assert e.event_type == "play"
    assert e.track_id == ""


def test_listening_room_broadcast() -> None:
    """T-039: ListeningRoom.broadcast sends message to participants."""
    room = ListeningRoom("room1", "host1")
    mock_ws = AsyncMock()
    room.participants["user1"] = mock_ws
    asyncio.run(room.broadcast({"type": "test"}))
    mock_ws.send.assert_called_once()
