# Contributing to SonicTune

First off: **thank you** for taking the time to contribute. 💜

This project is community-driven and FOSS. Every bug report, PR, doc fix, or feature idea makes it better.

> **Quick note:** SonicTune is not affiliated with YouTube or Google. Don't submit code that bypasses YouTube's anti-abuse systems, scrapes more aggressively than `ytmusicapi` does, or violates YouTube's ToS.

---

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Ways to contribute](#ways-to-contribute)
- [Dev environment setup](#dev-environment-setup)
- [Project structure](#project-structure)
- [Code style](#code-style)
- [Commit messages](#commit-messages)
- [Pull request flow](#pull-request-flow)
- [Testing](#testing)
- [D-Bus interface changes](#dbus-interface-changes)
- [QML / UI conventions](#qml--ui-conventions)
- [Releasing](#releasing)
- [Getting help](#getting-help)

---

## Code of Conduct

By participating you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md). Be kind, be patient, assume good intent.

---

## Ways to contribute

You don't need to write code to help:

- 🐛 **File bugs** — use the bug report template. Logs are gold.
- ✨ **Suggest features** — use the feature request template. Mockups welcome.
- 📚 **Improve docs** — typos, missing steps, confusing wording — all worth fixing.
- 🌍 **Translate** — once we have a string freeze (Phase 2). Ping us on Discussions.
- 🎨 **Make art** — app icon, theme presets, marketing screenshots.
- 🧪 **Write tests** — find an untested module, add coverage.
- 📦 **Package** — help with Flatpak, .deb, .rpm, AUR, Nix.

If you're not sure where to start, look for issues labeled [`good first issue`](https://github.com/yourusername/sonictune/labels/good%20first%20issue) or [`help wanted`](https://github.com/yourusername/sonictune/labels/help%20wanted).

---

## Dev environment setup

### Prerequisites

- Linux (Wayland or X11)
- Python 3.11+
- Qt 6.7+ development headers
- libmpv development files
- pkg-config
- meson + ninja (for system install)
- Flatpak + Flatpak Builder (for Flatpak testing)

### Install system deps

**Fedora:**
```bash
sudo dnf install python3-devel qt6-qtbase-devel qt6-qtdeclarative-devel \
  mpv-libs-devel pipewire-devel meson ninja-build
```

**Ubuntu / Debian:**
```bash
sudo apt install python3-dev python3-pip qt6-base-dev qt6-declarative-dev \
  libmpv-dev libmpv2 meson ninja-build
```

**Arch:**
```bash
sudo pacman -S python qt6-base qt6-declarative mpv meson ninja pkgconf
```

### Get the source

```bash
git clone https://github.com/yourusername/sonictune.git
cd sonictune
```

### Set up Python env

We recommend [`uv`](https://github.com/astral-sh/uv) — it's 10× faster than pip.

```bash
# Install uv (one-time)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Sync all deps (creates .venv automatically)
uv sync --dev
```

If you prefer plain pip:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

### Run it

```bash
./scripts/run.sh            # single process (UI + services)
./scripts/run.sh --verbose  # debug logging
```

### Verify your env

```bash
uv run ruff check src tests          # lint
uv run ruff format src tests         # format
uv run mypy src                      # type check
uv run pytest                        # tests
```

All four should pass cleanly before you open a PR.

---

## Project structure

```
sonictune/
├── src/
│   ├── sonictune/
│   │   ├── app.py             # Unified application class (entry point)
│   │   ├── config.py
│   │   ├── auth/              # OAuth + cookie import
│   │   ├── library/           # ytmusicapi wrapper
│   │   ├── player/            # libmpv wrapper + queue
│   │   ├── cache/             # LRU audio + art cache
│   │   ├── lyrics/            # LRCLIB client
│   │   ├── stats/             # listening stats aggregator
│   │   ├── mpris/             # MPRIS D-Bus server (desktop integration)
│   │   ├── discord/           # Discord Rich Presence
│   │   ├── db/                # SQLite (WAL) + migrations
│   │   ├── history/           # back-sync to YT Music
│   │   └── ui/                # QML frontend (PySide6)
│   │       ├── main.py        # Thin entry-point wrapper
│   │       ├── daemon_proxy.py  # Direct-call proxy exposed to QML as `Daemon`
│   │       ├── imageprovider.py
│   │       ├── tray.py        # System tray
│   │       └── qml/
│   │           ├── main.qml
│   │           ├── theme/     # Material 3 theme
│   │           ├── pages/     # Home, Search, Library, etc.
│   │           └── components/  # Reusable widgets
│   └── ...
├── data/                     # Desktop file, appstream, icons
├── flatpak/                  # Flatpak manifest
├── docs/                     # Architecture, D-Bus spec, roadmap
├── scripts/                  # Dev convenience scripts
├── tests/                    # Pytest tests
└── .github/                  # CI, issue templates
```

---

## Code style

- **Python:** Black-style (Ruff formatter), 100-char line length, 4-space indent.
- **Imports:** Sorted with `isort` (Ruff handles this).
- **Type hints:** Required on all public functions. `mypy --strict` must pass.
- **Async:** Use `asyncio` everywhere in the daemon. No blocking I/O on the event loop — use `asyncio.to_thread()` for sync libs.
- **QML:** 4-space indent, no tabs. Each `.qml` file starts with a comment describing what it is.
- **Naming:** Python `snake_case`, QML properties `camelCase`, D-Bus methods `PascalCase`.

We use `ruff` for linting + formatting, `mypy` for type checking. Both run in CI and must pass.

---

## Commit messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat` — new feature
- `fix` — bug fix
- `docs` — documentation only
- `refactor` — no behavior change
- `test` — test additions/changes
- `chore` — build, deps, tooling
- `ci` — CI changes

**Examples:**
```
feat(player): add crossfade toggle
fix(mpris): emit Seeked signal after seek
docs(dbus): document Player.Next method
refactor(cache): simplify LRU eviction logic
```

Keep the subject line under 72 chars. Use imperative mood ("add", not "added").

---

## Pull request flow

1. **Fork & branch** — branch from `main`, name it `feat/short-description` or `fix/issue-123`.
2. **Write code + tests** — keep PRs focused, ideally <500 LOC.
3. **Run checks locally** — `ruff`, `mypy`, `pytest` must all pass.
4. **Update docs** if behavior changed.
5. **Open PR** — fill in the template, link issues.
6. **Address review feedback** — push more commits, don't squash yet.
7. **Squash & merge** — maintainer will squash on merge.

We aim to review within 7 days. If it's been longer, ping us in Discussions.

---

## Testing

- **Unit tests** live in `tests/` and use `pytest` + `pytest-asyncio`.
- **Integration tests** (daemon ↔ D-Bus) live in `tests/integration/`.
- Aim for ≥80% coverage on `daemon/` modules. UI code is exempt (hard to test).

```bash
uv run pytest                          # run all
uv run pytest tests/test_cache.py      # one file
uv run pytest -k lru                   # by name pattern
uv run pytest --cov=sonictune          # with coverage
```

For tests that hit the network, mark them `@pytest.mark.network` so they can be skipped in CI:
```python
@pytest.mark.network
async def test_lrclib_fetch():
    ...
```

---

## D-Bus interface changes

If you change any D-Bus interface (add/remove methods, change signatures):

1. Update `docs/DBUS_INTERFACE.md`.
2. Bump the interface version in `src/sonictune/daemon/dbus/interfaces.py`.
3. Add a migration note if it's a breaking change.
4. Update both the daemon-side server and the UI-side client.

D-Bus is our public API contract — treat changes with the same care as a REST API.

---

## QML / UI conventions

- Every page lives in `qml/pages/` and is named `PascalCase.qml`.
- Every reusable component lives in `qml/components/`.
- Use Kirigami components where possible (`Kirigami.Page`, `Kirigami.AbstractListItem`).
- Colors come from the active theme — never hardcode hex.
- Strings must be translatable: `qsTr("Play")`, not `"Play"`.
- Animations: prefer `Behavior on x { NumberAnimation { duration: 200 } }` over imperative JS.
- No business logic in QML — call into the daemon via D-Bus client.

---

## Releasing

Maintainers handle releases. Process:

1. Update `version` in `pyproject.toml` and `meson.build`.
2. Add a `<release>` entry in `data/org.sonicTune.appdata.xml`.
3. Tag: `git tag v0.X.Y && git push --tags`.
4. CI builds the Flatpak + wheel and creates a draft GitHub release.
5. Maintainer publishes the release and announces in Discussions.

---

## Getting help

- 💬 [GitHub Discussions](https://github.com/yourusername/sonictune/discussions) — for questions, design chats, "how do I…" stuff.
- 🐛 [Issues](https://github.com/yourusername/sonictune/issues) — for bugs and concrete feature requests only.
- 📧 Email maintainers — for security issues only (see [SECURITY.md](SECURITY.md)).

Don't be shy — we'd rather answer a "dumb" question than have you waste three hours.

Happy hacking! 🎵
