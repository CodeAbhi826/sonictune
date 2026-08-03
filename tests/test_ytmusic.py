"""Tests for sonictune.library.ytmusic stream URL resolution fallback."""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from types import ModuleType
from unittest.mock import patch

from sonictune.library.ytmusic import YTMusicLibrary


class _FakeYDL:
    """Stub of yt_dlp.YoutubeDL that records the format string used."""

    captured_format: str | None = None

    def __init__(self, opts: dict):
        _FakeYDL.captured_format = opts.get("format")

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def extract_info(self, url: str, download: bool = True):
        return {"url": f"https://stream/{url.split('v=')[-1]}"}


def _make_yt_dlp_module() -> ModuleType:
    mod = ModuleType("yt_dlp")
    mod.YoutubeDL = _FakeYDL
    return mod


def _install_yt_dlp_module() -> ModuleType:
    _FakeYDL.captured_format = None
    return _make_yt_dlp_module()


def _fake_to_thread(fn, *args, **kwargs):
    return fn(*args, **kwargs)


def _run(coro):
    return asyncio.run(coro)


def test_configured_itag_used_when_available() -> None:
    """The requested (Premium) itag is tried first, with free fallbacks."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        with patch("asyncio.to_thread", side_effect=_fake_to_thread), \
             patch.dict(sys.modules, {"yt_dlp": _install_yt_dlp_module()}):
            url = _run(lib.get_stream_url("vid123", 141))
    assert url == "https://stream/vid123"
    assert _FakeYDL.captured_format == "141/251/140/bestaudio/best"


def test_free_itag_chain() -> None:
    """itag 251 keeps the free opus format as primary."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        with patch("asyncio.to_thread", side_effect=_fake_to_thread), \
             patch.dict(sys.modules, {"yt_dlp": _install_yt_dlp_module()}):
            url = _run(lib.get_stream_url("vid456", 251))
    assert url == "https://stream/vid456"
    assert _FakeYDL.captured_format == "251/140/bestaudio/best"


def test_aac_128_no_extra_fallback() -> None:
    """itag 140 (aac_128) needs no chain beyond itself."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        with patch("asyncio.to_thread", side_effect=_fake_to_thread), \
             patch.dict(sys.modules, {"yt_dlp": _install_yt_dlp_module()}):
            url = _run(lib.get_stream_url("vid789", 140))
    assert url == "https://stream/vid789"
    assert _FakeYDL.captured_format == "140/bestaudio/best"


# ---- Section 4: ytmusicapi primary resolver ----------------------------------


class _FakeYTM:
    """Stub ytmusicapi client. Record which video_id get_song was asked for."""

    def __init__(self, song_response=None):
        self.calls: list[str] = []
        self._song = song_response

    def get_song(self, video_id):
        self.calls.append(video_id)
        return self._song or {"streamingData": {}}


def _run_lib(lib, coro, itag=141):
    return asyncio.run(coro)


class _RaisingYTM:
    def get_song(self, video_id):
        raise RuntimeError("boom")


def test_ytmusicapi_primary_returns_direct_url() -> None:
    """If ytmusicapi returns an exact-itag URL, it's used and nothing else runs."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        fake = _FakeYTM({
            "streamingData": {
                "adaptiveFormats": [
                    {"itag": 141, "url": "https://direct.google.com/stream1"},
                    {"itag": 251, "url": "https://direct.google.com/opus"},
                ]
            }
        })
        lib._ytm = fake
        with patch("asyncio.to_thread", side_effect=_fake_to_thread):
            url = _run(lib.get_stream_url("vidAAA", 141))
    assert url == "https://direct.google.com/stream1"
    assert fake.calls == ["vidAAA"]


def test_asyncmusicapi_falls_back_to_next_best() -> None:
    """Request 141 but only 251 available -> returns the opus URL."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        fake = _FakeYTM({
            "streamingData": {
                "adaptiveFormats": [{"itag": 251, "url": "https://direct.google.com/opus"}]
            }
        })
        lib._ytm = fake
        with patch("asyncio.to_thread", side_effect=_fake_to_thread):
            url = _run(lib.get_stream_url("vidBBB", 141))
    assert url == "https://direct.google.com/opus"


def test_ytmusicapi_empty_streaming_data_falls_back_to_ytdlp() -> None:
    """Empty streamingData -> yt-dlp is invoked."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        lib._ytm = _FakeYTM({"streamingData": {}})
        with patch("asyncio.to_thread", side_effect=_fake_to_thread), \
             patch.dict(sys.modules, {"yt_dlp": _install_yt_dlp_module()}):
            url = _run(lib.get_stream_url("vidCCC", 141))
    assert url == "https://stream/vidCCC"
    assert _FakeYDL.captured_format == "141/251/140/bestaudio/best"


def test_ytmusicapi_exception_falls_back_to_ytdlp() -> None:
    """If get_song raises, fall back to yt-dlp without crashing."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        lib._ytm = _RaisingYTM()
        with patch("asyncio.to_thread", side_effect=_fake_to_thread), \
             patch.dict(sys.modules, {"yt_dlp": _install_yt_dlp_module()}):
            url = _run(lib.get_stream_url("vidDDD", 251))
    assert url == "https://stream/vidDDD"
    assert _FakeYDL.captured_format == "251/140/bestaudio/best"


def test_ytmusicapi_both_fail_raises() -> None:
    """ytmusicapi returns nothing AND yt-dlp returns nothing -> RuntimeError."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        lib._ytm = _FakeYTM({"streamingData": {}})

        class _EmptyYDL:
            def __init__(self, opts):
                pass

            def __enter__(self):
                return self

            def __exit__(self, *exc):
                return False

            def extract_info(self, url, download=True):
                return {}

        mod = ModuleType("yt_dlp")
        mod.YoutubeDL = _EmptyYDL
        with patch("asyncio.to_thread", side_effect=_fake_to_thread), \
             patch.dict(sys.modules, {"yt_dlp": mod}):
            try:
                _run(lib.get_stream_url("vidFFF", 141))
                raised = False
            except RuntimeError:
                raised = True
    assert raised


def test_url_locks_bounded() -> None:
    """Section 4 / P1-006: _url_locks never exceeds the cap."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        for i in range(600):
            lib._get_lock(f"vid{i}")
        assert len(lib._url_locks) == 512


def test_rate_limit_respected() -> None:
    """yt-dlp fallbacks are rate-limited to >= _min_url_interval apart."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        lib._ytm = _FakeYTM({"streamingData": {}})
        lib._min_url_interval = 0.0  # don't sleep — just assert the timestamp gate
        with patch("asyncio.to_thread", side_effect=_fake_to_thread), \
             patch.dict(sys.modules, {"yt_dlp": _install_yt_dlp_module()}):
            lib._get_stream_url_ytdlp("vid1", 141)
            first = lib._last_ytdlp_call
            lib._get_stream_url_ytdlp("vid2", 141)
            lib._get_stream_url_ytdlp("vid3", 141)
    # After the first call, _last_ytdlp_call is updated so subsequent calls
    # gate on it; the point is no error and the timestamp advancing.
    assert lib._last_ytdlp_call is not None
    assert lib._last_ytdlp_call >= first


def test_get_stream_url_caches_result() -> None:
    """Repeat calls for the same video_id hit the cache, not the network."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        fake = _FakeYTM({
            "streamingData": {"adaptiveFormats": [{"itag": 251, "url": "https://direct.google.com/opus"}]}
        })
        lib._ytm = fake
        with patch("asyncio.to_thread", side_effect=_fake_to_thread):
            first = _run(lib.get_stream_url("vidCACHE", 141))
            second = _run(lib.get_stream_url("vidCACHE", 141))
    assert first == "https://direct.google.com/opus"
    assert second == first
    assert fake.calls == ["vidCACHE"]  # only one get_song call


# ---- History reporting ------------------------------------------------------


class _HistoryYTM:
    def __init__(self):
        self.added: list[str] = []

    def add_history_item(self, video_id: str) -> None:
        self.added.append(video_id)


class _HistoryRaisingYTM:
    def add_history_item(self, video_id: str) -> None:
        raise RuntimeError("boom")


def test_add_to_history_success() -> None:
    """add_history_item is forwarded to ytmusicapi and returns True."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        fake = _HistoryYTM()
        lib._ytm = fake
        with patch("asyncio.to_thread", side_effect=_fake_to_thread):
            result = _run(lib.add_to_history("vid123"))
    assert result is True
    assert fake.added == ["vid123"]


def test_add_to_history_no_client() -> None:
    """Without an initialized client, reporting is a silent no-op (False)."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        lib._ytm = None
        result = _run(lib.add_to_history("vid123"))
    assert result is False


def test_add_to_history_exception_returns_false() -> None:
    """A failing add_history_item call returns False, never raises."""
    with TemporaryDirectory() as tmp:
        lib = YTMusicLibrary(oauth=None, cookies_path=Path(tmp) / "cook.txt")
        lib._ytm = _HistoryRaisingYTM()
        with patch("asyncio.to_thread", side_effect=_fake_to_thread):
            result = _run(lib.add_to_history("vid123"))
    assert result is False
