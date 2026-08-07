"""Tests for DaemonProxy (T-045 + extras)."""
from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import MagicMock

from sonictune.daemon_proxy import DaemonProxy


def make_test_proxy() -> DaemonProxy:
    """Create a minimal DaemonProxy for testing."""
    config = SimpleNamespace(
        audio=SimpleNamespace(quality="standard", itag=0),
        ui=SimpleNamespace(report_history=False),
    )
    return DaemonProxy(
        player=MagicMock(),
        queue=MagicMock(),
        library=MagicMock(),
        oauth=MagicMock(),
        lyrics=MagicMock(),
        stats=MagicMock(),
        art_cache=MagicMock(),
        audio_cache=MagicMock(),
        db=MagicMock(),
        sync=MagicMock(),
        config=config,
    )


import asyncio
import pytest


@pytest.mark.asyncio
async def test_daemon_proxy_error_boundary() -> None:
    """T-045: DaemonProxy.search surfaces API errors via searchError + errorOccurred.

    Previously this test checked ``result == []`` because search() was a
    synchronous @Slot(result=list). Bug #8 in COMPLETE_FIX_BATCH.md changed
    search() to fire-and-forget (no ``result`` decorator), so the equivalent
    assertion is now that the searchError/errorOccurred signals fire and the
    coroutine completes without raising.
    """
    proxy = make_test_proxy()
    proxy._ytm = MagicMock()
    proxy._ytm.search.side_effect = Exception("API error")
    spy_err = MagicMock()
    spy_search_err = MagicMock()
    proxy.errorOccurred.connect(spy_err)
    proxy.searchError.connect(spy_search_err)

    proxy.search("test query")

    # Let the scheduled _do() coroutine run.
    await asyncio.sleep(0)
    await asyncio.sleep(0)

    spy_err.assert_called_once()
    spy_search_err.assert_called_once()
    assert "API error" in spy_search_err.call_args[0][0]


def test_daemon_audio_quality_default() -> None:
    """Audio quality defaults to 'standard'."""
    proxy = make_test_proxy()
    assert proxy.audioQuality() == "standard"


def test_daemon_current_itag_default() -> None:
    """currentAudioItag defaults to 0."""
    proxy = make_test_proxy()
    assert proxy.currentAudioItag() == 0


def test_daemon_invalid_quality_no_signal() -> None:
    """setAudioQuality ignores invalid values without emitting."""
    proxy = make_test_proxy()
    spy = MagicMock()
    proxy.audioQualityChanged.connect(spy)
    proxy.setAudioQuality("bogus_quality")
    spy.assert_not_called()
    assert proxy.audioQuality() == "standard"


def test_daemon_get_status_includes_queue_state() -> None:
    """getStatus includes shuffle/repeat from the queue."""
    proxy = make_test_proxy()
    proxy._player.get_status.return_value = {"position_ms": 1000, "duration_ms": 200000}
    proxy._queue.get_status.return_value = {"shuffle": True, "repeat": "all"}
    spy = MagicMock()
    proxy.statusReceived.connect(spy)
    proxy.getStatus()
    payload = spy.call_args[0][0]
    assert payload["shuffle"] is True
    assert payload["repeat"] == "all"


def test_daemon_report_history_round_trip() -> None:
    """reportHistory/setReportHistory round-trip the persisted flag."""
    proxy = make_test_proxy()
    proxy._config.ui.report_history = True
    assert proxy.reportHistory() is True
    proxy.setReportHistory(False)
    assert proxy.reportHistory() is False
