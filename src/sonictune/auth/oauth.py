"""YouTube Music OAuth via TV device code flow.

Uses ytmusicapi >= 1.8 which supports OAuth with a TV device code flow:
no browser embedding needed, works headlessly, and is the recommended
authentication method going forward.

Flow:
1. User calls start_oauth() — we get a user_code + verification_url.
2. User opens verification_url in any browser, enters user_code, approves.
3. User calls poll_oauth() — we poll until approved, then save token.

The token is stored at config.oauth_path as JSON with mode 0600.
"""
from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import structlog
from ytmusicapi import OAuthCredentials, YTMusic

from sonictune.auth.secure_storage import SecureTokenStorage

log = structlog.get_logger()


@dataclass
class OAuthSession:
    """Represents an in-progress OAuth flow."""

    user_code: str
    verification_url: str
    device_code: str
    interval: int
    expires_in: int


class OAuthManager:
    """Manages YouTube Music OAuth credentials and tokens."""

    def __init__(self, token_path: Path) -> None:
        self.token_path = token_path
        self._secure_storage = SecureTokenStorage(token_path.parent)
        self._token: dict[str, Any] | None = None
        self._oauth: OAuthCredentials | None = None
        self._device_code: str | None = None
        # Remembered across start_oauth() -> poll_oauth() so save_token() can
        # persist them (needed to rebuild OAuthCredentials after a restart).
        self._pending_client_id: str | None = None
        self._pending_client_secret: str | None = None

    async def init(self) -> None:
        """Load an existing token (and its OAuth client credentials) if present.

        BUGFIX: previously this only restored `self._token`, never
        `self._oauth`. `build_ytmusic()` requires *both* to be set before it
        will use the saved token, so every restart silently fell back to
        cookies/anonymous mode even though `is_authenticated` reported True.
        We now persist client_id/client_secret alongside the token (see
        save_token()) and reconstruct the OAuthCredentials object here.
        """
        token_data = self._secure_storage.load_oauth_token()
        if not token_data:
            return

        if "token" in token_data and "client_id" in token_data:
            # Current format: {"client_id", "client_secret", "token": {...}}
            self._token = token_data["token"]
            client_id = token_data.get("client_id", "")
            client_secret = token_data.get("client_secret", "")
            if client_id and client_secret:
                self._oauth = OAuthCredentials(
                    client_id=client_id, client_secret=client_secret
                )
            else:
                log.warning(
                    "oauth.credentials_missing",
                    hint="Token loaded but client_id/secret are missing — "
                    "please sign in again.",
                )
        else:
            # Legacy format: the whole data *is* the token dict
            self._token = token_data
            log.warning(
                "oauth.legacy_token_format",
                hint="Saved token predates credential persistence — "
                "please sign in again to re-enable playback of your library.",
            )

        log.info("oauth.loaded", path=str(self.token_path), usable=self._oauth is not None)

    @property
    def is_authenticated(self) -> bool:
        return self._token is not None

    def get_token(self) -> dict[str, Any] | None:
        return self._token

    async def ensure_valid_token(self) -> None:
        """Refresh token if expired or about to expire.

        Google OAuth access tokens last ~1 hour. If the stored token has
        expired (or `expires_at` is missing, e.g. from an older save), we
        refresh it via ``OAuthCredentials.refresh_token()`` and persist the
        result, preserving the refresh_token if the response omits it.
        """
        if not self._token or not self._oauth:
            return
        refresh_token = self._token.get("refresh_token")
        if not refresh_token:
            return
        expires_at = self._token.get("expires_at")
        if expires_at and time.time() < expires_at - 60:
            return

        oauth = self._oauth

        def _refresh() -> dict[str, Any]:
            return oauth.refresh_token(refresh_token)  # type: ignore[return-value]

        loop = asyncio.get_running_loop()
        try:
            new_token = await loop.run_in_executor(None, _refresh)
        except Exception as e:
            log.warning("oauth.refresh_failed", error=str(e))
            return
        if "access_token" not in new_token:
            log.warning("oauth.refresh_unexpected", token_keys=list(new_token))
            return
        # Some providers rotate refresh tokens; keep the old one if absent.
        new_token.setdefault("refresh_token", refresh_token)
        self.save_token(new_token)
        log.info("oauth.refreshed")

    async def start_oauth(
        self,
        client_id: str,
        client_secret: str,
    ) -> OAuthSession:
        """Begin the TV device code OAuth flow.

        Args:
            client_id: OAuth client ID from Google Cloud Console.
            client_secret: OAuth client secret from Google Cloud Console.

        Returns:
            OAuthSession with user_code & verification_url for the user.
        """
        credentials = OAuthCredentials(
            client_id=client_id,
            client_secret=client_secret,
        )

        def _get_code() -> dict[str, Any]:
            return credentials.get_code()  # type: ignore[return-value]

        loop = asyncio.get_running_loop()
        code = await loop.run_in_executor(None, _get_code)

        self._oauth = credentials
        self._device_code = code["device_code"]
        # Remembered so poll_oauth() -> save_token() can persist them to
        # disk; without this, the saved token can't be reconstructed into a
        # usable OAuthCredentials object after a restart.
        self._pending_client_id = client_id
        self._pending_client_secret = client_secret

        return OAuthSession(
            user_code=code["user_code"],
            verification_url=code["verification_url"],
            device_code=code["device_code"],
            interval=code.get("interval", 5),
            expires_in=code["expires_in"],
        )

    async def poll_oauth(self) -> bool:
        """Poll the OAuth endpoint until user approves or flow expires."""
        if not self._oauth or not self._device_code:
            return False

        oauth = self._oauth

        def _token_from_code(dc: str) -> dict[str, Any]:
            return oauth.token_from_code(dc)  # type: ignore[return-value]

        loop = asyncio.get_running_loop()
        result = await loop.run_in_executor(None, _token_from_code, self._device_code)

        if "access_token" in result:
            self.save_token(result)
            return True

        error = result.get("error", "unknown")
        if error in ("authorization_pending", "slow_down"):
            log.info("oauth.poll_pending", error=error)
        else:
            log.warning("oauth.poll_error", error=error)

        return False

    async def logout(self) -> None:
        """Forget the current token."""
        self._token = None
        self._device_code = None
        self._oauth = None
        self._pending_client_id = None
        self._pending_client_secret = None
        success = self._secure_storage.delete_oauth_token()
        if not success:
            log.warning("oauth.logout_failed")

    def save_token(self, token: dict[str, Any]) -> None:
        """Persist an OAuth token securely (encrypted or keyring).

        BUGFIX: also persists client_id/client_secret alongside the token
        (in the `{"client_id", "client_secret", "token": {...}}` shape read
        by init()). Without this, a fresh process has no way to rebuild the
        OAuthCredentials object needed to actually use the token.
        """
        payload = {
            "client_id": self._pending_client_id or "",
            "client_secret": self._pending_client_secret or "",
            "token": token,
        }
        success = self._secure_storage.save_oauth_token(payload)
        if success:
            self._token = token
            log.info("oauth.token_saved")
        else:
            log.warning("oauth.token_save_failed")

    def build_ytmusic(self, cookies_path: Path | None = None) -> YTMusic:
        """Construct a ytmusicapi.YTMusic instance using the stored token."""
        if self._token and self._oauth:
            return YTMusic(
                oauth_credentials=self._oauth,
                auth=self._token,
            )
        if cookies_path and cookies_path.exists():
            log.info("oauth.using_cookies", path=str(cookies_path))
            return YTMusic(str(cookies_path))
        log.warning("oauth.anonymous_mode")
        return YTMusic()


__all__ = ["OAuthManager", "OAuthSession"]
