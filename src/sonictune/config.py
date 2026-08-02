"""Configuration loading and defaults.

SonicTune loads config in this priority order:
1. CLI flags (--config /path/to.toml)
2. ~/.config/sonictune/config.toml
3. XDG_CONFIG_HOME/sonictune/config.toml
4. Built-in defaults
"""
from __future__ import annotations

import os
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

if sys.version_info >= (3, 11):
    import tomllib
else:
    import tomli as tomllib


# --- Defaults --------------------------------------------------------------

DEFAULT_CONFIG_DIR = Path(
    os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))
) / "sonictune"

DEFAULT_CACHE_DIR = Path(
    os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))
) / "sonictune"

DEFAULT_DATA_DIR = Path(
    os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local" / "share"))
) / "sonictune"


# --- Dataclasses -----------------------------------------------------------


@dataclass
class AudioConfig:
    """Audio playback settings."""

    quality: str = "aac_256"  # aac_256 (Premium, 256kbps) | opus_160 (free, 160kbps)
    normalization: bool = True  # EBU R128 loudnorm via mpv af
    gapless: bool = True  # mpv --gapless-audio=yes
    volume_step: int = 5  # percent per step
    replaygain: bool = False  # for downloaded files
    crossfade_seconds: float = 0.0  # 0 = disabled

    # YouTube Music itags (don't change unless you know what you're doing)
    ITAGS: dict[str, int] = field(
        default_factory=lambda: {
            "aac_256": 141,  # Premium AAC 256kbps
            "opus_160": 251,  # Free Opus 160kbps
            "aac_128": 140,  # Free AAC 128kbps fallback
        }
    )

    @property
    def itag(self) -> int:
        """Resolve the configured quality to a YouTube itag."""
        return self.ITAGS.get(self.quality, self.ITAGS["opus_160"])


@dataclass
class CacheConfig:
    """On-disk cache settings."""

    audio_size_mb: int = 1024  # 1 GB LRU audio cache
    art_size_mb: int = 256  # 256 MB art cache
    directory: Path = DEFAULT_CACHE_DIR
    audio_subdir: str = "audio"
    art_subdir: str = "art"

    @property
    def audio_dir(self) -> Path:
        return self.directory / self.audio_subdir

    @property
    def art_dir(self) -> Path:
        return self.directory / self.art_subdir


@dataclass
class UIConfig:
    """UI-related settings (read by the frontend)."""

    theme: str = "dark"  # dark | light | archive
    accent_color: str = "#6750A4"  # Material 3 default purple
    volume_step: int = 5
    remember_page: bool = True


@dataclass
class DiscordConfig:
    """Discord Rich Presence settings."""

    enabled: bool = False
    client_id: str = ""  # User-provided Discord app client ID
    show_in_status: bool = True


@dataclass
class MprisConfig:
    """MPRIS D-Bus settings."""

    enabled: bool = True
    instance_name: str = "sonictune"  # org.mpris.MediaPlayer2.sonictune


@dataclass
class DaemonConfig:
    """Top-level config object."""

    audio: AudioConfig = field(default_factory=AudioConfig)
    cache: CacheConfig = field(default_factory=CacheConfig)
    ui: UIConfig = field(default_factory=UIConfig)
    discord: DiscordConfig = field(default_factory=DiscordConfig)
    mpris: MprisConfig = field(default_factory=MprisConfig)

    # Paths
    config_dir: Path = DEFAULT_CONFIG_DIR
    data_dir: Path = DEFAULT_DATA_DIR
    cache_dir: Path = DEFAULT_CACHE_DIR

    # General
    log_level: str = "INFO"  # DEBUG | INFO | WARNING | ERROR
    log_file: Path | None = None  # None = stderr

    @property
    def db_path(self) -> Path:
        return self.data_dir / "sonictune.db"

    @property
    def oauth_path(self) -> Path:
        return self.config_dir / "oauth.json"

    @property
    def cookies_path(self) -> Path:
        return self.config_dir / "cookies.txt"


# --- Loader ----------------------------------------------------------------

_DEFAULT_TOML = """
# SonicTune configuration file.
# Edit values below to customize. Restart the daemon for changes to take effect.

[audio]
quality = "aac_256"           # aac_256 (Premium, 256kbps) | opus_160 (free, 160kbps)
normalization = true
gapless = true
volume_step = 5
replaygain = false
crossfade_seconds = 0.0       # 0 = disabled

[cache]
audio_size_mb = 1024
art_size_mb = 256
# directory = "~/.cache/sonictune"  # uncomment to override

[ui]
theme = "dark"                # dark | light | archive
accent_color = "#6750A4"
volume_step = 5
remember_page = true

[discord]
enabled = false
client_id = ""
show_in_status = true

[mpris]
enabled = true
instance_name = "sonictune"

# [general]
# log_level = "INFO"
# log_file = "~/.local/share/sonictune/logs/sonictune.log"
"""


def load_config(explicit_path: Path | str | None = None) -> DaemonConfig:
    """Load config from file, falling back to defaults.

    Args:
        explicit_path: Optional explicit path to a TOML config file.

    Returns:
        Loaded DaemonConfig.
    """
    config_path = Path(explicit_path) if explicit_path else DEFAULT_CONFIG_DIR / "config.toml"

    config = DaemonConfig()

    if not config_path.exists():
        # Write a default config file so users can discover/edit it.
        try:
            config_path.parent.mkdir(parents=True, exist_ok=True)
            config_path.write_text(_DEFAULT_TOML)
        except OSError:
            # Read-only home (rare). Just use built-in defaults.
            pass
        return config

    with config_path.open("rb") as f:
        data: dict[str, Any] = tomllib.load(f)

    # Merge into dataclass
    if "audio" in data:
        for k, v in data["audio"].items():
            if hasattr(config.audio, k):
                setattr(config.audio, k, v)

    if "cache" in data:
        for k, v in data["cache"].items():
            if k == "directory":
                config.cache.directory = Path(str(v).replace("~", str(Path.home())))
            elif hasattr(config.cache, k):
                setattr(config.cache, k, v)

    if "ui" in data:
        for k, v in data["ui"].items():
            if hasattr(config.ui, k):
                setattr(config.ui, k, v)

    if "discord" in data:
        for k, v in data["discord"].items():
            if hasattr(config.discord, k):
                setattr(config.discord, k, v)

    if "mpris" in data:
        for k, v in data["mpris"].items():
            if hasattr(config.mpris, k):
                setattr(config.mpris, k, v)

    if "daemon" in data:
        daemon = data["daemon"]
        if "log_level" in daemon:
            config.log_level = daemon["log_level"]
        if "log_file" in daemon:
            path = Path(str(daemon["log_file"]).replace("~", str(Path.home())))
            config.log_file = path
            path.parent.mkdir(parents=True, exist_ok=True)

    # Make sure cache directories exist
    config.cache.directory.mkdir(parents=True, exist_ok=True)
    config.cache.audio_dir.mkdir(parents=True, exist_ok=True)
    config.cache.art_dir.mkdir(parents=True, exist_ok=True)
    config.data_dir.mkdir(parents=True, exist_ok=True)

    return config


__all__ = [
    "AudioConfig",
    "CacheConfig",
    "DaemonConfig",
    "DiscordConfig",
    "MprisConfig",
    "UIConfig",
    "load_config",
]
