# src/sonictune/player/sleep_timer.py
"""Sleep timer with 6 modes (5/15/30/45/60 min + end of track)."""
from __future__ import annotations

import asyncio
from enum import Enum


class SleepTimerMode(Enum):
    OFF = "off"
    MINUTES_5 = "5min"
    MINUTES_15 = "15min"
    MINUTES_30 = "30min"
    MINUTES_45 = "45min"
    MINUTES_60 = "60min"
    END_OF_TRACK = "end_of_track"


class SleepTimer:
    def __init__(self, player) -> None:
        self._player = player
        self._mode = SleepTimerMode.OFF
        self._task: asyncio.Task | None = None
        self._remaining_ms: int = 0

    def set_mode(self, mode: SleepTimerMode) -> None:
        self._mode = mode
        if self._task:
            self._task.cancel()
            self._task = None

        if mode == SleepTimerMode.OFF:
            self._remaining_ms = 0
            return

        if mode == SleepTimerMode.END_OF_TRACK:
            self._remaining_ms = 0
            return

        minutes = {
            SleepTimerMode.MINUTES_5: 5,
            SleepTimerMode.MINUTES_15: 15,
            SleepTimerMode.MINUTES_30: 30,
            SleepTimerMode.MINUTES_45: 45,
            SleepTimerMode.MINUTES_60: 60,
        }.get(mode, 0)

        self._remaining_ms = minutes * 60 * 1000
        if minutes > 0:
            try:
                asyncio.get_running_loop()
            except RuntimeError:
                # No running loop (e.g. sync test context) — the countdown
                # starts as soon as a loop is available via set_mode again.
                self._task = None
                return
            self._task = asyncio.create_task(self._countdown())

    async def _countdown(self) -> None:
        while self._remaining_ms > 0:
            await asyncio.sleep(1)
            self._remaining_ms -= 1000
        await self._player.stop()

    @property
    def is_active(self) -> bool:
        return self._mode != SleepTimerMode.OFF

    def get_remaining_text(self) -> str:
        if self._mode == SleepTimerMode.OFF:
            return ""
        minutes = self._remaining_ms // 60000
        seconds = (self._remaining_ms % 60000) // 1000
        return f"{minutes}:{seconds:02d}"

    async def on_track_ended(self) -> None:
        if self._mode == SleepTimerMode.END_OF_TRACK:
            await self._player.stop()
