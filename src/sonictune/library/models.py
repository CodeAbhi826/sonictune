"""Data models for music entities.

These are typed, normalized views of what ytmusicapi returns. ytmusicapi
returns dicts with inconsistent keys (some camelCase, some snake_case,
some optional), so we wrap them in dataclasses with sensible defaults.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


def _duration_ms(data: dict[str, Any]) -> int:
    """Extract duration in ms from a ytmusicapi result dict.

    Handles ``duration_seconds`` (int or "3:45" string), a bare ``duration``
    key (some endpoints return seconds or an ISO-ish string), and missing
    values (falls back to 0).
    """
    duration_seconds = data.get("duration_seconds") or data.get("duration")
    if duration_seconds is None:
        return 0
    if isinstance(duration_seconds, str):
        parts = [int(p) for p in duration_seconds.split(":") if p.isdigit()]
        if not parts:
            return 0
        total = 0
        for part in parts:
            total = total * 60 + part
        return total * 1000
    try:
        return int(float(duration_seconds) * 1000)
    except (TypeError, ValueError):
        return 0


@dataclass(slots=True)
class Track:
    """A single playable track."""

    video_id: str
    title: str
    artist: str = ""
    artist_id: str = ""
    album: str = ""
    album_id: str = ""
    duration_ms: int = 0
    thumbnail_url: str = ""
    is_explicit: bool = False
    itag: int = 0  # filled in by player when streaming URL resolved

    @classmethod
    def from_ytmusic(cls, data: dict[str, Any]) -> Track:
        """Build a Track from a ytmusicapi search/result dict."""
        artists = data.get("artists") or []
        primary_artist = artists[0] if artists else {}
        album = data.get("album") or {}

        return cls(
            video_id=data.get("videoId", ""),
            title=data.get("title", "Unknown"),
            artist=primary_artist.get("name", "Unknown Artist"),
            artist_id=primary_artist.get("id", ""),
            album=album.get("name", ""),
            album_id=album.get("id", ""),
            duration_ms=_duration_ms(data),
            thumbnail_url=_pick_thumbnail(data.get("thumbnails", [])),
            is_explicit=bool(data.get("isExplicit", False)),
        )


@dataclass(slots=True)
class Album:
    browse_id: str
    title: str
    artist: str = ""
    artist_id: str = ""
    year: int = 0
    thumbnail_url: str = ""
    track_count: int = 0
    tracks: list[Track] = field(default_factory=list)

    @classmethod
    def from_ytmusic(cls, data: dict[str, Any]) -> Album:
        return cls(
            browse_id=data.get("browseId", ""),
            title=data.get("title", "Unknown Album"),
            artist=data.get("artists", [{}])[0].get("name", ""),
            artist_id=data.get("artists", [{}])[0].get("id", ""),
            year=int(data.get("year", 0) or 0),
            thumbnail_url=_pick_thumbnail(data.get("thumbnails", [])),
            track_count=int(data.get("trackCount", 0) or 0),
        )


@dataclass(slots=True)
class Artist:
    channel_id: str
    name: str
    thumbnail_url: str = ""
    subscriber_count: int = 0

    @classmethod
    def from_ytmusic(cls, data: dict[str, Any]) -> Artist:
        return cls(
            channel_id=data.get("browseId", data.get("channelId", "")),
            name=data.get("artist", data.get("title", "Unknown Artist")),
            thumbnail_url=_pick_thumbnail(data.get("thumbnails", [])),
            subscriber_count=int(data.get("subscribers", "0").split(" ")[0].replace(",", "") or 0)
            if "subscribers" in data
            else 0,
        )


@dataclass(slots=True)
class Playlist:
    playlist_id: str
    title: str
    description: str = ""
    thumbnail_url: str = ""
    track_count: int = 0
    owner: str = ""

    @classmethod
    def from_ytmusic(cls, data: dict[str, Any]) -> Playlist:
        return cls(
            playlist_id=data.get("playlistId", data.get("browseId", "")),
            title=data.get("title", "Unknown Playlist"),
            description=data.get("description", ""),
            thumbnail_url=_pick_thumbnail(data.get("thumbnails", [])),
            track_count=int(data.get("trackCount", 0) or 0),
            owner=data.get("author", [{}])[0].get("name", "") if isinstance(data.get("author"), list)
            else data.get("author", ""),
        )


def _pick_thumbnail(thumbnails: list[dict[str, Any]]) -> str:
    """Pick the highest-quality thumbnail URL from ytmusicapi's list."""
    if not thumbnails:
        return ""
    return thumbnails[-1].get("url", "")


__all__ = ["Album", "Artist", "Playlist", "Track"]
