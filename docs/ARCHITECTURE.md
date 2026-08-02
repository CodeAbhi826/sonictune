# Architecture

This document explains how SonicTune is structured and why. If you're
contributing code, read this first.

## High-level overview

```
┌──────────────────────────────────────────────────────────────┐
│           SonicTune — Single Process (PySide6 + qasync)      │
│                                                              │
│  QML UI (renders + handles input)                            │
│   └── DaemonProxy (direct Python calls, NO D-Bus)            │
│                                                              │
│  Services (owned by SonicTuneApp in app.py)                  │
│   ├── AuthManager (OAuth TV device flow + cookies)           │
│   ├── YTMusicLibrary (ytmusicapi, async via to_thread)       │
│   ├── MpvPlayer / NullPlayer (libmpv)                        │
│   ├── QueueManager (shuffle/repeat/history)                  │
│   ├── ArtCache + AudioCache (on-disk LRU)                    │
│   ├── LyricsClient (LRCLIB)                                  │
│   ├── StatsAggregator (SQLite play_history)                  │
│   ├── Database (SQLite WAL via aiosqlite)                    │
│   ├── DiscordRPC (optional, pypresence)                      │
│   └── MprisServer (external D-Bus — desktop integration only)│
│                                                              │
│  System Tray (minimize-to-tray)                              │
└──────────────────────────────────────────────────────────────┘
```

## Why a single process?

SonicTune previously ran a **daemon + UI split** over D-Bus. Both
independent audits (see `docs/sonictune_audit_report.md` and
`docs/deep-research-report.md`) concluded that this IPC layer was the
root cause of most bugs:

- Variant wrapping complexity
- Signal annotation mismatches (`@signal()` signature derivation)
- Two event loops that must be kept in sync
- Async slot scheduling across a process boundary
- Connection-state management (the red "cannot reach daemon" banner)

Most Linux music players (Elisa, Amberol, Spot) run everything in one
process. SonicTune now does the same: **one process, one asyncio loop,
direct Python calls**. The "daemon" concept survives only as the internal
service layer.

What remains D-Bus: **MPRIS only** (`org.mpris.MediaPlayer2.sonictune`),
which is the standard desktop integration protocol (media keys, lockscreen,
GNOME/KDE playback widgets).

## Module map

### Application core (`src/sonictune/`)

| Module | Responsibility |
|---|---|
| `app.py` | Unified application class (`SonicTuneApp`). Owns all services, configures logging/locale, sets up QML engine, tray, and lifecycle. Entry point: `sonictune.app:main`. |
| `config.py` | Loads `~/.config/sonictune/config.toml` into typed dataclasses. Writes a default config on first launch. |
| `auth/oauth.py` | YouTube Music OAuth TV device code flow + token storage (mode 0600). |
| `auth/cookies.py` | Browser cookie import (fallback when OAuth unavailable). |
| `library/ytmusic.py` | Async wrapper around ytmusicapi. All network calls run in `asyncio.to_thread()` since ytmusicapi is sync. |
| `library/models.py` | Typed dataclasses (`Track`, `Album`, `Artist`, `Playlist`) wrapping ytmusicapi's inconsistent dict shapes. |
| `library/sync.py` | Syncs library (songs/albums/artists/playlists) from YT Music into local DB. |
| `player/mpv_player.py` | libmpv wrapper via python-mpv. Owns the actual playback engine, exposes transport + signals. |
| `player/null_player.py` | Stub player used when libmpv is unavailable (library/UI still work). |
| `player/queue.py` | Queue state: tracks, current index, shuffle, repeat, history. Pure Python (no I/O). |
| `player/types.py` | Shared enums (`PlayerState`, `PlayerEvent`) + `TrackInfo` dataclass. |
| `cache/lru.py` | Generic LRU (used in-memory for URL→path mapping). |
| `cache/art.py` | Album art cache — fetches, downscales to WebP, LRU-evicts by total size. Exposes `get_path()` (async) and `get_sync()` (for the Qt image thread). |
| `cache/audio.py` | Downloaded/streamed audio cache. |
| `lyrics/lrclib.py` | Synced lyrics from LRCLIB. Parses LRC format with offset support. |
| `stats/aggregator.py` | Computes listening stats from `play_history` table. 5-min cache. |
| `mpris/server.py` | MPRIS v2 D-Bus server — lets KDE/GNOME/lockscreen control playback. |
| `discord/rpc.py` | Discord Rich Presence via pypresence. Optional. |
| `db/database.py` | SQLite (WAL mode) wrapper. Async via aiosqlite. Schema migrations. |
| `history/sync.py` | Back-sync plays to YT Music (for YouTube Recap). |
| `utils/helpers.py` | Misc shared helpers. |

### UI (`src/sonictune/ui/`)

| Module | Responsibility |
|---|---|
| `main.py` | Thin entry-point wrapper around `sonictune.app:main`. |
| `daemon_proxy.py` | `DaemonProxy` — a `QObject` with the same signals/slots the old D-Bus client exposed, but calling services directly in-process. This is what QML talks to. |
| `clipboard.py` | `ClipboardHelper` — copy-to-clipboard for OAuth codes. |
| `imageprovider.py` | `QQuickImageProvider` for `image://art/<url>`. Reads directly from `ArtCache` (sync `get_sync()`), no IPC. |
| `tray.py` | System tray icon (show/hide/quit) for minimize-to-tray. |
| `qml/main.qml` | Application shell: window, nav rail, page stack, player bar. |
| `qml/theme/Theme.qml` | Material 3-inspired palette (dark/light/archive presets). Singleton (`pragma Singleton` + `qmldir`). |
| `qml/pages/` | One QML file per page (Home, Search, Library, Stats, NowPlaying, Settings). |
| `qml/components/` | Reusable widgets (PlayerBar, AlbumCard, TrackList, etc.). |

## Data flow: play a track

1. User clicks a track in `TrackList.qml`.
2. QML calls `Daemon.playTrack(videoId)`.
3. `DaemonProxy.playTrack()` runs an async coroutine that:
   a. Calls `library.get_track(videoId)` — fetches metadata via ytmusicapi (in thread).
   b. Calls `queue.clear()` + `queue.add_track(track)`.
   c. Calls `library.get_stream_url(video_id, itag)` — uses yt-dlp to resolve playable URL (in thread).
   d. Calls `player.load_url(url, track_info)` — libmpv starts playing.
4. `MpvPlayer` emits events → `DaemonProxy` forwards them as Qt signals (`stateChanged`, `trackChanged`, `positionChanged`) → QML updates.

## Data flow: stats

1. Track finishes (`MpvPlayer.END_REACHED` event).
2. `DaemonProxy._on_end_reached()` records the play via `stats.record_play(video_id, position_ms, completion_pct)` and advances the queue.
3. Stats module writes a row to `play_history` table.
4. When user opens Stats page, QML calls `Daemon.getStats()` → `StatsAggregator.get_stats()` → returns cached aggregation (or recomputes if cache stale).
5. UI renders charts.

## Why these specific libraries?

- **libmpv (via python-mpv)**: Best-in-class audio quality, hardware decoding, gapless, mature, well-maintained. Alternatives (GStreamer, VLC) are either more complex or have worse YT streaming support.
- **ytmusicapi**: Only mature Python library for YT Music. Has OAuth support (rare).
- **yt-dlp**: Resolves playable stream URLs. YTM's signature cipher changes frequently; yt-dlp keeps up.
- **dbus-next**: Used only for MPRIS (external desktop integration), where it is a clean async-native fit.
- **aiosqlite**: Async wrapper over stdlib sqlite3. Lets us use `async/await` for DB access without blocking the event loop.
- **httpx**: Async HTTP client. Cleaner than `requests` for modern async code.
- **structlog**: Structured logging — invaluable for debugging. JSON output when not a TTY.
- **PySide6**: Official Qt Python bindings. LGPL. Better license story than PyQt6 (GPL).
- **qasync**: Bridges Qt's event loop and asyncio — lets the UI and all services share one loop.
- **pypresence**: Discord Rich Presence — only stable option.

## Why SQLite + WAL?

- **WAL mode** allows concurrent reads while writing.
- **No external DB server** — keeps deployment simple.
- **Single file** — easy to back up, easy to wipe.
- **Built-in to Python** — no extra dependency.

For our scale (single user, ~10k plays/year), SQLite is more than enough.

## What about Kirigami?

Kirigami (KDE's QtQuick layout framework) is great for cross-form-factor apps but adds:
- A hard dependency on KDE Frameworks (huge).
- Opinionated page routing that doesn't always fit media-player UX.
- More "KDE-flavored" visuals.

For SonicTune's single-window desktop UX, raw QtQuick.Controls + Material is leaner. If we later want mobile support, we can revisit.

## What about GStreamer?

GStreamer is the "official" Linux media framework, but:
- API is C-centric and complex.
- Plugin discovery is fragile across distros.
- Less mature for streaming URL playback than mpv.
- mpv's audio pipeline is simpler and "just works".

mpv under the hood uses ffmpeg/libav, so we get the same codec support without GStreamer's plugin complexity.

## Concurrency model

SonicTune is a **single process with one asyncio event loop** (a qasync
`QEventLoop` that also drives Qt). All I/O is async (httpx, aiosqlite,
dbus-next). Sync libraries (ytmusicapi, mpv) are called via
`asyncio.to_thread()`.

mpv runs its own thread internally (libmpv is thread-safe). Event
callbacks from mpv are marshalled back to our event loop via
`asyncio.run_coroutine_threadsafe()`.

Qt signal emission from async coroutines is safe because the same event
loop drives both Qt and asyncio. Async methods invoked from QML slots use
`asyncio.create_task()` — they run on the shared loop.

The `ArtImageProvider` runs on Qt's image thread, so it uses the
synchronous `ArtCache.get_sync()` rather than the async `get_path()`.

## Locale

libmpv requires the C locale for numeric parsing. `SonicTuneApp._set_locale()`
sets `LC_ALL` via `ctypes.setlocale()` at the C level (and via Python's
`locale.setlocale`) **before** any other library imports, eliminating the
locale race.

## Lifecycle

```
[single process: python -m sonictune.app]
    │
    ├── loads config from ~/.config/sonictune/config.toml
    ├── sets C locale (ctypes, pre-import)
    ├── inits DB (~/.local/share/sonictune/sonictune.db)
    ├── inits OAuth manager + YTMusicLibrary
    ├── inits libmpv (or NullPlayer)
    ├── inits art/audio caches, lyrics, stats, sync
    ├── (optional) registers org.mpris.MediaPlayer2.sonictune
    ├── (optional) connects to Discord IPC
    ├── creates DaemonProxy → exposed to QML as `Daemon`
    ├── loads main.qml, shows window + tray icon
    │
    ▼
[runs, serving QML calls directly]
    │
    ▼
[quit (tray Quit / window close → minimize to tray)]
    │
    ▼
[graceful shutdown: close Discord, unregister MPRIS, stop player, close DB]
```

Run it with a single command:

```
./scripts/run.sh [--verbose] [--no-mpris] [--no-discord]
```

## Future considerations

- **Mobile companion app**: Would need a new IPC path (the old D-Bus server is gone).
- **Web UI**: A small Flask/FastAPI wrapper around the same service classes.
- **Headless CLI**: `sonictune` is a GUI app; a CLI mode could reuse the service layer directly.
