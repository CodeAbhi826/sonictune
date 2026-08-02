"""Discord Rich Presence integration via pypresence.

Users must provide their own Discord application client_id (create one
at https://discord.com/developers/applications).
"""
from __future__ import annotations

import asyncio
import time
from typing import Any

import structlog

log = structlog.get_logger()


class DiscordRPC:
    """Manages Discord Rich Presence connection."""

    def __init__(self, client_id: str) -> None:
        self._client_id = client_id
        self._client: Any = None  # pypresence.Presence
        self._connected: bool = False
        self._current_state: dict[str, Any] = {}
        self._update_lock = asyncio.Lock()

    async def connect(self) -> None:
        if not self._client_id:
            log.warning("discord.no_client_id")
            return

        try:
            from pypresence import Presence
        except ImportError:
            log.warning("discord.pypresence_not_installed")
            return

        def _connect() -> Any:
            presence = Presence(self._client_id)
            presence.connect()
            return presence

        try:
            self._client = await asyncio.to_thread(_connect)
            self._connected = True
            log.info("discord.connected", client_id=self._client_id)
        except Exception as e:
            log.warning("discord.connect_failed", error=str(e))

    async def close(self) -> None:
        if self._client:
            try:
                await asyncio.to_thread(self._client.close)
            except Exception:
                pass
            self._client = None
            self._connected = False
            log.info("discord.closed")

    async def update(
        self,
        title: str,
        artist: str,
        album: str | None = None,
        thumbnail_url: str | None = None,
        duration_ms: int | None = None,
        position_ms: int | None = None,
        paused: bool = False,
    ) -> None:
        """Update Discord presence with current track info."""
        if not self._connected or not self._client:
            return

        async with self._update_lock:
            self._current_state = {
                "title": title,
                "artist": artist,
                "album": album,
                "thumbnail_url": thumbnail_url,
                "duration_ms": duration_ms,
                "position_ms": position_ms,
                "paused": paused,
            }

            # Build payload
            now = int(time.time())
            payload: dict[str, Any] = {
                "state": f"by {artist}"[:128],
                "details": title[:128],
                "large_image": "sonictune",
                "large_text": "SonicTune"[:128],
                "small_image": "paused" if paused else "playing",
                "small_text": "Paused" if paused else "Playing",
            }

            if not paused and duration_ms and position_ms is not None:
                start = now - (position_ms // 1000)
                end = start + (duration_ms // 1000)
                payload["start"] = start
                payload["end"] = end

            try:
                await asyncio.to_thread(self._client.update, **payload)
            except Exception as e:
                log.warning("discord.update_failed", error=str(e))

    async def clear(self) -> None:
        if self._connected and self._client:
            try:
                await asyncio.to_thread(self._client.clear)
            except Exception:
                pass


__all__ = ["DiscordRPC"]
