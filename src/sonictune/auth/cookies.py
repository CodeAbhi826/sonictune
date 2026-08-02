"""Browser cookie import — fallback for users who can't use OAuth.

Reads cookies from a user-supplied file (Firefox-style cookies.txt, or
a JSON exported from a browser extension). ytmusicapi >= 1.0 supports
either format.
"""
from __future__ import annotations

import shutil
from pathlib import Path

import structlog

log = structlog.get_logger()


# Common cookie file locations on Linux (for documentation/UX only — we
# don't auto-read raw browser cookie stores because that requires breaking
# sqlite locks and dealing with DPAPI-style encryption on some systems).
FIREFOX_COOKIE_PATHS = [
    "~/.mozilla/firefox/*.default*/cookies.sqlite",
]

CHROME_COOKIE_PATHS = [
    "~/.config/google-chrome/Default/Cookies",
    "~/.config/chromium/Default/Cookies",
    "~/.config/BraveSoftware/Brave-Browser/Default/Cookies",
]


def import_browser_cookies(
    source_path: Path | str,
    dest_path: Path | str,
) -> bool:
    """Copy a user-supplied cookies file into our config directory.

    Args:
        source_path: Path to the user's cookies file. Can be:
            - Netscape cookies.txt format (most reliable)
            - JSON exported via browser extension
        dest_path: Where to save (typically config.cookies_path).

    Returns:
        True on success, False on failure.
    """
    source = Path(source_path).expanduser()
    dest = Path(dest_path).expanduser()

    if not source.exists():
        log.error("cookies.source_not_found", path=str(source))
        return False

    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        shutil.copy2(source, dest)
        dest.chmod(0o600)
        log.info("cookies.imported", src=str(source), dest=str(dest))
        return True
    except OSError as e:
        log.error("cookies.import_failed", error=str(e))
        return False


def detect_browser_cookies() -> list[Path]:
    """Look for browser cookie files (informational only — we don't auto-copy)."""
    import glob

    found: list[Path] = []
    for pattern in FIREFOX_COOKIE_PATHS + CHROME_COOKIE_PATHS:
        found.extend(Path(p) for p in glob.glob(Path(pattern).expanduser().as_posix()))
    return found


__all__ = ["detect_browser_cookies", "import_browser_cookies"]
