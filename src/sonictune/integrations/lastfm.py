# src/sonictune/integrations/lastfm.py
"""Last.fm scrobbling — OAuth session key + now playing / scrobble."""
from __future__ import annotations

import hashlib

import aiohttp
import structlog

log = structlog.get_logger()
LASTFM_API = "https://ws.audioscrobbler.com/2.0/"


class LastFmScrobbler:
    def __init__(self, api_key: str, api_secret: str, session_key: str = "") -> None:
        self._api_key = api_key
        self._api_secret = api_secret
        self._session_key = session_key
        self._enabled = bool(session_key)

    def _sign(self, params: dict[str, str]) -> str:
        sig = "".join(k + params[k] for k in sorted(params.keys()))
        sig += self._api_secret
        return hashlib.md5(sig.encode()).hexdigest()

    async def scrobble(
        self, artist: str, title: str, timestamp: int, album: str = "", duration: int = 0
    ) -> bool:
        if not self._enabled:
            return False
        params = {
            "method": "track.scrobble",
            "api_key": self._api_key,
            "sk": self._session_key,
            "artist": artist,
            "track": title,
            "timestamp": str(timestamp),
            "album": album,
            "duration": str(duration),
            "format": "json",
        }
        params["api_sig"] = self._sign(params)
        try:
            async with aiohttp.ClientSession() as session, session.post(LASTFM_API, data=params, timeout=10) as resp:
                data = await resp.json()
                if "error" in data:
                    log.warning("lastfm.scrobble_error", error=data.get("message"))
                    return False
                log.info("lastfm.scrobbled", artist=artist, track=title)
                return True
        except Exception as e:
            log.warning("lastfm.scrobble_failed", error=str(e))
            return False

    async def now_playing(self, artist: str, title: str, album: str = "", duration: int = 0) -> bool:
        if not self._enabled:
            return False
        params = {
            "method": "track.updateNowPlaying",
            "api_key": self._api_key,
            "sk": self._session_key,
            "artist": artist,
            "track": title,
            "album": album,
            "duration": str(duration),
            "format": "json",
        }
        params["api_sig"] = self._sign(params)
        try:
            async with aiohttp.ClientSession() as session, session.post(LASTFM_API, data=params, timeout=10) as resp:
                return "error" not in await resp.json()
        except Exception:
            return False
