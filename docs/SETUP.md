# Setup Guide

Detailed setup for developers and power users. For a quick start, see
the [README](../README.md).

## Prerequisites

### System packages

**Fedora 40+**
```bash
sudo dnf install \
    python3-devel \
    qt6-qtbase-devel \
    qt6-qtdeclarative-devel \
    qt6-qtquickcontrols2-devel \
    mpv-libs-devel \
    pipewire-devel \
    meson \
    ninja-build \
    pkgconf-pkg-config \
    flatpak \
    flatpak-builder
```

**Ubuntu 24.04+ / Debian 13+**
```bash
sudo apt install \
    python3-dev \
    python3-venv \
    qt6-base-dev \
    qt6-declarative-dev \
    qt6-quickcontrols2-dev \
    libmpv-dev \
    libmpv2 \
    meson \
    ninja-build \
    pkg-config \
    flatpak \
    flatpak-builder
```

**Arch Linux**
```bash
sudo pacman -S \
    python \
    python-pip \
    qt6-base \
    qt6-declarative \
    qt6-quickcontrols2 \
    mpv \
    meson \
    ninja \
    pkgconf \
    flatpak \
    flatpak-builder
```

### Python

SonicTune requires **Python 3.11 or newer**. Check with:
```bash
python3 --version
```

If your distro ships an older Python, use [pyenv](https://github.com/pyenv/pyenv)
or [uv](https://github.com/astral-sh/uv) to install a newer one.

### uv (recommended)

[`uv`](https://github.com/astral-sh/uv) is a fast Python package manager.
We strongly recommend it — it's 10–100× faster than pip.

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Get the source

```bash
git clone https://github.com/CodeAbhi826/sonictune.git
cd sonictune
```

## Install Python dependencies

With `uv` (recommended):
```bash
uv sync --dev
```

With plain pip:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

## First run

SonicTune is a single process — run it with one command:

```bash
./scripts/run.sh
```

Add `--verbose` for debug logging. You should see output like:
```
2026-07-31 [info] app.starting version=0.1.0
2026-07-31 [info] db.init path=/home/you/.local/share/sonictune/sonictune.db
2026-07-31 [info] library.ready authenticated=False
2026-07-31 [info] player.ready gapless=True normalization=True
2026-07-31 [info] mpris.registered name=org.mpris.MediaPlayer2.sonictune
2026-07-31 [info] app.ready
2026-07-31 [info] app.qml_ready
```

### Sign in

Open **Settings → Account → Sign In**. You'll need to:

1. Create a Google Cloud project at https://console.cloud.google.com/
2. Enable the **YouTube Data API v3**
3. Create OAuth credentials (type: "TVs and Limited Input devices")
4. Copy the client ID and client secret
5. Paste them into the SonicTune OAuth dialog

Alternatively, use **cookie import**:
1. Install the "cookies.txt" extension for your browser
2. Visit music.youtube.com, log in, export cookies
3. Place the file at `~/.config/sonictune/cookies.txt` (mode 0600)

## Configuration

The config file is at `~/.config/sonictune/config.toml`. It's created on
first launch with defaults. Edit it to customize:

```toml
[audio]
quality = "aac_256"        # 256 kbps AAC (Premium, recommended)
# quality = "opus_160"     # 160 kbps Opus (free tier)

[cache]
audio_size_mb = 1024       # 1 GB audio cache
art_size_mb = 256          # 256 MB album art cache

[ui]
theme = "dark"             # dark | light | archive
```

Restart SonicTune for changes to take effect.

## Logs

Logs go to stderr by default. To log to a file:

```toml
[general]
log_level = "INFO"  # DEBUG | INFO | WARNING | ERROR
log_file = "~/.local/share/sonictune/logs/sonictune.log"
```

Or use the `--verbose` flag:
```bash
./scripts/run.sh --verbose
```

## Verifying everything works

1. **MPRIS registered (media keys work):**
   ```bash
   busctl --user list | grep mpris
   # Should show: org.mpris.MediaPlayer2.sonictune
   ```

2. **Introspect MPRIS:**
   ```bash
   gdbus introspect --session \
     --dest org.mpris.MediaPlayer2.sonictune \
     --object-path /org/mpris/MediaPlayer2
   ```

3. **Play/pause via CLI:**
   ```bash
   dbus-send --session --dest=org.mpris.MediaPlayer2.sonictune \
     --type=method_call /org/mpris/MediaPlayer2 \
     org.mpris.MediaPlayer2.Player.PlayPause
   ```

## Troubleshooting

### Window doesn't open / tray icon missing

- Make sure you're on a desktop session with a status area (tray).
- Some tiling WMs hide tray icons; run with `QT_DEBUG_PLUGINS=1` to debug.

### "libmpv not found"

Install the libmpv development package (see Prerequisites above).

### "yt-dlp fails to extract"

YouTube changes their player code frequently. Update yt-dlp:
```bash
uv pip install --upgrade yt-dlp
```

### "OAuth flow fails"

Make sure you created credentials of type **"TVs and Limited Input devices"**,
not "Web application". The TV flow uses a different OAuth endpoint.

### Audio is silent

- Check `pavucontrol` (PulseAudio Volume Control) — make sure SonicTune
  isn't muted.
- On PipeWire, check `pw-top` to see if the SonicTune stream is active.
- Try `./scripts/run.sh --verbose` and look for `player.mpv_error`.

### UI doesn't show album art

- The image provider uses `image://art/<url>`. Check the logs for
  `image_provider.fetch_failed` warnings.

## Development workflow

### Run tests

```bash
uv run pytest                          # all tests
uv run pytest tests/test_cache.py      # one file
uv run pytest -k lru                   # by name pattern
uv run pytest --cov=sonictune          # with coverage
```

### Lint + format

```bash
uv run ruff check src tests            # lint
uv run ruff format src tests           # format
uv run mypy src                        # type check
```

### Build Flatpak

```bash
flatpak-builder --user --install --force-clean build-dir \
    flatpak/org.sonicTune.json
flatpak run org.sonicTune
```

### Build system install (Meson)

```bash
meson setup build
ninja -C build
ninja -C build install
```

## Uninstall

```bash
# Stop SonicTune
pkill -f sonictune.app

# Remove Python package
uv pip uninstall sonictune

# Remove user data (config, cache, db, logs)
rm -rf ~/.config/sonictune ~/.cache/sonictune ~/.local/share/sonictune

# Remove system install (if installed via Meson)
sudo ninja -C build uninstall
```
