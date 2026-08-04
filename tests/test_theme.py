"""Tests for Theme tokens (T-001 to T-004)."""
from __future__ import annotations

from sonictune.ui.qml.theme.Theme import Theme


def test_theme_background_color() -> None:
    """T-001: Theme background is Material 3 dark."""
    assert Theme.background == "#0F0F0F"


def test_theme_on_surface_color() -> None:
    """T-002: Theme onSurface is light gray (not black)."""
    assert Theme.onSurface == "#E6E0E9"


def test_theme_primary_color() -> None:
    """T-003: Theme primary is M3 purple accent."""
    assert Theme.primary == "#D0BCFF"


def test_theme_reduced_motion_default() -> None:
    """T-004: Theme.reducedMotion defaults to False."""
    assert Theme.reducedMotion is False
