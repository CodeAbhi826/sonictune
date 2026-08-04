"""Tests for Security (T-030 to T-033)."""
from __future__ import annotations

import stat
import tempfile
from pathlib import Path
from unittest.mock import patch

from sonictune.auth.secure_storage import SecureTokenStorage, redact_sensitive_tokens


def test_secure_token_storage_save_and_load() -> None:
    """T-030: SecureTokenStorage round-trips token correctly."""
    with tempfile.TemporaryDirectory() as tmpdir, patch("sonictune.auth.secure_storage.KEYRING_AVAILABLE", False):
        storage = SecureTokenStorage(config_dir=Path(tmpdir))
        token = {"access_token": "secret123", "refresh_token": "refresh456"}
        assert storage.save_oauth_token(token) is True
        loaded = storage.load_oauth_token()
        assert loaded is not None
        assert loaded["access_token"] == "secret123"
        assert loaded["refresh_token"] == "refresh456"


def test_secure_token_storage_directory_permissions() -> None:
    """T-031: Config directory has 0700 permissions."""
    with tempfile.TemporaryDirectory() as tmpdir, patch("sonictune.auth.secure_storage.KEYRING_AVAILABLE", False):
            SecureTokenStorage(config_dir=Path(tmpdir))
            mode = stat.S_IMODE(Path(tmpdir).stat().st_mode)
            assert mode == 0o700


def test_secure_token_storage_file_permissions() -> None:
    """T-032: Token file has 0600 permissions."""
    with tempfile.TemporaryDirectory() as tmpdir, patch("sonictune.auth.secure_storage.KEYRING_AVAILABLE", False):
            storage = SecureTokenStorage(config_dir=Path(tmpdir))
            storage.save_oauth_token({"test": "value"})
            token_file = Path(tmpdir) / "oauth.enc"
            mode = stat.S_IMODE(token_file.stat().st_mode)
            assert mode == 0o600


def test_log_redaction() -> None:
    """T-033: redact_sensitive_tokens replaces sensitive fields."""
    result = redact_sensitive_tokens(None, "test", {"access_token": "secret", "user": "john"})
    assert result["access_token"] == "[REDACTED]"
    assert result["user"] == "john"


def test_secure_token_storage_load_empty() -> None:
    """Loading a token when none saved returns None."""
    with tempfile.TemporaryDirectory() as tmpdir, patch("sonictune.auth.secure_storage.KEYRING_AVAILABLE", False):
        storage = SecureTokenStorage(config_dir=Path(tmpdir))
        assert storage.load_oauth_token() is None


def test_log_redaction_preserves_non_secrets() -> None:
    """redact_sensitive_tokens keeps unrelated keys untouched."""
    result = redact_sensitive_tokens(None, "test", {"client_id": "abc", "expires_in": 3600})
    assert result["client_id"] == "abc"
    assert result["expires_in"] == 3600
