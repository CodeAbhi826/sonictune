# Roadmap

This document tracks SonicTune's development phases. Dates are estimates
and may shift based on contributor availability.

## Phase 0 — Foundation ✅

**Status:** Complete (in this starter repo)

- [x] Project structure (Meson, Flatpak, src layout)
- [x] GitHub project files (README, LICENSE, CI, issue templates, CONTRIBUTING)
- [x] Build system (Meson + Flatpak manifest)
- [x] Desktop integration (.desktop, AppStream metadata, icon)
- [x] Daemon skeleton (asyncio, D-Bus, config, DB)
- [x] UI skeleton (PySide6 + QML shell, Material 3 theme)
- [x] Documentation (ARCHITECTURE, DBUS_INTERFACE, SETUP)

## Phase A — Unification ✅

**Status:** Complete (v10)

SonicTune is now a **single-process application**. The daemon + D-Bus
split was removed; all services run in the UI process with direct Python
calls. MPRIS remains as the only D-Bus surface (desktop integration).

- [x] Unified application class (`src/sonictune/app.py`)
- [x] Direct-call `DaemonProxy` (replaces the D-Bus client; same QML API)
- [x] Flattened package layout (`src/sonictune/{auth,library,player,...}`)
- [x] Single launch script (`./scripts/run.sh`)
- [x] Simplified `ArtImageProvider` (direct `ArtCache` access)
- [x] System tray (minimize-to-tray)
- [x] Removed connection banner (always connected)
- [x] Direct Python tests (`tests/test_app.py`) replacing D-Bus E2E tests

## Phase 1 — Core Playback 🚧

**Status:** In progress
**ETA:** 2–3 weeks of focused work

### Auth
- [x] OAuth token storage (mode 0600)
- [x] Cookie import fallback
- [ ] **OAuth TV device code flow** (currently stubbed — needs google-auth-oauthlib wiring)
- [ ] OAuth token refresh (automatic before expiry)
- [ ] UI for OAuth flow (show user code, poll for approval) — dialog exists; pending refresh wiring

### Library
- [x] ytmusicapi async wrapper
- [x] Search (songs, albums, artists, playlists)
- [x] Browse (Home, Library songs/albums/playlists)
- [ ] Get track details (full metadata + streaming URL)
- [ ] Get album with track list
- [ ] Get artist page (top songs, albums, related)

### Player
- [x] libmpv integration via python-mpv
- [x] Transport (play, pause, stop, seek, volume)
- [x] Gapless playback config
- [x] Audio normalization (EBU R128)
- [x] State + position signals
- [ ] **Stream URL resolution via yt-dlp** (implemented but untested — needs end-to-end test)
- [ ] End-of-track → advance queue → load next
- [ ] Pre-fetch next track's URL (for true gapless)

### Queue
- [x] Add / remove / clear
- [x] Shuffle
- [x] Repeat (off / all / one)
- [x] Jump to track
- [ ] Drag-to-reorder in QML
- [ ] Save / restore queue across daemon restarts

### UI
- [x] Nav rail + page stack shell
- [x] Home page (auth prompt + section renderer)
- [x] Search page (with filter chips)
- [x] Library page (songs/albums/playlists tabs)
- [x] Now Playing page (large art + lyrics)
- [x] Settings page (account + theme + about)
- [x] Stats page (KPI cards + bar chart)
- [x] Player bar (transport + seek + volume)
- [x] Album art pipeline (QQuickImageProvider + on-disk cache)
- [x] Lyrics view (synced, click-to-seek)
- [x] Queue drawer (slide-out from right)
- [x] Keyboard shortcuts (Space, Ctrl+Arrows, Ctrl+F)
- [ ] **OAuth UI flow** (settings page button → modal with user code)
- [ ] Loading + error states polish
- [ ] Empty state illustrations
### MPRIS
- [x] MPRIS v2 server skeleton
- [x] Transport controls
- [ ] Property change signals (PropertiesChanged)
- [ ] Seeked signal

## Phase 2 — Sync & Library (Planned)

**ETA:** 2 weeks after Phase 1 stable

- [ ] Full library sync (playlists, likes, uploads, history)
- [ ] **History back-sync to YouTube Music** (for YouTube Recap)
- [ ] Regular YouTube video playback (mpv video surface via QQuickFramebufferObject)
- [ ] Local library management (downloaded files + mutagen tags)
- [ ] Playlist creation / editing
- [ ] Liked songs management
- [ ] Listen later queue
- [ ] systemd user service file (auto-start on login, restart-on-crash)

## Phase 3 — Polish & Power Features (Planned)

**ETA:** 2–3 weeks after Phase 2

- [ ] Offline cache UI (configurable size, eviction policy, per-track "downloaded" indicator)
- [ ] Stats dashboard v2 (year recap, top genres, listening streaks, monthly trends)
- [ ] Discord Rich Presence (currently stubbed — needs UI for client_id config)
- [ ] Sleep timer (with fade-out)
- [ ] Crossfade toggle + duration slider
- [ ] Audio normalization toggle in UI
- [ ] Equalizer (mpv `--af=superequalizer`)
- [ ] Skip silence (mpv `--af=silenceremove`)
- [ ] Audio device picker (choose PipeWire sink)
- [ ] Smart playlists (auto-generated based on history)
- [ ] ReplayGain for downloaded files
- [ ] Lyrics offset adjustment UI
- [ ] Full theming system (Material 3 presets, custom accent colors, brand preset)
- [ ] i18n (gettext, initial translations: es, de, fr, ja)
- [ ] Keyboard shortcuts editor

## Phase 4 — Distribution (Planned)

**ETA:** 1 week after Phase 3

- [ ] **Flatpak on Flathub** (primary distribution)
- [ ] .deb via PPA (Ubuntu)
- [ ] .rpm via Copr (Fedora)
- [ ] AUR PKGBUILD (Arch)
- [ ] Nixpkgs package
- [ ] AppStream metadata finalized
- [ ] Release signing (GPG)
- [ ] Automated release pipeline (GitHub Actions on tag push)
- [ ] Marketing screenshots (multiple languages)
- [ ] Website / landing page
- [ ] Matrix room for community

## Phase 5 — Future Ideas (No ETA)

These are stretch goals / community suggestions:

- **Mobile companion app** (Linux phones, Android via Termux?)
- **Web UI** for remote control (small Flask/FastAPI wrapper around D-Bus)
- **Voice control** via local Whisper (offline speech-to-text)
- **Acoustic fingerprinting** for tracks with bad metadata (Chromaprint + AcoustID)
- **MusicBrainz integration** for metadata enrichment
- **Plugin system** (separate processes communicating via D-Bus)
- **Collaborative playlists** (peer-to-peer via libp2p?)
- **HiFi tier support** if YT Music ever adds lossless

## How to contribute to the roadmap

- **Vote:** Use 👍 on issues to vote for features you want.
- **Suggest:** Open a feature request with the "Phase 5 idea" label.
- **Implement:** Pick a Phase 1/2 item from the list above, comment on the
  relevant issue (or open one), and submit a PR. See [CONTRIBUTING.md](../CONTRIBUTING.md).

The roadmap is reviewed monthly. Items may be reordered based on community
feedback and contributor interest.
