# src/sonictune/social/sync.py
from __future__ import annotations

import json
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import websockets


class ListeningRoom:
    def __init__(self, room_id: str, host_user_id: str) -> None:
        self.room_id = room_id
        self.host_user_id = host_user_id
        self.participants: dict[str, websockets.WebSocketServerProtocol] = {}
        self.current_track: dict = {}
        self.is_playing: bool = False
        self.position_ms: int = 0

    async def broadcast(self, message: dict) -> None:
        dead = []
        for user_id, ws in self.participants.items():
            try:
                await ws.send(json.dumps(message))
            except Exception:
                dead.append(user_id)
        for user_id in dead:
            del self.participants[user_id]

    async def sync_play(self, track_id: str, position_ms: int) -> None:
        self.current_track = {"video_id": track_id}
        self.is_playing = True
        self.position_ms = position_ms
        await self.broadcast({
            "type": "play",
            "track_id": track_id,
            "position_ms": position_ms,
        })
