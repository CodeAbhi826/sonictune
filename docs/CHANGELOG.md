# Changelog

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
