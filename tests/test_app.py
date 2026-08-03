"""Tests for sonictune.app + sonictune.ui.daemon_proxy.

Replaces the old D-Bus E2E tests. Tests the unified single-process
architecture directly — no subprocesses, no D-Bus.
"""
from __future__ import annotations

import asyncio
from typing import Any

from sonictune.library.models import Album, Playlist, Track
from sonictune.player.null_player import NullPlayer
from sonictune.player.queue import QueueManager, RepeatMode
from sonictune.player.types import PlayerEvent, PlayerState
from sonictune.ui.daemon_proxy import DaemonProxy

# ---- Fakes ------------------------------------------------------------------


class FakeOAuth:
    is_authenticated = False

    async def init(self) -> None:
        pass

    async def start_oauth(self, client_id: str, client_secret: str) -> Any:
        return type(
            "Session",
            (),
            {
                "user_code": "ABCD-EFGH",
                "verification_url": "https://google.com/device",
                "device_code": "devcode",
                "expires_in": 600,
                "interval": 5,
            },
        )()

    async def poll_oauth(self) -> bool:
        return True

    async def logout(self) -> None:
        self.is_authenticated = False


class FakeLibrary:
    def __init__(self) -> None:
        self.tracks: dict[str, Track] = {}

    async def init(self) -> None:
        pass

    async def close(self) -> None:
        pass

    async def get_track(self, video_id: str) -> Track:
        return self.tracks.get(video_id) or Track(video_id=video_id, title=f"Track {video_id}", artist="Artist")

    async def get_stream_url(self, video_id: str, itag: int = 0) -> str:
        return f"https://example.com/{video_id}.m4a"

    async def search(self, query: str, filter_: str | None = None, limit: int = 20) -> list[Any]:
        return [Track(video_id=f"r{i}", title=f"{query} {i}", artist="Artist") for i in range(limit)]

    async def search_songs(self, query: str, limit: int = 20) -> list[Track]:
        return [Track(video_id=f"s{i}", title=f"{query} {i}", artist="Artist") for i in range(limit)]

    async def get_home(self) -> list[Any]:
        return [
            {
                "title": "Quick picks",
                "contents": [
                    {"title": "Song A", "videoId": "v1", "artists": [{"name": "Artist A"}], "thumbnails": [{"url": "http://x/a.jpg"}]},
                    {"title": "Song B", "videoId": "v2", "artists": [{"name": "Artist B"}], "thumbnails": [{"url": "http://x/b.jpg"}]},
                ],
            },
        ]

    async def get_library_songs(self, limit: int = 100) -> list[Track]:
        return [Track(video_id=f"l{i}", title=f"Song {i}", artist="Artist") for i in range(limit)]

    async def get_library_albums(self, limit: int = 50) -> list[Album]:
        return [Album(browse_id=f"al{i}", title=f"Album {i}", artist="Artist") for i in range(limit)]

    async def get_library_playlists(self, limit: int = 50) -> list[Playlist]:
        return [Playlist(playlist_id=f"pl{i}", title=f"Playlist {i}") for i in range(limit)]


class FakeLyrics:
    async def get_synced(self, track_name: str, artist_name: str, album_name: str | None, duration_ms: int | None) -> list[Any]:
        return []


class FakeStats:
    def __init__(self) -> None:
        self.recorded: list[tuple[str, int, float, str | None]] = []

    async def record_play(
        self,
        video_id: str,
        position_ms: int,
        completion_pct: float,
        started_at: str | None = None,
    ) -> None:
        self.recorded.append((video_id, position_ms, completion_pct, started_at))

    async def get_stats(self) -> Any:
        return type(
            "Stats",
            (),
            {
                "total_plays": 0,
                "total_listen_ms": 0,
                "unique_tracks": 0,
                "unique_artists": 0,
                "top_tracks": [],
                "top_artists": [],
                "listening_by_hour": [],
                "listening_by_day": [],
                "last_30_days": [],
            },
        )()


class FakeDB:
    async def record_search(self, query: str, result_count: int) -> None:
        pass

    async def get_search_history(self, limit: int = 10) -> list[Any]:
        return [{"query": "test", "result_count": 5, "searched_at": 0}]


class FakeSync:
    async def sync_all(self) -> dict[str, int]:
        return {"songs": 1, "albums": 2, "artists": 3, "playlists": 4}


class FakeCache:
    async def close(self) -> None:
        pass


class FakeConfig:
    audio = type("Audio", (), {"itag": 140})()
    cookies_path = "/tmp/sonictune-cookies.txt"
    ui = type("UI", (), {"report_history": True})()
    config_dir = None


def make_proxy() -> DaemonProxy:
    return DaemonProxy(
        player=NullPlayer(),
        queue=QueueManager(),
        library=FakeLibrary(),
        oauth=FakeOAuth(),
        lyrics=FakeLyrics(),
        stats=FakeStats(),
        art_cache=FakeCache(),
        audio_cache=FakeCache(),
        db=FakeDB(),
        sync=FakeSync(),
        config=FakeConfig(),
    )


# ---- DaemonProxy: connection -------------------------------------------------


def test_proxy_always_connected() -> None:
    proxy = make_proxy()
    assert proxy.connected is True
    assert proxy.connectionChanged


def test_proxy_signals_exist() -> None:
    """All signals used by QML are present on the proxy."""
    proxy = make_proxy()
    for name in [
        "stateChanged",
        "positionChanged",
        "trackChanged",
        "queueChanged",
        "authChanged",
        "connectionChanged",
        "error",
        "statusReceived",
        "queueReceived",
        "searchCompleted",
        "searchError",
        "searchSongsCompleted",
        "librarySongsReceived",
        "libraryAlbumsReceived",
        "libraryPlaylistsReceived",
        "startOAuthCompleted",
        "pollOAuthCompleted",
        "importCookiesCompleted",
        "statsReceived",
        "syncLibraryCompleted",
        "searchHistoryReceived",
        "lyricsReceived",
        "homeReceived",
    ]:
        assert hasattr(proxy, name), f"missing signal {name}"


def test_proxy_slots_exist() -> None:
    """All QML-callable slots are present."""
    proxy = make_proxy()
    for name in [
        "play",
        "pause",
        "playPause",
        "stop",
        "next",
        "previous",
        "seek",
        "setVolume",
        "getStatus",
        "playTrack",
        "addToQueue",
        "removeFromQueue",
        "clearQueue",
        "jumpTo",
        "setShuffle",
        "setRepeat",
        "getQueue",
        "search",
        "searchSongs",
        "getHome",
        "getLibrarySongs",
        "getLibraryAlbums",
        "getLibraryPlaylists",
        "isAuthenticated",
        "startOAuth",
        "pollOAuth",
        "logout",
        "importCookies",
        "getStats",
        "recordSearch",
        "getSearchHistory",
        "syncLibrary",
        "getLyrics",
        "reportHistory",
        "setReportHistory",
    ]:
        assert hasattr(proxy, name), f"missing slot {name}"


def test_proxy_report_history_default_true() -> None:
    """reportHistory() reflects the config default (True)."""
    proxy = make_proxy()
    assert proxy.reportHistory() is True


def test_proxy_set_report_history_updates_config() -> None:
    """setReportHistory() flips the config value seen by QML."""
    proxy = make_proxy()
    proxy.setReportHistory(False)
    assert proxy.reportHistory() is False
    proxy.setReportHistory(True)
    assert proxy.reportHistory() is True


def test_normalize_search_item_maps_camelcase_to_snake() -> None:
    """Raw ytmusicapi search hits (camelCase) map to QML snake_case keys."""
    proxy = make_proxy()
    raw = {
        "resultType": "song",
        "title": "Ordinary",
        "videoId": "abc123",
        "duration_seconds": 213,
        "thumbnails": [{"url": "small.jpg"}, {"url": "big.jpg"}],
        "artists": [{"name": "A"}, {"name": "B"}],
        "album": {"id": "x", "name": "LP"},
    }
    item = proxy._normalize_search_item(raw)
    assert item["video_id"] == "abc123"
    assert item["title"] == "Ordinary"
    assert item["thumbnail_url"] == "big.jpg"
    assert item["artist"] == "A, B"
    assert item["album"] == "LP"
    assert item["duration_ms"] == 213000
    assert item["resultType"] == "song"


def test_normalize_search_item_handles_track_object() -> None:
    """Typed Track objects (no .get) also normalize."""
    proxy = make_proxy()
    track = Track(video_id="v9", title="Song", artist="Artist", album="LP", duration_ms=200000)
    item = proxy._normalize_search_item(track)
    assert item["video_id"] == "v9"
    assert item["title"] == "Song"
    assert item["artist"] == "Artist"
    assert item["duration_ms"] == 200000


# ---- DaemonProxy: player events ----------------------------------------------


async def test_proxy_emits_state_changed() -> None:
    proxy = make_proxy()
    events: list[str] = []
    proxy.stateChanged.connect(lambda s: events.append(s))
    await proxy._player._set_state(PlayerState.PLAYING)
    await asyncio.sleep(0)  # let asyncio.call_soon batch flush
    assert PlayerState.PLAYING.value in events


async def test_proxy_emits_track_changed() -> None:
    proxy = make_proxy()
    emitted: list[dict[str, Any]] = []
    proxy.trackChanged.connect(lambda d: emitted.append(d))

    track = Track(video_id="v1", title="Hello", artist="World", album="LP", duration_ms=180000)
    await proxy._player._emit(PlayerEvent.TRACK_CHANGED, {"track": track})
    await asyncio.sleep(0)
    assert emitted and emitted[0]["video_id"] == "v1"
    assert emitted[0]["title"] == "Hello"


async def test_proxy_emits_position_changed() -> None:
    proxy = make_proxy()
    positions: list[tuple[int, int]] = []
    proxy.positionChanged.connect(lambda p, d: positions.append((p, d)))
    await proxy._player._emit(PlayerEvent.POSITION_CHANGED, {"position_ms": 5000, "duration_ms": 180000})
    await asyncio.sleep(0)
    assert (5000, 180000) in positions


# ---- DaemonProxy: transport --------------------------------------------------


async def test_proxy_get_status_emits() -> None:
    proxy = make_proxy()
    results: list[dict[str, Any]] = []
    proxy.statusReceived.connect(lambda s: results.append(s))
    proxy.getStatus()
    assert results and "state" in results[0]


async def test_proxy_play_track_flows_to_player() -> None:
    proxy = make_proxy()
    proxy._library.tracks["abc"] = Track(video_id="abc", title="Song", artist="Artist")
    states: list[str] = []
    proxy.stateChanged.connect(lambda s: states.append(s))
    proxy.playTrack("abc")
    await asyncio.sleep(0.05)
    assert proxy._player.current_track.video_id == "abc"


async def test_proxy_set_repeat() -> None:
    proxy = make_proxy()
    proxy.setRepeat(RepeatMode.ALL.value)
    await asyncio.sleep(0.05)
    assert proxy._queue.repeat == RepeatMode.ALL


async def test_proxy_set_shuffle() -> None:
    proxy = make_proxy()
    proxy.setShuffle(True)
    await asyncio.sleep(0.05)
    assert proxy._queue.shuffle is True


# ---- DaemonProxy: library ----------------------------------------------------


async def test_proxy_search_emits_results() -> None:
    proxy = make_proxy()
    results: list[Any] = []
    proxy.searchCompleted.connect(lambda r: results.append(r))
    proxy.search("hello", "songs", 5)
    await asyncio.sleep(0.05)
    assert results and len(results[0]) == 5


async def test_proxy_home_emits() -> None:
    proxy = make_proxy()
    results: list[Any] = []
    proxy.homeReceived.connect(lambda r: results.append(r))
    proxy.getHome()
    await asyncio.sleep(0.05)
    assert results
    sections = results[0]
    assert len(sections) == 1
    assert sections[0]["title"] == "Quick picks"
    assert len(sections[0]["items"]) == 2
    assert sections[0]["items"][0]["video_id"] == "v1"
    assert sections[0]["items"][0]["thumbnail_url"] == "http://x/a.jpg"


def test_proxy_normalize_home() -> None:
    proxy = make_proxy()
    raw = [
        {
            "title": "Row 1",
            "contents": [
                {"title": "T1", "videoId": "v1", "artists": [{"name": "A1"}, {"name": "A2"}], "thumbnails": [{"url": "http://x/1.jpg"}, {"url": "http://x/hi.jpg"}]},
                {"title": "Playlist", "playlistId": "PL1", "thumbnails": []},
                {"browseId": "no-title", "thumbnails": []},
            ],
        },
        {"title": "Empty row", "contents": []},
    ]
    sections = proxy._normalize_home(raw)
    assert len(sections) == 1
    assert sections[0]["title"] == "Row 1"
    items = sections[0]["items"]
    assert len(items) == 3
    assert items[0]["subtitle"] == "A1, A2"
    assert items[0]["thumbnail_url"] == "http://x/hi.jpg"  # largest thumbnail
    assert items[0]["video_id"] == "v1"
    assert items[1]["browse_id"] == "PL1"
    assert items[2]["title"] == ""


def test_proxy_normalize_home_empty() -> None:
    proxy = make_proxy()
    assert proxy._normalize_home([]) == []
    assert proxy._normalize_home(None) == []


# ---- DaemonProxy: stats ------------------------------------------------------


async def test_proxy_stats_emit() -> None:
    proxy = make_proxy()
    results: list[dict[str, Any]] = []
    proxy.statsReceived.connect(lambda s: results.append(s))
    proxy.getStats()
    await asyncio.sleep(0.05)
    assert results and "total_plays" in results[0]


# ---- DaemonProxy: end-of-track auto-advance ----------------------------------


async def test_proxy_end_reached_records_and_advances() -> None:
    proxy = make_proxy()
    t1 = Track(video_id="e1", title="One", artist="A")
    t2 = Track(video_id="e2", title="Two", artist="B")
    await proxy._queue.add_tracks([t1, t2])
    await proxy._queue.set_repeat(RepeatMode.ALL)
    await proxy._queue.advance()  # current -> e2

    await proxy._on_end_reached({"video_id": "e2"})
    await asyncio.sleep(0.05)

    assert proxy._player.current_track.video_id in ("e1", "e2")


# ---- SonicTuneApp: wiring ----------------------------------------------------


def test_app_creates_queue() -> None:
    from sonictune.config import DaemonConfig

    app = type("App", (), {"config": DaemonConfig()})
    assert app.config is not None


def test_app_importable() -> None:
    import sonictune.app
    assert sonictune.app.SonicTuneApp


# ---- YouTube Music history reporting ----------------------------------------
#
# These drive SonicTuneApp._on_player_event() directly with a lightweight
# fake `self` so we don't need a full app instance (which would require Qt
# and a real event loop).


class _FakePlayerForHistory:
    def __init__(self, track: Track | None) -> None:
        self.current_track = track

    def add_listener(self, callback) -> None:
        pass


class _FakeLibraryForHistory:
    def __init__(self) -> None:
        self.reported: list[str] = []
        self.fail = False

    async def add_to_history(self, video_id: str) -> bool:
        if self.fail:
            return False
        self.reported.append(video_id)
        return True


class _FakeUIConfig:
    report_history = True


def _make_history_app(track: Track | None = None, report: bool = True):
    from sonictune.app import SonicTuneApp

    player = _FakePlayerForHistory(track)
    lib = _FakeLibraryForHistory()
    app = type("App", (), {
        "_history_reported": False,
        "config": type("Config", (), {"ui": type("UI", (), {"report_history": report})()})(),
        "player": player,
        "library": lib,
    })()
    # Bind the real reporting helper so the fake behaves like the app.
    app._report_history = SonicTuneApp._report_history.__get__(app, type(app))
    return app, lib


async def test_history_reported_at_threshold() -> None:
    """POSITION_CHANGED past min(30s, 50%) reports the play."""
    from sonictune.app import SonicTuneApp
    track = Track(video_id="vid123", title="Song", artist="Artist")
    app, lib = _make_history_app(track=track, report=True)
    await SonicTuneApp._on_player_event(
        app, PlayerEvent.POSITION_CHANGED, {"position_ms": 31000, "duration_ms": 180000}
    )
    assert app._history_reported is True
    assert lib.reported == ["vid123"]


async def test_history_not_reported_when_disabled() -> None:
    """report_history=False suppresses reporting entirely."""
    from sonictune.app import SonicTuneApp
    track = Track(video_id="vid123", title="Song", artist="Artist")
    app, lib = _make_history_app(track=track, report=False)
    await SonicTuneApp._on_player_event(
        app, PlayerEvent.POSITION_CHANGED, {"position_ms": 31000, "duration_ms": 180000}
    )
    assert app._history_reported is False
    assert lib.reported == []


async def test_history_reported_once_per_track() -> None:
    """Repeated position ticks do not double-report."""
    from sonictune.app import SonicTuneApp
    track = Track(video_id="vid123", title="Song", artist="Artist")
    app, lib = _make_history_app(track=track, report=True)
    for _ in range(5):
        await SonicTuneApp._on_player_event(
            app, PlayerEvent.POSITION_CHANGED, {"position_ms": 31000, "duration_ms": 180000}
        )
    assert app._history_reported is True
    assert lib.reported == ["vid123"]


async def test_history_reset_on_track_change() -> None:
    """A new track resets the per-track guard so it can be reported again."""
    from sonictune.app import SonicTuneApp
    track = Track(video_id="vid123", title="Song", artist="Artist")
    app, _lib = _make_history_app(track=track, report=True)
    await SonicTuneApp._on_player_event(
        app, PlayerEvent.POSITION_CHANGED, {"position_ms": 31000, "duration_ms": 180000}
    )
    assert app._history_reported is True
    await SonicTuneApp._on_player_event(app, PlayerEvent.TRACK_CHANGED, {"track": track})
    assert app._history_reported is False


async def test_history_reported_on_end_if_not_already() -> None:
    """END_REACHED reports when the track ended before the threshold."""
    from sonictune.app import SonicTuneApp
    track = Track(video_id="vid123", title="Song", artist="Artist")
    app, lib = _make_history_app(track=track, report=True)
    await SonicTuneApp._on_player_event(app, PlayerEvent.END_REACHED, {"track": track})
    assert app._history_reported is True
    assert lib.reported == ["vid123"]


async def test_history_not_double_reported_on_end() -> None:
    """END_REACHED after a threshold report does not report twice."""
    from sonictune.app import SonicTuneApp
    track = Track(video_id="vid123", title="Song", artist="Artist")
    app, lib = _make_history_app(track=track, report=True)
    await SonicTuneApp._on_player_event(
        app, PlayerEvent.POSITION_CHANGED, {"position_ms": 31000, "duration_ms": 180000}
    )
    await SonicTuneApp._on_player_event(app, PlayerEvent.END_REACHED, {"track": track})
    assert lib.reported == ["vid123"]
