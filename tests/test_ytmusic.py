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


def _fake_to_thread(fn, *_args, **_kwargs):
    return fn()


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
