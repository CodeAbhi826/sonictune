# SonicTune

**A native Linux YouTube Music client built for performance, privacy, and power users.**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Linux](https://img.shields.io/badge/platform-Linux-1793D1?logo=linux&logoColor=white)](https://www.kernel.org/)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Qt6](https://img.shields.io/badge/Qt-6.7+-41CD52?logo=qt&logoColor=white)](https://www.qt.io/)
[![CI](https://github.com/CodeAbhi826/sonictune/actions/workflows/ci.yml/badge.svg)](https://github.com/CodeAbhi826/sonictune/actions/workflows/ci.yml)

SonicTune is a FOSS YouTube Music client for Linux that prioritizes native performance, hardware acceleration, and a clean Material 3-inspired UI. It runs as a **single process** — a QML frontend and all music services (auth, library, libmpv player, caches, stats) in one app. MPRIS provides desktop/media-key integration.

> **Status:** Phase 1 (Core) — actively developed. See [ROADMAP.md](docs/ROADMAP.md).

---

## ✨ Features

### Phase 1 (Current)
- 🔐 **OAuth login** (TV device code flow — no browser embedding) + cookie import fallback
- 🔍 **Search & browse** YouTube Music (Home, Charts, Library, Artists, Albums, Playlists)
- 🎵 **256 kbps AAC playback** via libmpv (hardware-decoded, gapless)
- 🎨 **Album art pipeline** with on-disk LRU cache + QQuickImageProvider
- 📜 **Synced lyrics** via LRCLIB (FOSS, no API key)
- 🎛️ **Queue management** (shuffle, repeat, drag-to-reorder)
- 🚇 **MPRIS** integration (KDE/GNOME media controls, lockscreen)
- ⌨️ **Keyboard shortcuts** + media keys

### Phase 2 (Planned)
- 📚 Full library sync (playlists, likes, uploads)
- 🕒 History sync back to YouTube (for YouTube Recap)
- 🎬 Regular YouTube video playback (mpv video surface)
- 📁 Local library management

### Phase 3 (Planned)
- 💾 Offline cache + downloads (configurable quality)
- 📊 Stats dashboard (year recap, listening hours, top artists)
- 🎨 Discord Rich Presence
- 😴 Sleep timer, crossfade, audio normalization
- 🎨 Themable UI (Material 3 presets)

---

## 🏗️ Architecture

```
┌────────────────────────────────────────────┐
│          SonicTune (single process)        │
│  QML UI (Material 3)                       │
│    └── DaemonProxy (direct Python calls)   │
│  Services: auth, library, player, caches,  │
│            lyrics, stats, DB, discord      │
│  System tray (minimize-to-tray)            │
│  MPRIS (external D-Bus, desktop only)      │
└────────────────────────────────────────────┘
```

**Why a single process?**
- No D-Bus IPC → no Variant wrapping, no signal mismatches, one event loop
- The UI and services share state directly; no connection management
- Simpler code, fewer bugs (the old daemon/UI split was the root cause of most)

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

---

## 🚀 Quick Start

### Requirements
- Linux (Wayland or X11)
- Python 3.11+
- Qt 6.7+ (PySide6)
- libmpv (≥ 0.36)
- PipeWire or PulseAudio
- `uv` (recommended) or `pip`

### One-shot setup

```bash
git clone https://github.com/CodeAbhi826/sonictune.git
cd sonictune
./scripts/setup-dev.sh
```

This installs all dependencies (system + Python) and sets up the dev environment.

### Run it

```bash
./scripts/run.sh            # or: python -m sonictune.app
./scripts/run.sh --verbose  # debug logging
```

On first launch, the UI will prompt you to log in via OAuth (TV device code flow — you'll see a URL + code on screen, visit it in any browser, enter the code, done).

---

## 📦 Installation (end-user, future)

Once Phase 1 is stable, we'll publish:
- **Flatpak** on Flathub (primary)
- `.deb` via PPA
- `.rpm` via Copr
- AUR package

For now, build from source using the quick start above.

---

## ⚙️ Configuration

Config lives at `~/.config/sonictune/config.toml`. Defaults:

```toml
[audio]
quality = "aac_256"           # aac_256 (Premium, 256kbps) | opus_160 (free, 160kbps)
normalization = true           # EBU R128 loudnorm
gapless = true

[cache]
audio_size_mb = 1024           # 1 GB LRU audio cache
art_size_mb = 256              # 256 MB art cache
directory = "~/.cache/sonictune"

[ui]
theme = "dark"                 # dark | light | archive
volume_step = 5

[discord]
enabled = false
client_id = ""                 # Your Discord app client ID
```

---

## 🛠️ Development

```bash
# Install dev dependencies
uv sync --dev

# Run tests
pytest

# Lint
ruff check src tests
ruff format --check src tests

# Type check
mypy src
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full dev guide.

---

## 🔌 MPRIS Integration

SonicTune exposes standard [MPRIS v2](https://specifications.freedesktop.org/mpris-spec/latest/) on the session bus for desktop integration (media keys, lockscreen, GNOME/KDE playback widgets):

- Bus name: `org.mpris.MediaPlayer2.sonictune`
- Object path: `/org/mpris/MediaPlayer2`

Full spec: [docs/DBUS_INTERFACE.md](docs/DBUS_INTERFACE.md).

You can introspect with:
```bash
gdbus introspect --session --dest org.mpris.MediaPlayer2.sonictune --object-path /org/mpris/MediaPlayer2
```

---

## 📝 License

GPL-3.0-or-later. See [LICENSE](LICENSE).

SonicTune uses [yt-dlp](https://github.com/yt-dlp/yt-dlp) and [ytmusicapi](https://github.com/sigma67/ytmusicapi) for content access. It is not affiliated with YouTube or Google. Users are responsible for complying with YouTube's Terms of Service.

---

## 💬 Community

- **Issues:** [GitHub Issues](https://github.com/CodeAbhi826/sonictune/issues)
- **Discussions:** [GitHub Discussions](https://github.com/CodeAbhi826/sonictune/discussions)
- **Matrix:** `#sonictune:matrix.org` (coming soon)

---

## 🙏 Acknowledgements

- [ytmusicapi](https://github.com/sigma67/ytmusicapi) — YT Music API
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — YouTube video extraction
- [mpv](https://github.com/mpv-player/mpv) — the best media player
- [Kirigami](https://develop.kde.org/frameworks/kirigami/) — QtQuick layout framework
- [LRCLIB](https://lrclib.net) — synced lyrics database
- Inspired by [Spot](https://github/xou816/spot), [Elisa](https://invent.kde.org/multimedia/elisa), [Amberol](https://gitlab.gnome.org/World/amberol)
