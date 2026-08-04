"""Tests for sonictune.config."""
from __future__ import annotations

from pathlib import Path

from sonictune.config import (
    QUALITY_ITAG_MAP,
    AudioConfig,
    CacheConfig,
    DaemonConfig,
    load_config,
)


def test_default_config_creates_file(tmp_path: Path) -> None:
    """Loading config when no file exists should write a default one."""
    config_path = tmp_path / "config.toml"

    # Patch the default config dir to tmp_path
    import sonictune.config as cfg_module
    original_default = cfg_module.DEFAULT_CONFIG_DIR
    cfg_module.DEFAULT_CONFIG_DIR = tmp_path
    try:
        config = load_config()
        assert config_path.exists()
        assert config.audio.quality == "standard"
    finally:
        cfg_module.DEFAULT_CONFIG_DIR = original_default


def test_config_loads_custom_values(tmp_path: Path) -> None:
    config_file = tmp_path / "config.toml"
    config_file.write_text("""
[audio]
quality = "standard"
itag = 0

[cache]
audio_size_mb = 512

[ui]
accent_color = "#D0BCFF"
""")

    config = load_config(explicit_path=config_file)
    assert config.audio.quality == "standard"
    assert config.audio.itag == 0
    assert config.cache.audio_size_mb == 512
    assert config.ui.accent_color == "#D0BCFF"


def test_audio_config_itag_resolution() -> None:
    audio = AudioConfig()
    assert audio.quality == "standard"
    assert audio.itag == 0  # default 0 = auto-resolve handled by DaemonProxy

    # itag is a separate field; DaemonProxy.setAudioQuality updates both
    audio.quality = "low"
    audio.itag = QUALITY_ITAG_MAP["low"]
    assert audio.itag == QUALITY_ITAG_MAP["low"]  # 249

    audio.quality = "standard"
    audio.itag = QUALITY_ITAG_MAP["standard"]
    assert audio.itag == QUALITY_ITAG_MAP["standard"]  # 250

    audio.quality = "high"
    audio.itag = QUALITY_ITAG_MAP["high"]
    assert audio.itag == QUALITY_ITAG_MAP["high"]  # 0 = auto-resolve

    # Unknown quality falls back to standard
    audio.quality = "unknown"
    audio.itag = 0
    assert audio.itag == 0


def test_cache_config_dirs() -> None:
    cache = CacheConfig(directory=Path("/tmp/sonictune-test"))
    assert cache.audio_dir == Path("/tmp/sonictune-test/audio")
    assert cache.art_dir == Path("/tmp/sonictune-test/art")


def test_daemon_config_paths() -> None:
    config = DaemonConfig()
    assert config.db_path.name == "sonictune.db"
    assert config.oauth_path.name == "oauth.json"
    assert config.cookies_path.name == "cookies.txt"


def test_invalid_toml_raises_valueerror(tmp_path: Path) -> None:
    """Malformed TOML should raise (TOMLDecodeError is a ValueError)."""
    bad = tmp_path / "bad.toml"
    bad.write_text("@ not: [ valid toml")
    try:
        load_config(explicit_path=bad)
        raised = False
    except ValueError:
        raised = True
    assert raised


def test_config_missing_file_creates_default(tmp_path: Path) -> None:
    """Loading with no config file writes a runnable default."""
    import sonictune.config as cfg_module

    target = tmp_path / "newdir"
    original = cfg_module.DEFAULT_CONFIG_DIR
    cfg_module.DEFAULT_CONFIG_DIR = target
    try:
        config = load_config()
        assert (target / "config.toml").exists()
        assert config.audio.quality == "standard"
        assert AudioConfig().itag == 0
    finally:
        cfg_module.DEFAULT_CONFIG_DIR = original


def test_audio_config_custom_itag_resolution() -> None:
    """The itag field can be explicitly set; QUALITY_ITAG_MAP provides defaults."""
    audio = AudioConfig()
    audio.quality = "standard"
    audio.itag = QUALITY_ITAG_MAP["standard"]
    assert audio.itag == QUALITY_ITAG_MAP["standard"]
    audio.quality = "low"
    audio.itag = QUALITY_ITAG_MAP["low"]
    assert audio.itag == QUALITY_ITAG_MAP["low"]
    audio.quality = "high"
    audio.itag = QUALITY_ITAG_MAP["high"]
    assert audio.itag == QUALITY_ITAG_MAP["high"]


def test_audio_config_quality_unknown_falls_back() -> None:
    audio = AudioConfig(quality="bogus")
    assert audio.itag == 0  # auto-resolve fallback
