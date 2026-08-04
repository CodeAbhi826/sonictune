"""Tests for UI compliance (T-040 to T-043)."""
from __future__ import annotations

import re
from pathlib import Path


def test_no_black_text_in_qml() -> None:
    """T-040: No QML file contains "#000000" or "black"."""
    qml_dir = Path("src/sonictune/ui/qml")
    qml_files = list(qml_dir.rglob("*.qml"))

    for f in qml_files:
        content = f.read_text(encoding="utf-8")
        assert "#000000" not in content, f"{f} contains black"
        assert 'color: "black"' not in content, f"{f} contains black"
        assert "color: 'black'" not in content, f"{f} contains black"


def test_all_colors_from_theme() -> None:
    """T-041: No hardcoded hex colors in QML (except Theme.qml)."""
    qml_dir = Path("src/sonictune/ui/qml")
    qml_files = [f for f in qml_dir.rglob("*.qml") if f.name != "Theme.qml"]
    hex_pattern = re.compile(r'#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})')

    for f in qml_files:
        content = f.read_text(encoding="utf-8")
        matches = hex_pattern.findall(content)
        assert len(matches) == 0, f"{f} contains hardcoded hex: {matches}"


def test_reduced_motion_respected() -> None:
    """T-042: Animations check reducedMotion flag."""
    qml_files = list(Path("src/sonictune/ui/qml").rglob("*.qml"))

    for f in qml_files:
        content = f.read_text(encoding="utf-8")
        if "Behavior on" in content:
            assert "enabled: !Theme.reducedMotion" in content or "enabled: !theme.reducedMotion" in content, f"{f} missing reducedMotion check"


def test_low_end_mode_no_shadows() -> None:
    """T-043: Shadow properties respect lowEndMode."""
    theme_file = Path("src/sonictune/ui/qml/theme/Theme.qml")
    content = theme_file.read_text(encoding="utf-8")
    assert "(lowEndMode || disableShadows) ? 0 :" in content
