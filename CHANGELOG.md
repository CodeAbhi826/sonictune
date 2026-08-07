# SonicTune Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Visual Regression Testing**: Added automated visual tests using Playwright to detect UI glitches. ([TESTING.md](TESTING.md))
- **MCP Image Validation**: Support for `data:image/...` URIs in `ArtImageProvider` to fix base64 PNG/SVG loading issues.
- **Application Icon**: Set window icon to use `data/org.sonicTune.svg`.
- **GitHub Codespaces**: Added `.devcontainer` configuration for remote testing.
- **Ejentum MCP Integration**: Wired `ejentum-mcp` (cognitive operations for reasoning, code, anti-deception, memory) into the local opencode config; API key exposed via project `.env` and shell profile. Verified end-to-end (initialize + live tool call).
- **E2B Sandbox Runner**: Added `scripts/e2b_runner.py` for sandboxed testing (`--test`), app visual inspection (`--app`), headless opencode runs (`--opencode`), and API-key validation (`--check`). Verified `e2b_` key and `opencode` template end-to-end.
- **oh-my-openagent**: Installed the OpenCode edition (`bunx oh-my-openagent install --no-tui --platform=opencode ... --skip-auth`), registered `oh-my-openagent@latest` in the global opencode config, and remapped all omo agents/categories to the existing `morph` provider models (Kimi K3, GLM-5.2, Qwen 3.5, MiniMax M3, DeepSeek V4 Flash). `doctor` passes with warnings only.
- **OpenAgentsControl**: Installed locally (`.opencode/`), adding `OpenAgent`/`OpenCoder` agents, subagents, productivity commands (`/add-context`, `/commit`, `/test`, `/optimize`, …), and the MVI context system (approval-gated, plan-first workflow).
- **Qt-native visual regression test**: Rewrote `tests/visual/test_main_window.py` to launch the real app under Xvfb (pyvirtualdisplay) and capture the window with ImageMagick, replacing the Playwright test that targeted a non-existent web UI on `localhost:8000`. Baseline captured and the diff test passes; `UPDATE_BASELINE=1` regenerates baselines. Added `numpy` to the dev/test deps for pixel diffing.

### Fixed
- **Image Loading**: Base64-encoded PNGs and SVGs now load correctly in the UI.
- **Stale queue emissions** (`daemon_proxy.py`): `queueChanged` now emits only *after* `remove_at`/`clear`/`set_shuffle`/`set_repeat` complete instead of firing with pre-mutation state.
- **Dead QML error binding** (`main.qml`): removed `onError` handler that could never fire (PySide6 only registers `errorOccurred`); the working `onErrorOccurred` handler remains.
- **Duplicate error emit**: `_play_track` no longer emits `errorOccurred` twice on failure.
- **Deprecated loop APIs**: `asyncio.get_event_loop()` → `get_running_loop()` in `local_scanner.py` and `color_extractor.py`.
- **Devcontainer (BUG3)**: Python pinned to 3.12; Xvfb moved to `postStartCommand`; `DISPLAY` persisted via `/etc/profile.d/sonictune-dev.sh` instead of a per-script `export`.
- **QML launch fixes**: `SyncedLyricsView.qml` `onCurrentPositionMsChanged` handler moved onto `root` and switched to array indexing (was on `ListView` with ListModel APIs → compile error); missing `id: header` added; `qrc:/qml/pages/*.qml` URLs replaced with relative paths in `main.qml` and `NavRail.qml` (no `.qrc` resource exists).
- **Undeclared signals**: declared 15 missing `Signal`s (`homeError`, `lyricsError`, `playlistTracksReceived/Error`, `startOAuthError`, `pollOAuthError`, `statsError`, `syncLibraryError`, `searchSongsError`, `searchHistoryError`, `librarySongs/Albums/PlaylistsError`, `audioCacheSizeReceived/Error`, `audioCacheCleared`) that were emitted but never defined, which would raise `AttributeError` inside error handlers. App now reaches `app.qml_ready` with zero QML warnings.

### Changed
- **Testing Workflow**: Documented MCP-based testing and changelog update rules in `AGENTS.md`.
- **Secrets Hygiene**: `.env` and `.env.*` now ignored by git.

---

## [0.1.0] - 2026-08-02

### Added
- Initial release of SonicTune with Phase 1-4 features (Navigation, Material You, Local Library, Lyrics, Performance).