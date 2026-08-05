# Changelog

## [Unreleased] — 2026-08-05 (Audit fix pass)

### Added
- Bundled **Inter** (Regular/Medium/SemiBold/Bold) + **JetBrains Mono** (Regular/Medium/SemiBold/Bold) under `data/fonts/` with their OFL-1.1 license texts (V3); `_register_fonts()` verified to expose the exact family names Theme.qml uses.
- Bounded stream-resolution retry/fallback in `library/ytmusic.py` (G1): yt-dlp fallback escalates `force_ipv4` → `force_ipv4`+`geo_bypass`, returns `None` after 3 attempts; `daemon_proxy._play_track` toasts "Skipped — unavailable" and auto-advances.
- Wiring tests for SponsorBlock (G2) proving POSITION_CHANGED seeks and TRACK_CHANGED fetches through the app listener.
- Cross-desktop release verification checklist in `docs/ROADMAP.md` (G3): GNOME/Wayland, plain X11, and one non-Arch distro.
- `test_theme_tokens_in_sync` (D1): drift guard between `Theme.qml` and `Theme.py`; fixed 3 drifted values (`on_background`, `on_surface`, `on_tertiary_container`).
- Feature list in `README.md` (highlights SponsorBlock).
- Note in `docs/ROADMAP.md` Phase 3 that `top_albums` is intentionally empty (L2).

### Fixed
- **`app.py`: `time` not imported** in the Last.fm wiring (NameError at runtime) — real bug.
- **`local_scanner.py`: `file_path` undefined** in `_extract_mp3_metadata` (NameError on the MP3 fallback path); F823 shadowing in `get_album_art`; missing `PIL.Image` import; unused `primary_hex`.
- Removed inert `gpu_context="wayland"` from the audio-only `MpvPlayer` (L3).
- Test files for deleted dead modules removed (`test_audio_devices.py`, `test_prefetch.py`, `test_social.py`).
- 52 ruff errors cleared (undefined names, unused imports/vars, ambiguous `l` vars, nested `with`, redundant try/except); `ruff check` now passes clean.
- `test_crossfade_disable` updated for the H1 `_rebuild_af_chain()` behavior (keeps normalization when crossfade is off).

### Changed
- Per-file ruff ignores: `app.py` RUF006 (fire-and-forget wiring tasks, matches `daemon_proxy.py`); `local_scanner.py`/`color_extractor.py` ASYNC240 (executor-delegated disk I/O).

---

## [Unreleased] — 2026-08-04 (QA suite green + QML polish)

### Added
- `qapp` fixture in `tests/conftest.py` for Qt-based tests (`240bcdf`).
- `WheelHandler` + `cacheBuffer: 1200` on `TrackList.qml` to fix scroll-wheel hijacking (`240bcdf`).
- `Theme.shadowColor` token; card shadows now come from theme instead of hardcoded hex (`240bcdf`).

### Changed
- `LibraryPage.qml` Songs tab unwrapped from `ScrollView` so the `ListView` owns its own scrolling (`240bcdf`).
- `AlbumCard.qml`/`ArtistCard.qml`/`PlaylistCard.qml` replace clipped elevation with `DropShadow` (no more shadow clipping) (`240bcdf`).

### Fixed
- Full test suite green: **206 passed, 3 skipped** (`240bcdf`).
  - Comprehensive suite: prefetch tests await the async prefetch task before asserting; image-cache LRU test mirrors the real per-insert eviction.
  - `test_ui.py`: explicit UTF-8 file reads (locale is polluted to `C` by `mpv_player`), and QML no longer contains hardcoded hex colors.
  - Restored discarded Phase 2 work and added the QA regression suite (`18e1d52`).

---

## [Unreleased] — 2026-08-04 (Post-Revamp fixes)

### Added
- **ytmusicapi-native stream resolver** in `library/ytmusic.py` — resolves playable stream URLs directly via ytmusicapi instead of yt-dlp, fixing playback for non-Premium accounts (`5e0ef1a`, `ebd380f`).
- Material 3 UI token expansion in `theme/Theme.qml` + new `STButton.qml`/`STSlider.qml` component sources (`5e0ef1a`).
- YT Music history reporting wired through `daemon_proxy` → `app.py` (`95f1de1`).
- Expanded test suite: `tests/test_mpris.py`, `tests/test_player.py`, `tests/test_stats.py`, `tests/test_config.py`, `tests/test_ui.py`, `tests/test_ytmusic.py`, plus new `tests/conftest.py` fixture helpers (`5e0ef1a`).

### Changed
- Full UI revamp pass across `NowPlayingPage`, `SettingsPage`, `SearchPage`, `HomePage`, `PlayerBar`, `TrackList`, `NavRail`, `Icon`, `Theme.qml` — M3 styling, layout and white-text fixes (`95f1de1`, `ec8d60e`).
- `README.md` trimmed to a concise status marker ("Still in development") (`d1be9ff`).

### Fixed
- Audio stream resolution failing for non-Premium accounts (all playback broken) — stream resolver switched to ytmusicapi-native approach (`ebd380f`).
- UI stuck on loading — qasync event loop now driven from `app.py`, QML type/anchoring fixes (`076b087`).
- Playback + search result mapping + white text on search results (`ec8d60e`).
- `MpvPlayer` annotation resolved; `daemonConnected` access qualified in QML (`f8b0f0a`).
- Daemon connected state exposed to QML so the banner was no longer falsely shown (`6ffd227`).
- Merged audit fixes + UI revamp into the unified single-process architecture (`90094b4`).

---

## [Unreleased] — 2026-08-01 (Phase C — UI Revamp)

### Added
- **Phase C UI revamp (UI-1–UI-10)** per `docs/sonictune_audit_report.md` (Kimi) + v10 spec.
- Material Symbols icon font (Material Icons glyph set) at `src/sonictune/ui/qml/fonts/MaterialSymbols.ttf`, registered in `app.py` via `QFontDatabase` (`UI-1`).
- NEW `components/STIcon.qml` — icon component, zero emoji, Material Symbols glyph map (`UI-2`).
- NEW `components/STButton.qml` — Material 3 button (Filled/Tonal/Outlined/Text/Elevated) (`UI-3`).
- NEW `components/STCard.qml` — unified media card with hover play overlay (`UI-4`).
- NEW `components/STSlider.qml` — Material 3 slider (`UI-5`).
- NEW `components/BottomNav.qml` — bottom navigation for narrow windows (`UI-9`).
- NEW `components/STSkeleton.qml` — shimmer loading placeholder (`UI-10`).
- Theme: added M3 `primaryContainer`, `onPrimaryContainer`, `secondary`, `secondaryContainer`, `onSecondaryContainer` color roles.
- Home feed normalization in `daemon_proxy.getHome()` → QML-friendly sections (`UI-7`).

### Changed
- `PlayerBar.qml` rewritten with STSlider + STIcon; compact mode for narrow windows (`UI-6`).
- `NavRail.qml` widened to 80px (M3 spec) and uses STIcon (`UI-8/3.15`).
- `main.qml` responsive: NavRail ≥960px, BottomNav <960px; PlayerBar compact <960px (`UI-9`).
- `HomePage.qml` loads `Daemon.getHome()` on start, shows skeleton rows while loading, uses STCard/STButton (`UI-7`, `UI-10`).
- `AlbumCard.qml`/`PlaylistCard.qml`/`ArtistCard.qml` deleted — replaced by `STCard.qml`.
- `NowPlayingPage.qml` — added missing `shuffle`/`repeat` bindings, uses STIcon (`UI-8/2.6`).
- `SearchPage.qml` — filter chips use a `currentFilter` property instead of fragile children traversal (`UI-8/2.5`).
- `QueueDrawer.qml` — removed deprecated `arguments.callee` (`UI-8/2.7`).
- `TrackList.qml` — context menu uses captured `itemVideoId` at delegate root (`UI-8/2.9`).
- `LoadingOverlay.qml` — `enabled: opacity > 0.5` so it never blocks input during fade (`UI-8/2.10`).
- `StatsPage.qml` — bar chart max-hour guard for empty data (`UI-8/3.13`).
- `SettingsPage.qml` — version from `AppVersion` context property; fixed repo URL (`UI-8/2.8`, `3.17`).
- `pyproject.toml` — `yourusername` URLs → `CodeAbhi826/sonictune` (`3.17`).

### Fixed
- QML Rule 21: `STIcon` no longer shadows built-in `color` property.
- `STButton` requires `Qt5Compat.GraphicalEffects` import for DropShadow.

### Docs Updated
- `docs/CHANGELOG.md` (this file).

## [Unreleased] — 2026-07-31 (Phase B — Service fixes)

### Added
- **Phase B fixes (SB-1–SB-10)** per `docs/sonictune_audit_report.md` (Kimi) + v10 spec.
- OAuth token refresh: `OAuthManager.ensure_valid_token()` refreshes before expiry, called before every YTMusic API call (`SB-4`).
- Play start-time tracking in `MpvPlayer`/`NullPlayer` (`play_started_at`, `_iso_started_at`) passed to `record_play()` (`SB-5`).
- DiscordRPC wired to player events (`TRACK_CHANGED`/`STATE_CHANGED`) — previously dead code (`SB-6`).
- `Track.from_ytmusic()` now parses `duration_seconds` (int or "3:45") or `duration` into `duration_ms` (`SB-7`).
- Queue: `can_go_next()`/`can_go_previous()` lock-guarded helpers; MPRIS `CanGoNext`/`CanGoPrevious` are async getters (`SB-3`).
- Tests: `tests/test_models.py` (duration parsing), `tests/test_oauth.py` (token refresh), new queue shuffle-history tests.

### Fixed
- MPRIS `LoopStatus`/`Shuffle` setters now wire to `queue.set_repeat()`/`set_shuffle()` (`SB-1`).
- MPRIS `Next()`/`Previous()` use `queue.advance()`/`go_back()` instead of non-mutating getters (`SB-2`).
- `jump_to()` in shuffle mode pushes the current track onto history instead of linear ranges (`SB-9`).
- `remove_at()` in shuffle mode adjusts `_shuffled_position`/`_shuffled_order` instead of blindly rebuilding (`SB-10`).
- C-locale via `ctypes.setlocale` already present in `app.py` (`SB-8`).

## [Unreleased] — 2026-07-31 (Phase A — Unification)

### Added
- **Phase A unification (UA-1–UA-9)**: SonicTune is now a single process. The daemon + D-Bus split was removed; QML talks to services via a direct-call `DaemonProxy` (same signal/slot names, Rule 24).
- NEW `src/sonictune/app.py` — `SonicTuneApp` owns all services, sets C locale via `ctypes.setlocale` pre-import, sets up QML engine + tray, clean shutdown. Entry point: `sonictune.app:main`.
- NEW `src/sonictune/ui/daemon_proxy.py` — direct Python proxy replacing `dbus_client.py`.
- NEW `src/sonictune/ui/tray.py` — system tray (show/hide/quit), minimize-to-tray.
- NEW `tests/test_app.py` — direct tests of `DaemonProxy` (signals, slots, player events, transport, library, stats, end-of-track auto-advance). Replaces `tests/test_e2e.py`.
- `ArtCache.get_sync()` — synchronous art fetch for the Qt image provider thread.
- `--no-mpris` / `--no-discord` / `--verbose` / `--config` CLI flags on `sonictune.app:main`.

### Changed
- Flattened package layout: `src/sonictune/daemon/{auth,library,player,cache,lyrics,stats,mpris,discord,db,history,utils,config}` → `src/sonictune/…`. All imports updated.
- `ui/main.py` is a thin wrapper around `app.main()`.
- `ui/imageprovider.py` reads directly from `ArtCache` (no D-Bus bridge).
- `ui/main.qml` — removed the "Cannot reach daemon" connection banner (always connected, Rule 23).
- `scripts/run-ui.sh` → `scripts/run.sh` (single launch command: `./scripts/run.sh`).
- `pyproject.toml` entry point: `sonictune = "sonictune.app:main"` (removed `sonictuned`).
- `meson.build` — removed `sonictuned` wrapper + systemd unit install.
- `config.py` — removed stale `dbus_bus_name` field.

### Deleted
- `src/sonictune/daemon/dbus/` (interfaces.py, etc.) — the D-Bus server is gone.
- `src/sonictune/daemon/sonictuned.py` — daemon entry (merged into `app.py`).
- `src/sonictune/ui/dbus_client.py` — replaced by `daemon_proxy.py`.
- `scripts/run-daemon.sh`, `scripts/sonictuned.in`, `scripts/sandbox-test.sh`.
- `data/org.sonicTune.Daemon.service` — systemd unit (no longer needed).
- `tests/test_e2e.py` — D-Bus subprocess tests.

### Fixed
- `MprisServer.__init__()` rejected a `stats=` kwarg passed by the spec's `app.py` — removed it so MPRIS registers.
- `daemon_proxy.py` used `RepeatMode` and `TrackInfo` without imports (`NameError` at runtime) — added imports.
- Circular import: `ui/__init__.py` eagerly imported `ui.main` — made passive.
- `meson.build` referenced the deleted `org.sonicTune.Daemon.service` — removed the block.
- Docs updated to single-process architecture: `ARCHITECTURE.md`, `DBUS_INTERFACE.md` (MPRIS only), `SETUP.md`, `ROADMAP.md`, `README.md`.

### Removed (from earlier versions — superseded by unification)
- Bug 28/30 fixes for the D-Bus client (`@asyncSlot`, signal return annotations) — the D-Bus layer they fixed is deleted.
- Bug 24/25/27/31/32 remain valid for the UI and are unchanged.

### Known Issues (unfixed)
- Daemon crashes with SIGSEGV (exit 139) at `mpv_set_option` when running through `sonictuned` console_script entry point. Root cause unknown — isolated `MpvPlayer.init()` tests pass successfully. Likely a threading/event-loop interaction with python-mpv's ctypes/libffi calls during mpv handle creation.

---

## [2026-07-27] — Pre-unification

### Fixed
- Bug 32 (BF-23): OAuthDialog single "Copy" button combined URL+code. Split into "Copy URL" + "Copy Code"; added ClipboardHelper (clipboard.py) registered as `Clipboard` context property.
- Bug 31 (BF-22): NavRail "Now Playing"/"Settings" swapped — StackLayout child order now matches NavRail order.
- Bug 30 (BF-21): daemon `@signal()` methods had no return annotations — dbus-next derives signal signatures from the return annotation, so all signals were introspected/emitted with zero args. Added return annotations + return values; client now registers handlers and receives data.
- Bug 28 (BF-21): DaemonClient.connect() never ran. Root cause: main.py called `app.exec()` directly, which runs only Qt — qasync's asyncio loop was never driven. Fix: `loop.run_forever()` (drives both) + `@asyncSlot()` on `_start_connect`.
- Bug 27 (BF-20): pages didn't switch — custom `property int currentIndex` shadowed StackLayout's built-in. Fix: deleted the shadowing declaration.
- Bug 26 (BF-19): HomePage "Sign in" button now opens OAuthDialog instead of logging "TODO" (SettingsPage was already wired in a previous pass).
- Bug 26 (BF-18): Theme singleton not registered. Every QML file referencing Theme.* got undefined (~17 errors). Fix: added `pragma Singleton` to Theme.qml, created theme/qmldir, added `engine.addImportPath()` in main.py.
- Bug 26 (BF-18): Added missing `fontHeadlineSmall` property to Theme.qml (used by HomePage.qml but not defined).
- Bug 26 (BF-18): Fixed StatCard.qml parent traversal — replaced fragile `parent.parent.parent.title` with `root.title`/`root.value` via `id: root`.
- Bug 25 (BF-17): UI crash with `TypeError: object does not support the context manager protocol` (Python 3.12+) — replaced `with loop: return loop.run_forever()` with `return app.exec()`. Window now opens and stays open.
- Bug 24 (BF-16): INCORRECTLY ATTEMPTED — reintroduced `with loop:` + `loop.run_forever()` which were previously fixed in Bug 6 and Bug 11.
- Bug 23 (BF-15): MPRIS split — MprisInterface split into MprisRootInterface + MprisPlayerInterface, both exported at /org/mpris/MediaPlayer2
- Bug 22 (BF-14): mpv SIGSEGV due to non-C locale. Root cause: libmpv requires LC_ALL=C, not just LC_NUMERIC. Fix applied in 3 places: `scripts/run-daemon.sh` (export LC_ALL=C env var), `mpv_player.py:init()` (setlocale LC_ALL right before mpv.MPV()), `sonictuned.py:23` (changed LC_NUMERIC to LC_ALL).
- Bug 13: OAuth token now loaded on daemon startup via `await oauth.init()` in `sonictuned.py`
- Bug 10: Added `Metadata` `@dbus_property` to MPRIS interface
- Bug 12: Added `access=PropertyAccess.READ` to all 17 read-only MPRIS properties
- Bug 11: UI event loop — replaced `loop.run_forever()` with `app.exec()` for qasync integration
- Bug 11: All `@Slot(result=...)` in `dbus_client.py` converted to async signal-based pattern
- Bug 11: All QML pages updated to use signal-based async pattern
- Bug 14: Injected `DaemonConfig` into `PlayerInterface`, `MprisInterface`, `DBusServer`, `MprisServer`
- Bug 14: Replaced `AudioConfig()` with `self._config.audio` in all stream URL lookups
- Bug 16: Updated systemd service file with env vars, SyslogIdentifier, CollectMode
- Bug 17: Replaced `__import__("datetime")` with proper `from datetime import datetime`
- Bug 18: Refactored `sync_library()` to `LibrarySync` class with progress callbacks
- Bug 18: Added `SyncProgress` and `SyncComplete` D-Bus signals; sync runs fire-and-forget
- Bug 19: Added per-video cache + dedup locks + global 2s rate limit on `get_stream_url`
- Bug 20: Changed `TrackInfo` import from `mpv_player` to `player.types`
- Bug 21: Thread-safe `_on_position`/`_on_duration` via `call_soon_threadsafe`
- Bug 1: Moved `self._loop` from `MpvPlayer.__init__` to `init()` as Hypothesis A fix

- Bug 23 (BF-15): Split `MprisInterface` into `MprisRootInterface` and `MprisPlayerInterface`
- Bug 23 (BF-15): Both interfaces now exported at `/org/mpris/MediaPlayer2` — `org.mpris.MediaPlayer2.Player` is now visible to D‑Bus consumers
- Bug 23 (BF-15): Removed `--no-mpris` flag from E2E daemon fixture; added MPRIS E2E tests (bus name, introspection, property access)

### Changed
- Updated GitHub URLs from `yourusername` to `CodeAbhi826` across all source files, docs, and metadata
- Added E2E test suite (`tests/test_e2e.py`) for daemon D-Bus interface verification

### Known Issues (unfixed)
- Daemon crashes with SIGSEGV (exit 139) at `mpv_set_option` when running through `sonictuned` console_script entry point. Root cause unknown — isolated `MpvPlayer.init()` tests pass successfully. Likely a threading/event-loop interaction with python-mpv's ctypes/libffi calls during mpv handle creation.
