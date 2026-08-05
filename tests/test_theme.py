"""Tests for Theme tokens (T-001 to T-004)."""
from __future__ import annotations

import re
from pathlib import Path

from sonictune.ui.qml.theme.Theme import Theme

_THEME_QML = Path(__file__).resolve().parents[1] / "src" / "sonictune" / "ui" / "qml" / "theme" / "Theme.qml"


def test_theme_background_color() -> None:
    """T-001: Theme background is Material 3 dark."""
    assert Theme.background == "#0F0F0F"


def test_theme_on_surface_color() -> None:
    """T-002: Theme fgSurface is light gray (not black)."""
    assert Theme.fgSurface == "#E6E1E5"


def test_theme_primary_color() -> None:
    """T-003: Theme primary is M3 purple accent."""
    assert Theme.primary == "#D0BCFF"


def test_theme_reduced_motion_default() -> None:
    """T-004: Theme.reducedMotion defaults to False."""
    assert Theme.reducedMotion is False


# ---- D1: Theme.py / Theme.qml drift guard -----------------------------------
#
# Theme.qml is the single source of truth at runtime; Theme.py mirrors it so
# the Python suite can assert token values. This test fails on any drift — a
# token changed in one file but not the other (the Bug 26 failure class).


def _snake_to_camel(name: str) -> str:
    parts = name.split("_")
    return parts[0] + "".join(p.capitalize() for p in parts[1:])


def _qml_hex_colors() -> dict[str, str]:
    """Map QML color-token name -> normalized hex value (hex-valued only)."""
    text = _THEME_QML.read_text(encoding="utf-8")
    colors: dict[str, str] = {}
    for match in re.finditer(r'property\s+color\s+(\w+): *"(#[0-9A-Fa-f]{6,8})"', text):
        colors[match.group(1)] = match.group(2).lower()
    return colors


def _py_hex_colors() -> dict[str, str]:
    """Map Theme.py color attributes to their camelCase QML-facing names."""
    from sonictune.ui.qml.theme import Theme as ThemeModule

    colors: dict[str, str] = {}
    for name, value in vars(ThemeModule.Theme).items():
        if name.startswith("_"):
            continue
        if not isinstance(value, str) or not value.startswith("#"):
            continue
        camel = _snake_to_camel(name) if "_" in name else name
        colors.setdefault(camel, value.lower())
    return colors


def test_theme_tokens_in_sync() -> None:
    """D1: every Python-mirrored color token matches Theme.qml exactly."""
    qml_colors = _qml_hex_colors()
    py_colors = _py_hex_colors()
    qml_lower = {k.lower(): v for k, v in qml_colors.items()}

    # Intentional aliases that exist only on the Python side (not QML-facing).
    allowed_missing = {"fgsurfacemuted"}

    missing_in_qml = sorted(
        name for name in py_colors if name.lower() not in qml_lower
        and name.lower() not in allowed_missing
    )
    assert not missing_in_qml, (
        f"Theme.py tokens missing from Theme.qml: {missing_in_qml}"
    )

    drifted = sorted(
        name
        for name, py_value in py_colors.items()
        if name.lower() in qml_lower and qml_lower[name.lower()] != py_value
    )
    assert not drifted, (
        f"Theme.py token values drifted from Theme.qml: {drifted}"
    )
