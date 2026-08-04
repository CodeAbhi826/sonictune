# src/sonictune/library/local.py
"""Local file playback — scan ~/Music and read audio metadata."""
from __future__ import annotations

from pathlib import Path

import mutagen

from sonictune.library.models import Track

SUPPORTED_FORMATS = {".mp3", ".flac", ".m4a", ".ogg", ".wav", ".opus", ".wma"}

DEFAULT_MUSIC_DIR = Path.home() / "Music"


class LocalLibrary:
    def __init__(self, music_dir: Path = DEFAULT_MUSIC_DIR) -> None:
        self._music_dir = music_dir
        self._tracks: list[Track] = []

    def scan(self) -> list[Track]:
        self._tracks = []
        for ext in SUPPORTED_FORMATS:
            for file_path in self._music_dir.rglob(f"*{ext}"):
                try:
                    track = self._read_metadata(file_path)
                    if track:
                        self._tracks.append(track)
                except Exception:
                    pass
        return self._tracks

    def _read_metadata(self, path: Path) -> Track | None:
        audio = mutagen.File(str(path))
        if not audio:
            return None

        def _get(key: str, default: list[str]) -> str:
            tags = getattr(audio, "tags", None)
            if tags is not None and hasattr(tags, "get"):
                value = tags.get(key, default)
                if value:
                    return value[0]
            return default[0]

        title = _get("title", [path.stem])
        artist = _get("artist", ["Unknown Artist"])
        album = _get("album", [""])
        duration_ms = int(audio.info.length * 1000) if getattr(audio, "info", None) else 0
        return Track(
            video_id=f"local:{path.stem}",
            title=title,
            artist=artist,
            album=album,
            duration_ms=duration_ms,
            thumbnail_url="",
        )

    def get_stream_url(self, video_id: str) -> str:
        if not video_id.startswith("local:"):
            return ""
        stem = video_id.replace("local:", "")
        for ext in SUPPORTED_FORMATS:
            path = self._music_dir / f"{stem}{ext}"
            if path.exists():
                return str(path)
            for found in self._music_dir.rglob(f"{stem}{ext}"):
                return str(found)
        return ""
