# src/sonictune/social/profile.py
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class UserProfile:
    user_id: str
    display_name: str
    avatar_url: str = ""
    is_public: bool = True
    created_at: datetime = field(default_factory=datetime.utcnow)
    total_plays: int = 0
    total_hours: float = 0.0
    top_tracks: list[dict] = field(default_factory=list)
    top_artists: list[dict] = field(default_factory=list)
    recently_played: list[dict] = field(default_factory=list)
