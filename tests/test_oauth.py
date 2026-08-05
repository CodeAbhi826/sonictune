"""Tests for OAuth token refresh (SB-4)."""
from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock

from sonictune.auth.oauth import OAuthManager


async def test_ensure_valid_token_skips_when_not_expired(tmp_path: Path) -> None:
    oauth = OAuthManager(tmp_path / "token.json")
    oauth._token = {"access_token": "a", "refresh_token": "r", "expires_at": 10**12}
    oauth._oauth = MagicMock()
    await oauth.ensure_valid_token()
    oauth._oauth.refresh_token.assert_not_called()


async def test_ensure_valid_token_refreshes_when_expired(tmp_path: Path) -> None:
    oauth = OAuthManager(tmp_path / "token.json")
    oauth._token = {"access_token": "a", "refresh_token": "r", "expires_at": 1}
    oauth._oauth = MagicMock()
    oauth._oauth.refresh_token.return_value = {"access_token": "new", "expires_in": 3600}
    await oauth.ensure_valid_token()
    oauth._oauth.refresh_token.assert_called_once()
    assert oauth._token["access_token"] == "new"
    assert oauth._token["refresh_token"] == "r"  # preserved if not rotated
    # Token is now saved to secure storage (keyring or encrypted file), not plaintext JSON
    # No need to check file existence


async def test_ensure_valid_token_no_token(tmp_path: Path) -> None:
    oauth = OAuthManager(tmp_path / "token.json")
    await oauth.ensure_valid_token()
    assert not tmp_path.joinpath("token.json").exists()


async def test_ensure_valid_token_handles_refresh_error(tmp_path: Path) -> None:
    oauth = OAuthManager(tmp_path / "token.json")
    oauth._token = {"access_token": "a", "refresh_token": "r", "expires_at": 1}
    oauth._oauth = MagicMock()
    oauth._oauth.refresh_token.side_effect = RuntimeError("network down")
    await oauth.ensure_valid_token()  # must not raise
    assert oauth._token["access_token"] == "a"


async def test_ensure_valid_token_skips_without_refresh_token(tmp_path: Path) -> None:
    oauth = OAuthManager(tmp_path / "token.json")
    oauth._token = {"access_token": "a", "expires_at": 1}
    oauth._oauth = MagicMock()
    await oauth.ensure_valid_token()
    oauth._oauth.refresh_token.assert_not_called()
