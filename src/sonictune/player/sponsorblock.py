# src/sonictune/player/sponsorblock.py
"""SponsorBlock integration — skip sponsor/intro/outro segments."""
from __future__ import annotations

import aiohttp
import structlog

log = structlog.get_logger()
SPONSORBLOCK_API = "https://sponsor.ajay.app/api/skipSegments"


class SponsorBlock:
    def __init__(self, enabled: bool = True, categories: list[str] | None = None) -> None:
        self.enabled = enabled
        self.categories = categories or ["sponsor", "intro", "outro", "selfpromo", "music_offtopic"]
        self._cache: dict[str, list[tuple[float, float]]] = {}

    async def get_segments(self, video_id: str) -> list[tuple[float, float]]:
        if not self.enabled or not video_id:
            return []
        if video_id in self._cache:
            return self._cache[video_id]

        try:
            async with aiohttp.ClientSession() as session:
                params = {"videoID": video_id, "categories": str(self.categories).replace("'", '"')}
                async with session.get(SPONSORBLOCK_API, params=params, timeout=5) as resp:
                    if resp.status != 200:
                        return []
                    data = await resp.json()
                    segments = [(item["segment"][0], item["segment"][1]) for item in data]
                    self._cache[video_id] = segments
                    return segments
        except Exception as e:
            log.warning("sponsorblock.fetch_failed", error=str(e))
            return []

    def should_skip(self, video_id: str, position_ms: int) -> int | None:
        if not self.enabled:
            return None
        if video_id not in self._cache:
            return None
        pos_sec = position_ms / 1000
        for start, end in self._cache[video_id]:
            if start <= pos_sec < end:
                return int(end * 1000)
        return None
