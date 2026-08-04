"""Tests for Sleep Timer (T-013 to T-015)."""
from __future__ import annotations

from sonictune.player.sleep_timer import SleepTimer, SleepTimerMode


class FakePlayer:
    def __init__(self):
        self.stop_called = False

    async def stop(self):
        self.stop_called = True


def test_sleep_timer_5_minutes() -> None:
    """T-013: SleepTimer sets 5 minute countdown correctly."""
    player = FakePlayer()
    timer = SleepTimer(player)
    timer.set_mode(SleepTimerMode.MINUTES_5)
    assert timer._remaining_ms == 300000
    assert timer.is_active is True


def test_sleep_timer_cancel() -> None:
    """T-014: SleepTimer OFF mode cancels active timer."""
    player = FakePlayer()
    timer = SleepTimer(player)
    timer.set_mode(SleepTimerMode.MINUTES_5)
    timer.set_mode(SleepTimerMode.OFF)
    assert timer.is_active is False
    assert timer._remaining_ms == 0


def test_sleep_timer_end_of_track() -> None:
    """T-015: SleepTimer END_OF_TRACK triggers on track end."""
    import asyncio
    player = FakePlayer()
    timer = SleepTimer(player)
    timer.set_mode(SleepTimerMode.END_OF_TRACK)
    asyncio.run(timer.on_track_ended())
    assert player.stop_called is True


def test_sleep_timer_remaining_text() -> None:
    """T-048: get_remaining_text returns M:SS format."""
    player = FakePlayer()
    timer = SleepTimer(player)
    timer.set_mode(SleepTimerMode.MINUTES_5)
    text = timer.get_remaining_text()
    assert ":" in text
    parts = text.split(":")
    assert len(parts) == 2
    assert parts[0] == "5"
    assert len(parts[1]) == 2


def test_sleep_timer_remaining_text_off() -> None:
    """get_remaining_text returns empty string when OFF."""
    player = FakePlayer()
    timer = SleepTimer(player)
    assert timer.get_remaining_text() == ""


def test_sleep_timer_15_minutes() -> None:
    """SleepTimer MINUTES_15 sets a 15 minute countdown."""
    player = FakePlayer()
    timer = SleepTimer(player)
    timer.set_mode(SleepTimerMode.MINUTES_15)
    assert timer._remaining_ms == 900000
    text = timer.get_remaining_text()
    assert text.startswith("15:")
