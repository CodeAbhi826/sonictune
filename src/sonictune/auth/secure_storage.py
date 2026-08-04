# src/sonictune/auth/secure_storage.py
"""SecureTokenStorage -- OAuth tokens NEVER touch disk in plaintext."""

from __future__ import annotations

import hashlib
import json
import os
import stat
from base64 import urlsafe_b64encode
from pathlib import Path
from typing import Any

import structlog

try:
    import keyring
    KEYRING_AVAILABLE = True
except ImportError:
    KEYRING_AVAILABLE = False

try:
    from cryptography.fernet import Fernet
    CRYPTO_AVAILABLE = True
except ImportError:
    CRYPTO_AVAILABLE = False

log = structlog.get_logger()
SERVICE_NAME = "sonictune"
ACCOUNT_NAME = "oauth_token"

SENSITIVE_KEYS = {
    "token", "access_token", "refresh_token", "id_token", "auth", "cookie",
    "password", "secret", "api_key", "api_secret", "session_key", "oauth", "credentials",
}


class SecureTokenStorage:
    def __init__(self, config_dir: Path | None = None) -> None:
        self._config_dir = config_dir or (Path.home() / ".config" / "sonictune")
        self._token_path = self._config_dir / "oauth.enc"
        self._ensure_dir_permissions()

    def save_oauth_token(self, token_data: dict[str, Any]) -> bool:
        try:
            token_json = json.dumps(token_data, separators=(",", ":"))
            if KEYRING_AVAILABLE:
                try:
                    keyring.set_password(SERVICE_NAME, ACCOUNT_NAME, token_json)
                    log.info("token.saved_keyring")
                    return True
                except Exception as e:
                    log.warning("token.keyring_failed", error=str(e))
            if CRYPTO_AVAILABLE:
                encrypted = self._encrypt(token_json)
                self._token_path.write_bytes(encrypted)
                self._token_path.chmod(0o600)
                log.info("token.saved_encrypted_file")
                return True
            log.error("token.no_secure_storage")
            return False
        except Exception as e:
            log.error("token.save_failed", error=str(e))
            return False

    def load_oauth_token(self) -> dict[str, Any] | None:
        try:
            if KEYRING_AVAILABLE:
                try:
                    token_str = keyring.get_password(SERVICE_NAME, ACCOUNT_NAME)
                    if token_str:
                        return json.loads(token_str)
                except Exception as e:
                    log.warning("token.keyring_load_failed", error=str(e))
            if self._token_path.exists() and CRYPTO_AVAILABLE:
                encrypted = self._token_path.read_bytes()
                decrypted = self._decrypt(encrypted)
                return json.loads(decrypted)
            return None
        except Exception as e:
            log.warning("token.load_failed", error=str(e))
            return None

    def delete_oauth_token(self) -> bool:
        success = True
        if KEYRING_AVAILABLE:
            try:
                keyring.delete_password(SERVICE_NAME, ACCOUNT_NAME)
            except Exception as e:
                log.warning("token.keyring_delete_failed", error=str(e))
                success = False
        if self._token_path.exists():
            try:
                self._token_path.unlink()
            except Exception as e:
                log.warning("token.file_delete_failed", error=str(e))
                success = False
        log.info("token.deleted")
        return success

    def has_token(self) -> bool:
        if KEYRING_AVAILABLE:
            try:
                if keyring.get_password(SERVICE_NAME, ACCOUNT_NAME):
                    return True
            except Exception:
                pass
        return self._token_path.exists()

    def _derive_key(self) -> bytes:
        machine_id = b""
        for path in ["/etc/machine-id", "/var/lib/dbus/machine-id"]:
            try:
                machine_id = Path(path).read_bytes().strip()
                break
            except Exception:
                continue
        if not machine_id:
            machine_id = (os.uname().nodename + str(os.getuid())).encode()
        key = hashlib.sha256(b"sonictune_salt_v1_" + machine_id).digest()
        return urlsafe_b64encode(key)

    def _encrypt(self, plaintext: str) -> bytes:
        return Fernet(self._derive_key()).encrypt(plaintext.encode("utf-8"))

    def _decrypt(self, ciphertext: bytes) -> str:
        return Fernet(self._derive_key()).decrypt(ciphertext).decode("utf-8")

    def _ensure_dir_permissions(self) -> None:
        self._config_dir.mkdir(parents=True, exist_ok=True)
        current_mode = self._config_dir.stat().st_mode
        if stat.S_IMODE(current_mode) != 0o700:
            self._config_dir.chmod(0o700)


def redact_sensitive_tokens(
    logger: Any, method_name: str, event_dict: dict[str, Any]
) -> dict[str, Any]:
    redacted: dict[str, Any] = {}
    for key, value in event_dict.items():
        lower_key = key.lower()
        if any(s in lower_key for s in SENSITIVE_KEYS):
            redacted[key] = "[REDACTED]"
        elif isinstance(value, dict):
            redacted[key] = {
                k: "[REDACTED]" if any(s in k.lower() for s in SENSITIVE_KEYS) else v
                for k, v in value.items()
            }
        else:
            redacted[key] = value
    return redacted
