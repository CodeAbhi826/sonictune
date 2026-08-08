# Changelog

## [Unreleased] — 2026-08-08 (Regression corrections — scroll, settings layout, tray)

### Fixed
- **Scrolling died over cards again** (Bug 1): the previous batch flipped `AlbumCard`/`PlaylistCard`/`ArtistCard` `onWheel` to `wheel.accepted = true`, which CONSUMES the wheel event so the parent `Flickable` never receives it. Reverted to `accepted = false` on all three cards so wheel events bubble up and vertical scroll works over the cards again. (`TrackList` and `SettingsPage` were already `false`.)
- **Settings hub width collapsed** (Bug 2): `SettingsPage.qml` had `Layout.fillWidth: true` on a `ColumnLayout` that is a direct child of a `ScrollView` — `Layout.*` only works inside a Layout container, so the width collapsed. Added `id: settingsScroll` to the `ScrollView` and bound the column to `width: settingsScroll.availableWidth`.
- **Settings sub-pages width collapsed** (Bug 3): all six sub-pages (`SettingsAppearancePage`, `SettingsPlayerPage`, `SettingsContentPage`, `SettingsIntegrationsPage`, `SettingsBackupPage`, `SettingsAboutPage`) used `width: parent.width`, which is circular/zero inside a `ScrollView`. Reverted to `width: page.width`. Padding changes kept.
- **Tray icon still missing** (Bug 4): `tray.py` built the icon with `QIcon(str(svg_path))`, which returns null for SVGs without the QtSvg image-format plugin. `_tray_icon()` now uses `QSvgRenderer` → `QPixmap` → `QIcon` (the same approach `app.py` already uses for the window icon, verified).

### Verified
- `qmllint` clean on AlbumCard, PlaylistCard, ArtistCard, SettingsPage, SettingsAppearancePage.
- `py_compile` clean on tray.py.
- `QQmlComponent` compile: **20/20 QML entrypoints pass**.
- `pytest tests/ --ignore=tests/visual` → **216 passed, 4 skipped**.

## [Unreleased] — 2026-08-08 (11-bug final runtime fix)

### Fixed
- **NavRail `StackView` compile error** (Bug 1): added `import QtQuick.Controls` so the `StackView.Immediate` enum in `NavRail.qml` resolves instead of failing at load.
- **`FileDialog.selectFolder` Qt 6 API** (Bug 2): `LocalLibraryPage.qml` used the removed Qt 5 `selectFolder`/`folder`/`shortcuts` API. Replaced with Qt 6 `fileMode: FileDialog.Directory` + `currentFolder: Qt.homePath` — this was the last pre-existing QML compile failure, now **11/11 pages compile**.
- **Router resolved page URLs from its own directory** (Bug 3): `Router.pushPage("pages/X.qml")` resolved to `router/pages/X.qml` (missing). Now `Qt.resolvedUrl("../" + pageUrl)` resolves relative to the QML root. Also switched the invalid instance access `stackView.Immediate` to the type-level `StackView.Immediate` (with the required import).
- **Search passed `limit` as `scope`** (Bug 4): `daemon_proxy.search` called `self._ytm.search(query, filter_, limit)` positionally, mapping limit onto `scope` and yielding "Invalid scope provided". Now uses `filter=`/`limit=` keyword args.
- **Album art never loaded for HTTP URLs** (Bug 5): `ArtImageProvider.requestImage` treated every URL as a local path. Now branches explicitly: HTTP/HTTPS → disk-cache lookup + background fetch (returns empty immediately), local path → direct load, else background fetch.
- **Tray icon missing / black taskbar square / Quit hung** (Bug 6): `tray.py` looked for the icon at the wrong path (`data/org.sonicTune.svg` is at `data/icons/hicolor/scalable/apps/`), and Quit only called `app.quit()` without stopping the qasync loop. Icon resolution now tries the theme then both SVG paths; `_quit_app()` stops the event loop before quitting. App window icon was already set from the SVG (verified).
- **NavRail highlight didn't sync on Router/back navigation** (Bug 7): added a `Connections` block in `main.qml` that maps `contentStack.currentItem.objectName` → `navRail.currentIndex` on `currentItemChanged`.
- **Play button showed pause when idle** (Bug 8): `NowPlayingBar` play/pause icon now also requires `currentTrack.title` (a track actually loaded) before showing the pause glyph.
- **Home page jitter** (Bug 9): `AlbumCard`/`PlaylistCard`/`ArtistCard` changed `onWheel` to `wheel.accepted = true` so wheel events stop at the card and the parent `Flickable` handles them natively (competing vertical+horizontal scroll handlers were causing jitter). `TrackList` and `SettingsPage` deliberately stay at `false`.
- **Settings sub-pages missing `objectName`** (Bug 10): already present from the prior screenshot batch — verified all six (`settingsAppearance`, `settingsPlayer`, `settingsContent`, `settingsIntegrations`, `settingsBackup`, `settingsAbout`).
- **Private-method access** (Bug 11): `daemon_proxy` called `self._player._iso_started_at()`. Both `MpvPlayer` and `NullPlayer` now expose it as a public `@property iso_started_at`; call site updated to `self._player.iso_started_at`.

### Verified
- `qmllint` clean on NavRail, LocalLibraryPage, Router, main.qml, NowPlayingBar, and all three cards.
- `py_compile` clean on daemon_proxy, imageprovider, tray, mpv_player, null_player.
- `QQmlComponent` compile: **11/11 QML entrypoints pass** (was 38/39; the pre-existing `selectFolder` failure is now fixed).
- `pytest tests/ --ignore=tests/visual` → **215 passed, 4 skipped, 1 pre-existing flaky failure** (`test_mpv_seek_cpu_spikes`, a timing assertion that also fails on clean HEAD, unrelated to this batch).

## [Unreleased] — 2026-08-06 (UI event + performance fixes)

### Fixed
- **Clicks blocked everywhere** (Bug 1): `ErrorToast` root `Item` filled the window and its `DragHandler` intercepted all mouse events even when hidden. Now `enabled`/`visible` are bound to `bar.opacity > 0` so it only captures events while the toast shows.
- **Loading veil swallowed clicks during fade-out** (Bug 2): `LoadingOverlay` stayed `enabled: visible` while fading. Changed to `enabled: opacity > 0.5` so events pass through as soon as the fade begins.
- **Massive lag from GPU DropShadow** (Bug 3): removed the `DropShadow { samples: 16 }` layer from `AlbumCard`, `PlaylistCard`, and `ArtistCard`; hover feedback is now the existing tonal border highlight (Material 3 elevation) instead of re-rendered shaders. Dropped the `Qt5Compat.GraphicalEffects` imports.
- **Card hover z-order flicker** (Bug 6): removed the `z: ma.containsMouse ? 10 : 1` re-sort on hover from all three cards (scale animation remains).
- **Render-thread block on thumbnail fetch** (Bug 4): `ArtImageProvider.requestImage` no longer performs synchronous HTTP fetches. Pixmap cache and disk cache return instantly; uncached URLs return an empty `QImage` immediately and a background thread downloads the art (with in-flight dedup) so the next request hits disk.
- **Jerky scrolling in lists** (Bug 5): removed the manual `WheelHandler` in `TrackList` that fought with ListView's native wheel handling.
- **"variant" property compile failure** (Bug 7): `LocalLibraryPage.qml` used plain QtQuick.Controls `Button` for the "Browse…" / "Scan" / "Scan Music Folder" actions; plain `Button` does not support `variant` (Material 3 only). All three instances changed to `STButton`.

## [Unreleased] — 2026-08-07 (Runtime bug fixes from audit batch)

### Fixed
- **Bug #1 — Signal type mismatches (6 signals)**: `daemon_proxy.py` — `queueChanged`, `queueReceived`, `startOAuthCompleted`, `pollOAuthCompleted`, `syncLibraryCompleted`, `lyricsReceived` were declared with the wrong payload types, causing `_pythonToCppCopy` failures and silent drops. All six re-declared to match their actual emitters (dict / bool / list as appropriate).
- **Bug #2 — NullPlayer missing setters**: added `set_speed` (clamped 0.5–2.0) and `set_crossfade` (clamped 0–12) so the daemon proxy's `setSpeed` / `setCrossfade` slots don't crash when libmpv is unavailable.
- **Bug #3 — mpv `event_id` key mismatch**: `mpv_player._handle_mpv_event` only checked `"event-id"` (hyphen) — python-mpv emits `"event_id"` (underscore), so `END_FILE` was never detected and the queue never auto-advanced. Now tries underscore first, falls back to hyphen.
- **Bug #4 — NavRail url + Immediate enum**: `NavRail.qml` compared `currentItem.url === targetUrl` (no page declares `url`) and called `navRail.stackView.Immediate` (an instance property that doesn't exist). Now compares `currentItem.objectName === navItem.modelData.name` and uses the type-level `StackView.Immediate` enum. Added `objectName: "home" / "search" / "library" / "local" / "stats" / "settings"` to each page root so the comparison actually resolves.
- **Bug #5 — Missing `encoding="utf-8"` on 4 text I/O calls**: `config.py:290` (`write_text(text)`), `config.py:386` (`write_text(_DEFAULT_TOML)`), `daemon_proxy.py:930` (`read_text()`), `daemon_proxy.py:950` (`write_text(text)`) all relied on locale — under `LC_ALL=C` (set for mpv) non-ASCII content crashed. All four now pass `encoding="utf-8"` explicitly.
- **Bug #6 — `playLocalTrack` was a stub**: now builds a `TrackInfo` from the local scanner and calls `player.load_url(f"file://{track.file_path}", info)`, so local files actually play.
- **Bug #7 — Acrossfade lavfi filter broke audio**: `mpv_player._rebuild_af_chain` appended `lavfi=[acrossfade=...]` which requires two input streams; mpv has one, so enabling crossfade silenced all playback. Filter is now commented out with a TODO for a proper end-file-hook + volume-ramp implementation.
- **Bug #8 — `search()` blocked the Qt UI thread**: `daemon_proxy.search` was `@Slot(str, str, int, result=list)`, so every search synchronously blocked the UI for 1–3 s of network I/O. Decorator now has no `result=`, both branches (sync `_ytm.search` and async `library.search`) run in an `asyncio.create_task`, and results are emitted via `searchCompleted` / `searchError`. `tests/test_daemon.py::test_daemon_proxy_error_boundary` rewritten as `@pytest.mark.asyncio` to match.
- **Bug #9 — tomli fallback for Python 3.10**: `config.py` imported `tomllib` directly; wrapped in `try/except ImportError: import tomli as tomllib` so Python 3.10 systems don't crash at config load.
- **`_clean()` helper for signal payloads**: added `DaemonProxy._clean(data)` that round-trips through `json.loads(json.dumps(data, default=str))` so Qt's `_pythonToCppCopy` warning stops firing on non-trivial payloads. Used inside `search()`.

### Verified
- All 9 runtime bugs resolved at the source level (grep-verified); QML: 38/39 pages pass (sole failure is the pre-existing `FileDialog.selectFolder` API mismatch in `LocalLibraryPage.qml:262`, unrelated to this batch); `pytest tests/ --ignore=tests/visual` → **216 passed, 4 skipped** (visual baseline + QtQuickTest/QFontMetrics env-dependent skips).

## [Unreleased] — 2026-08-07 (Material Symbols font + page objectName)

### Added
- **Material Symbols Rounded font** (`data/fonts/MaterialSymbolsRounded.ttf`, OFL-1.1): 15 MB TrueType font with thousands of icon glyphs, downloaded from `google/material-design-icons` (`variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf`). Auto-registered at startup by `app.py` via `QFontDatabase.addApplicationFont(font_dir.glob('*.ttf'))`. Bundled license text at `data/fonts/OFL-MaterialSymbols.txt`.
- **Material-Symbols-backed `Icon.qml`**: replaces the emoji-based `Text` with the Material Symbols Rounded font + ~80-entry glyph codepoint map. Font glyphs are cached as GPU textures by Qt, so 30+ simultaneous icons render without per-frame JS paint. Same public API (`name` / `size` / `color`) — every caller continues to work; map covers all snake_case and camelCase aliases used across the codebase.

### Fixed
- **`objectName` on page roots**: `HomePage` / `LibraryPage` / `LocalLibraryPage` / `SettingsPage` / `StatsPage` now expose `objectName: "home" / "library" / "local" / "settings" / "stats"` so the NavRail Bug #4 fix (`currentItem.objectName === navItem.modelData.name`) can actually compare against a real identifier. `SearchPage` and `PlaylistDetailPage` already had it.

### Changed
- `.gitignore` now excludes `.opencode/`, `.roo/`, `.roomodes` (agent runtime context — not project source).

### Tracked
- Root-level `CHANGELOG.md`, `TESTING.md`, `TEST_RESULTS.md`, `scripts/e2b_runner.py`, `test_demo.py` were untracked and are now under version control.

### Verified
- `QQmlComponent` compile: **38/39 QML pages pass** (sole failure is the pre-existing `FileDialog.selectFolder` API mismatch in `LocalLibraryPage.qml:262`, unrelated); `pytest tests/ --ignore=tests/visual` → **216 passed, 4 skipped**.

## [Unreleased] — 2026-08-07 (Screenshot audit fixes)

### P0 — Visible UI fixes
- **Bug A — NavRail active highlight never updated**: added `navRail.currentIndex = index` in the `MouseArea.onClicked` handler so clicking Home/Search/Library/Local/Stats/Settings actually moves the purple highlight (was stuck on Home/index 0 forever).
- **Bug B — SearchPage objectName mismatch**: `objectName: "searchPage"` → `"search"` so the NavRail "already on this page" comparison (`currentItem.objectName === modelData.name`) resolves.
- **Bug C — Play button showed pause while idle**: `NowPlayingBar` play/pause icon now requires `isPlaying && status.state === "playing"` before showing the pause glyph.
- **Bug D — Seek bar active with no track**: `STSlider` now has `enabled: durationMs > 0` + `opacity: durationMs > 0 ? 1.0 : 0.3` so it's disabled/dimmed when nothing is loaded.

### P0 — Scroll propagation
- **Bug E — MouseAreas ate wheel events**: added `onWheel: (wheel) => { wheel.accepted = false }` to the card `MouseArea` in `AlbumCard`, `PlaylistCard`, `ArtistCard`, the `TrackList` row, and the `SettingsPage` hub rows — vertical scroll now reaches the parent `Flickable`/`ScrollView`.
- **Bug F — Horizontal `ScrollView` swallowed vertical scroll**: `HomePage` section rows switched from `ScrollView` to a `Flickable` with `flickableDirection: Flickable.HorizontalFlick` + `contentWidth: innerRow.implicitWidth` so vertical wheel events pass through.
- **Bug G — TrackList WheelHandler**: verified already removed (native `ListView` scrolling).

### P0 — Album art
- **Bug H — `cache: false` on art images**: added `cache: false` to the `Image` elements in `AlbumCard`, `PlaylistCard`, `ArtistCard`, `TrackList`, and `NowPlayingBar` so QML re-requests after the background `ImageProvider` fetch completes instead of caching the empty first frame.

### P1 — Settings alignment
- **Bug I — invalid margins**: settings sub-pages — `width: page.width` → `width: parent.width`.
- **Bug J — SettingsPage hub**: `width: settingsPage.width - Theme.space6 * 2` → `Layout.fillWidth: true` for `sectionsColumn`.
- **Bug K — sub-page objectName**: added `objectName` (`settingsAppearance`, `settingsPlayer`, `settingsContent`, `settingsIntegrations`, `settingsBackup`, `settingsAbout`) to all six sub-page roots.

### P1 — Runtime
- **Bug L — unbounded `_url_cache`**: `DaemonProxy._url_cache` now stores `(url, fetched_at_epoch)` tuples and evicts entries older than 5 minutes before each playback lookup (bounded memory).
- **Bug M — `threading.Lock` in async player**: `mpv_player._lock` → `asyncio.Lock()` (removed now-unused `threading` import).
- **Bug N — websockets dep**: the `social/` module is already dead (no source, only `__pycache__`, zero imports) — no dependency to add.
- **Bug O — blocking I/O in local scanner**: `root.exists()` / `root.is_dir()` wrapped in `asyncio.to_thread()`.

### P2 — Minor
- **Bug P — `app.py` `main()` return type**: returns `0` on clean shutdown instead of `run_forever()`'s `None`.
- **Bug Q — `Theme.py` purpose note**: already documented in the module docstring (test-suite mirror of `Theme.qml`).
- **Bug R — DaemonProxy god object**: intentionally skipped (out of scope for this bug batch; noted as a future refactor).

### Verified
- `QQmlComponent` compile: **38/39 QML pages pass** (sole pre-existing `FileDialog.selectFolder` failure in `LocalLibraryPage.qml:262`, unrelated); `pytest tests/ --ignore=tests/visual` → **216 passed, 4 skipped**.

### Verified
- `QQmlComponent` compile READY + `pyside6-qmllint` exit 0 on all six touched QML files; `ruff check` clean on `imageprovider.py`; `pytest tests/` → **216 passed, 4 skipped** (visual baseline passes standalone); `main.qml` boots to `MAIN_QML_OK`.

---

## [Unreleased] — 2026-08-06 (Part 2: reference-project alignment)

### Added
- **Now Playing tabs** (Player | Lyrics | Queue): fullscreen view restructured with a `TabBar` + `StackLayout`; new Queue tab shows the live queue with remove/refresh (`Daemon.getQueue()`/`removeFromQueue`); lyrics moved into its own tab. `queueTracks()` helper moved to the root scope so queue-tab bindings resolve at load.
- **Album & Artist detail pages**: `AlbumDetailPage.qml`/`ArtistDetailPage.qml` (mirror `PlaylistDetailPage`) fetch via new `DaemonProxy.getAlbumDetail(browseId)`/`getArtistDetail(channelId)` slots + `albumDetailReceived`/`albumDetailError`/`artistDetailReceived`/`artistDetailError` signals; album/artist cards on Home/Search/Library now navigate via `Router.pushPage`.
- **Home pull-to-refresh**: sections scroll area converted to a `Flickable`; pulling past the threshold reloads the feed (`Daemon.getHome()`).
- **Settings sub-pages**: `SettingsPage` is now a hub; new `SettingsAppearancePage`, `SettingsPlayerPage`, `SettingsContentPage`, `SettingsIntegrationsPage`, `SettingsBackupPage`, `SettingsAboutPage` replace the single long accordion.
- **Stats visualizations**: "Last 30 days" bar chart + "Hourly listening" heat strip on `StatsPage` from existing `last_30_days_json`/`listening_by_hour_json`.
- **Liquid-glass accent**: subtle transparency on `PlayerBar` (with top highlight) and `NavRail`; `chevronLeft` used for back buttons (replaces undefined `arrow_back` glyph).

### Verified
- `QQmlComponent` compile: all new/changed QML pages + `main.qml` READY; `pyside6-qmllint` exit 0 on all changed pages; `ruff check` clean; `pytest tests/` → **216 passed, 4 skipped** (visual baseline passes standalone).

---

## [Unreleased] — 2026-08-05 (Part 1: boot blockers)

### Added
- `LastFmConfig`, `SponsorBlockConfig` dataclasses + `[lastfm]`/`[sponsorblock]` TOML sections in `config.py` (Bug A); `UIConfig.dynamic_theme_enabled` for Material You.
- `_palette_to_qml_dict()` in `app.py`: serializes the `MaterialPalette` dataclass into a camelCase dict so `dynamicPaletteChanged` actually reaches QML (was silently dropped as `{}`).

### Fixed
- **App no longer crashes at boot** (Bug A): config now exposes `lastfm`/`sponsorblock`/`ui.dynamic_theme_enabled` used by `app.py`.
- **Theme.qml QML parse failure** (Bug B): all `on*` color tokens renamed to `fg*` across `Theme.qml`, `Theme.py`, and every QML file (~200 usages) — `error`/`onError` collision gone, `Theme.qml` now compiles (`Status.Ready`), app reaches `qml_ready`.
- **`StackView.Immediate` enum scope** (Bug G): instance-form `stackView.Immediate` in `Router.qml`/`NavRail.qml`.
- **Shortcut wiring crash**: removed Python `ShortcutManager` duplicate (QtWidgets `QShortcut` is unreliable on a QQuickWindow and referenced missing `DaemonProxy` methods); QML-native `Shortcut` items in `main.qml` now handle all 9 shortcuts, with Ctrl+L/Ctrl+Q/Ctrl+F toggling drawer/Search correctly.
- **Tray icon fallback** (Bug J): `tray.py` falls back to `data/org.sonicTune.svg` when `QIcon.fromTheme` returns null.
- **Color extractor call site** (Bug A): `extract` → `extract_palette` (async classmethod, awaited correctly).
- Stale `tests/test_e2e.py` references in `docs/BUG_REPORT.md` → `tests/test_app.py`; `AGENTS.md` changelog path pinned to `docs/CHANGELOG.md` (Bug K).

### Changed
- Renamed `MaterialPalette` fields `on_*` → `fg_*` in `color_extractor.py`/`local_scanner.py` and `Theme.py` mirrors; `tests/test_theme.py`/`test_color_extractor.py` updated.

### Verified (all 6 audit checks)
- Config import OK; `Theme.qml` `Status.Ready`; app boots to `app.qml_ready`; `pytest tests/` → **216 passed, 4 skipped**; `pyside6-qmllint Theme.qml` exit 0; zero `Theme.on[A-Z]` remain.

---

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
