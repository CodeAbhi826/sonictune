# src/sonictune/social/feed.py
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class ActivityEvent:
    user_id: str
    user_name: str
    event_type: str
    track_id: str = ""
    track_title: str = ""
    track_artist: str = ""
    timestamp: datetime = field(default_factory=datetime.utcnow)
    thumbnail_url: str = ""
