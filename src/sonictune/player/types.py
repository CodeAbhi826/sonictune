"""Player types shared between MpvPlayer and NullPlayer.

Lives in a separate module so NullPlayer can be imported without needing
libmpv installed.
"""
from __future__ import annotations

import enum
from dataclasses import dataclass


class PlayerState(str, enum.Enum):
    IDLE = "idle"
    LOADING = "loading"
    PLAYING = "playing"
    PAUSED = "paused"
    STOPPED = "stopped"
    ERROR = "error"


class PlayerEvent(str, enum.Enum):
    STATE_CHANGED = "state_changed"
    TRACK_CHANGED = "track_changed"
    POSITION_CHANGED = "position_changed"
    VOLUME_CHANGED = "volume_changed"
    END_REACHED = "end_reached"
    ERROR = "error"


@dataclass
class TrackInfo:
    """Info about the currently-loaded track (set by daemon when loading)."""

    video_id: str = ""
    title: str = ""
    artist: str = ""
    album: str = ""
    duration_ms: int = 0
    thumbnail_url: str = ""


__all__ = ["PlayerEvent", "PlayerState", "TrackInfo"]
