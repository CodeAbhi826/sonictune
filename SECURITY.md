# Security Policy

## Supported Versions

SonicTune is pre-1.0 software. We only patch the latest release.

| Version | Supported          |
|---------|--------------------|
| 0.1.x   | ✅ latest release  |
| < 0.1   | ❌ not supported   |

## Reporting a Vulnerability

**Do NOT open a public GitHub issue for security reports.**

Instead, please email **security@yourusername.dev** with:

1. A description of the issue
2. Steps to reproduce (or PoC)
3. Affected versions
4. Suggested fix (if you have one)

You should receive an acknowledgment within 72 hours. We'll coordinate a fix
and disclosure timeline with you.

If the issue is sensitive (e.g., credentials leak), we'll set up a private
GitHub Security Advisory and add you as a collaborator so you can review
the fix.

## Scope

**In scope:**
- Vulnerabilities in SonicTune's own code (daemon, UI, D-Bus)
- Auth token leakage / improper storage
- Path traversal in cache or download paths
- D-Bus interface abuse (e.g., unauthenticated method calls affecting other users)

**Out of scope:**
- Bypassing YouTube's anti-abuse systems (we don't host that code)
- Vulnerabilities in dependencies (report upstream: `ytmusicapi`, `yt-dlp`,
  `mpv`, `PySide6`, etc.) — but DO tell us so we can bump our minimum versions
- Social engineering / phishing
- DoS via flooding the daemon (we rate-limit, but it's not a security control)

## Credential Storage

SonicTune stores:
- OAuth tokens in `~/.config/sonictune/oauth.json` (mode `0600`)
- Cookie-based auth in `~/.config/sonictune/cookies.txt` (mode `0600`)
- D-Bus session bus credentials (managed by your session manager)

We never log credentials. If you find any credential in a log file, that's a
bug — report it.

## Acknowledgements

We're grateful to security researchers who report issues responsibly.
With your permission, we'll add you to the acknowledgements list in release
notes.
