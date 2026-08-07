"""Configuration loading and defaults.

SonicTune loads config in this priority order:
1. CLI flags (--config /path/to.toml)
2. ~/.config/sonictune/config.toml
3. XDG_CONFIG_HOME/sonictune/config.toml
4. Built-in defaults
"""
from __future__ import annotations

import asyncio
import json
import os
try:
    import tomllib
except ImportError:
    import tomli as tomllib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

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
    """Audio playback settings.

    ``quality`` is exactly one of the three Phase 2 levels:
    "low", "standard", "high". ``itag`` is the resolved itag for the current
    selection (0 = unset / auto-resolve, used by "high").
    """

    quality: str = "standard"  # ONLY: "low", "standard", "high"
    itag: int = 0  # resolved itag; 0 = auto-resolve
    normalization: bool = True  # EBU R128 loudnorm via mpv af
    gapless: bool = True  # mpv --gapless-audio=yes
    volume_step: int = 5  # percent per step
    replaygain: bool = False  # for downloaded files
    crossfade_seconds: int = 0  # 0 = disabled (0-12s)
    speed: float = 1.0  # playback speed (0.5x-2.0x)


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

    theme: str = "dark"  # dark (Material 3 dark)
    accent_color: str = "#D0BCFF"  # Material 3 primary purple
    volume_step: int = 5
    remember_page: bool = True
    report_history: bool = True  # Report plays to YouTube Music history/Recap
    dynamic_theme_enabled: bool = False  # Material You palette extraction


@dataclass
class LastFmConfig:
    """Last.fm scrobbling settings."""

    enabled: bool = False
    api_key: str = ""
    api_secret: str = ""
    session_key: str = ""


@dataclass
class SponsorBlockConfig:
    """SponsorBlock skip settings."""

    enabled: bool = False
    categories: list[str] = field(
        default_factory=lambda: ["sponsor", "intro", "outro", "selfpromo", "music_offtopic"]
    )


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
class ShortcutsConfig:
    """Configurable keyboard shortcuts (9 total)."""

    play_pause: str = "Space"
    next: str = "Ctrl+Right"
    previous: str = "Ctrl+Left"
    volume_up: str = "Ctrl+Up"
    volume_down: str = "Ctrl+Down"
    toggle_lyrics: str = "Ctrl+L"
    toggle_queue: str = "Ctrl+Q"
    toggle_mini_player: str = "Ctrl+M"
    focus_search: str = "Ctrl+F"


# EXACTLY 3 audio quality levels. 0 for "high" means auto-resolve
# (see resolve_high_quality).
QUALITY_ITAG_MAP: dict[str, int] = {
    "low": 249,
    "standard": 250,
    "high": 0,
}


async def yt_dlp_extract_info(video_id: str) -> dict[str, Any]:
    """Extract format info for a video via yt-dlp (async wrapper)."""
    from yt_dlp import YoutubeDL

    opts = {
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "noplaylist": True,
    }

    def _extract() -> dict[str, Any]:
        with YoutubeDL(opts) as ydl:
            return ydl.extract_info(
                f"https://music.youtube.com/watch?v={video_id}",
                download=False,
            )

    return await asyncio.to_thread(_extract)


async def resolve_high_quality(video_id: str, ytm: Any) -> int:
    """Resolve 'high' quality. Order: 141 -> 774 -> 251."""
    # Try ytmusicapi authenticated stream first
    if ytm is not None and getattr(ytm, "auth", None):
        try:
            stream = ytm.get_song(video_id)
            if stream and "adaptiveFormats" in stream:
                itags = {f.get("itag") for f in stream["adaptiveFormats"]}
                if 141 in itags:
                    return 141
                if 774 in itags:
                    return 774
        except Exception:
            pass

    # Fallback to yt-dlp format inspection
    try:
        info = await yt_dlp_extract_info(video_id)
        formats = {f.get("format_id") for f in info.get("formats", [])}
        if "141" in formats:
            return 141
        if "774" in formats:
            return 774
    except Exception:
        pass

    return 251  # Guaranteed best free quality


@dataclass
class DaemonConfig:
    """Top-level config object."""

    audio: AudioConfig = field(default_factory=AudioConfig)
    cache: CacheConfig = field(default_factory=CacheConfig)
    ui: UIConfig = field(default_factory=UIConfig)
    discord: DiscordConfig = field(default_factory=DiscordConfig)
    mpris: MprisConfig = field(default_factory=MprisConfig)
    shortcuts: ShortcutsConfig = field(default_factory=ShortcutsConfig)
    lastfm: LastFmConfig = field(default_factory=LastFmConfig)
    sponsorblock: SponsorBlockConfig = field(default_factory=SponsorBlockConfig)

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

    def save(self) -> None:
        """Persist the current config back to ``config_dir/config.toml``."""
        path = self.config_dir / "config.toml"
        path.parent.mkdir(parents=True, exist_ok=True)

        def _section(title: str, values: dict[str, Any]) -> str:
            body = "\n".join(f"{k} = {_toml_value(v)}" for k, v in values.items())
            return f"[{title}]\n{body}\n"

        audio = {
            "quality": self.audio.quality,
            "itag": self.audio.itag,
            "normalization": self.audio.normalization,
            "gapless": self.audio.gapless,
            "volume_step": self.audio.volume_step,
            "replaygain": self.audio.replaygain,
            "crossfade_seconds": self.audio.crossfade_seconds,
            "speed": self.audio.speed,
        }
        ui = {
            "theme": self.ui.theme,
            "accent_color": self.ui.accent_color,
            "volume_step": self.ui.volume_step,
            "remember_page": self.ui.remember_page,
            "report_history": self.ui.report_history,
        }
        shortcuts = {
            "play_pause": self.shortcuts.play_pause,
            "next": self.shortcuts.next,
            "previous": self.shortcuts.previous,
            "volume_up": self.shortcuts.volume_up,
            "volume_down": self.shortcuts.volume_down,
            "toggle_lyrics": self.shortcuts.toggle_lyrics,
            "toggle_queue": self.shortcuts.toggle_queue,
            "toggle_mini_player": self.shortcuts.toggle_mini_player,
            "focus_search": self.shortcuts.focus_search,
        }
        lastfm = {
            "enabled": self.lastfm.enabled,
            "api_key": self.lastfm.api_key,
            "api_secret": self.lastfm.api_secret,
            "session_key": self.lastfm.session_key,
        }
        sponsorblock = {
            "enabled": self.sponsorblock.enabled,
            "categories": self.sponsorblock.categories,
        }
        text = (
            "# SonicTune configuration (auto-saved).\n\n"
            + _section("audio", audio)
            + _section("ui", ui)
            + _section("shortcuts", shortcuts)
            + _section("lastfm", lastfm)
            + _section("sponsorblock", sponsorblock)
        )
        path.write_text(text, encoding="utf-8")


def _toml_value(value: Any) -> str:
    """Render a Python value as a TOML literal."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, Path):
        value = str(value)
    return json.dumps(value)


# --- Loader ----------------------------------------------------------------

_DEFAULT_TOML = """
# SonicTune configuration file.
# Edit values below to customize. Restart the daemon for changes to take effect.

[audio]
quality = "standard"          # low | standard | high  (high auto-resolves)
itag = 0                      # 0 = auto-resolve (from quality)
normalization = true
gapless = true
volume_step = 5
replaygain = false
crossfade_seconds = 0         # 0 = disabled (0-12s)
speed = 1.0                   # playback speed (0.5-2.0)

[cache]
audio_size_mb = 1024
art_size_mb = 256
# directory = "~/.cache/sonictune"  # uncomment to override

[ui]
theme = "dark"                # Material 3 dark
accent_color = "#D0BCFF"      # Material 3 primary
volume_step = 5
remember_page = true
report_history = true         # Report plays to YouTube Music history/Recap
dynamic_theme_enabled = false # Extract Material You palette from album art

[shortcuts]
play_pause = "Space"
next = "Ctrl+Right"
previous = "Ctrl+Left"
volume_up = "Ctrl+Up"
volume_down = "Ctrl+Down"
toggle_lyrics = "Ctrl+L"
toggle_queue = "Ctrl+Q"
toggle_mini_player = "Ctrl+M"
focus_search = "Ctrl+F"

[discord]
enabled = false
client_id = ""
show_in_status = true

[mpris]
enabled = true
instance_name = "sonictune"

[lastfm]
enabled = false
api_key = ""
api_secret = ""
session_key = ""

[sponsorblock]
enabled = false
categories = ["sponsor", "intro", "outro", "selfpromo", "music_offtopic"]

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
            config_path.write_text(_DEFAULT_TOML, encoding="utf-8")
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

    if "shortcuts" in data:
        for k, v in data["shortcuts"].items():
            if hasattr(config.shortcuts, k):
                setattr(config.shortcuts, k, v)

    if "lastfm" in data:
        for k, v in data["lastfm"].items():
            if hasattr(config.lastfm, k):
                setattr(config.lastfm, k, v)

    if "sponsorblock" in data:
        for k, v in data["sponsorblock"].items():
            if hasattr(config.sponsorblock, k):
                setattr(config.sponsorblock, k, v)

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
    "QUALITY_ITAG_MAP",
    "AudioConfig",
    "CacheConfig",
    "DaemonConfig",
    "DiscordConfig",
    "LastFmConfig",
    "MprisConfig",
    "ShortcutsConfig",
    "SponsorBlockConfig",
    "UIConfig",
    "load_config",
    "resolve_high_quality",
    "yt_dlp_extract_info",
]
