"""Tests for sonictune.config."""
from __future__ import annotations

from pathlib import Path

from sonictune.config import (
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
        assert config.audio.quality == "opus_160"
    finally:
        cfg_module.DEFAULT_CONFIG_DIR = original_default


def test_config_loads_custom_values(tmp_path: Path) -> None:
    config_file = tmp_path / "config.toml"
    config_file.write_text("""
[audio]
quality = "opus_160"
normalization = false
gapless = false

[cache]
audio_size_mb = 512

[ui]
theme = "archive"
""")

    config = load_config(explicit_path=config_file)
    assert config.audio.quality == "opus_160"
    assert config.audio.normalization is False
    assert config.audio.gapless is False
    assert config.cache.audio_size_mb == 512
    assert config.ui.theme == "archive"


def test_audio_config_itag_resolution() -> None:
    audio = AudioConfig()
    assert audio.itag == 251  # default opus_160 (free)

    audio.quality = "aac_256"
    assert audio.itag == 141

    audio.quality = "aac_128"
    assert audio.itag == 140

    # Unknown quality falls back to opus_160
    audio.quality = "unknown"
    assert audio.itag == 251


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
        assert config.audio.quality == "opus_160"
        assert AudioConfig().itag == 251
    finally:
        cfg_module.DEFAULT_CONFIG_DIR = original


def test_audio_config_custom_itag_resolution() -> None:
    """The itag property resolves from the configured quality string."""
    audio = AudioConfig()
    audio.quality = "aac_256"
    assert audio.itag == 141
    audio.quality = "opus_160"
    assert audio.itag == 251
    audio.quality = "aac_128"
    assert audio.itag == 140


def test_audio_config_quality_unknown_falls_back() -> None:
    audio = AudioConfig(quality="bogus")
    assert audio.itag == 251  # opus_160 fallback
