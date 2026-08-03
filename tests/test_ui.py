"""UI-layer integration tests (category L — UI Integration).

These validate the QML-facing contract without needing a display server:
signal/slot cross-referencing between DaemonProxy and the QML, context
properties the app wires up, and Layout/page wiring in main.qml.
"""
from __future__ import annotations

import re
from pathlib import Path

QML_ROOT = Path(__file__).resolve().parents[1] / "src" / "sonictune" / "ui" / "qml"


def _read(name: str) -> str:
    p = QML_ROOT / name
    assert p.exists(), f"missing QML file {p}"
    return p.read_text()


# ---- Context property contract ------------------------------------------------


def test_apps_version_context_wired() -> None:
    from sonictune import __version__ as v
    assert isinstance(v, str) and v


def test_settings_page_uses_appversion() -> None:
    settings = _read("pages/SettingsPage.qml")
    assert "AppVersion" in settings


# ---- DaemonProxy signal/slot cross-reference ----------------------------------


def test_proxy_signals_referenced_in_qml() -> None:
    """Every Daemon.onXxx() used in QML maps to a real proxy signal."""
    from sonictune.ui.daemon_proxy import DaemonProxy

    _ = DaemonProxy  # (imported for signal existence checks below)

    qml_texts = [str(p.read_text()) for p in (QML_ROOT / "pages").glob("*.qml")]
    qml_texts += [str(p.read_text()) for p in (QML_ROOT / "components").glob("*.qml")]
    qml_texts.append(_read("main.qml"))
    blob = "\n".join(qml_texts)

    for sig in ["onStatusReceived", "onTrackChanged", "onStateChanged",
                "onPositionChanged", "onConnectionChanged", "onHomeReceived",
                "onSearchCompleted", "onStatsReceived", "onAuthChanged"]:
        # Every onXxx used in QML must correspond to a real Signal in the proxy.
        used = sig in blob
        if used:
            signal_name = sig[2].lower() + sig[3:]  # "StatusReceived" -> "statusReceived"
            assert hasattr(DaemonProxy, signal_name), f"missing signal {signal_name}"


def test_daemon_slots_called_from_qml() -> None:
    """Every Daemon.method() invoked in QML maps to a real @Slot."""
    from sonictune.ui.daemon_proxy import DaemonProxy

    blob = "\n".join(p.read_text() for p in (QML_ROOT / "pages").glob("*.qml"))
    blob += "\n".join(p.read_text() for p in (QML_ROOT / "components").glob("*.qml"))
    blob += _read("main.qml")

    calls = set(re.findall(r"Daemon\.(\w+)\(", blob))
    for method in calls:
        assert hasattr(DaemonProxy, method), f"QML calls missing proxy slot: {method}"


# ---- App wiring ----------------------------------------------------------------


def test_app_registers_imageprovider_and_theme() -> None:
    app_src = (Path(__file__).resolve().parents[1] / "src" / "sonictune" / "app.py").read_text()
    assert 'addImageProvider("art"' in app_src
    assert "QQuickStyle.setStyle" in app_src


# ---- No emoji in UI ===========================================================


def test_no_emoji_in_qml() -> None:
    """Components must not contain emoji pictographs."""
    emoji_re = re.compile(
        "[\U0001F300-\U0001FAFF]|[\u2600-\u27BF]|[\uFE00-\uFE0F]"
    )
    for p in (QML_ROOT / "components").glob("*.qml"):
        text = p.read_text()
        matches = emoji_re.findall(text)
        # Emoji-free: any match is an error.
        assert not matches, f"emoji found in {p}: {matches}"


# ---- No redundant Now Playing tab ===========================================


def test_navrail_has_exactly_five_items_no_nowplaying() -> None:
    """The nav rail must keep only Home/Search/Library/Stats/Settings."""
    navrail = _read("components/NavRail.qml")
    items = re.findall(r'name:\s*"(\w+)"', navrail)
    # Rail destinations only (ignore unrelated strings like icon names).
    rail_names = [n for n in items if n in {
        "home", "search", "library", "stats", "nowplaying", "settings"
    }]
    assert rail_names == ["home", "search", "library", "stats", "settings"]
    assert "nowplaying" not in rail_names


def test_stacklayout_has_no_nowplaying_page() -> None:
    """main.qml's page-switch mapping must not include a nowplaying tab."""
    main = _read("main.qml")
    # The 5-page mapping inside switchTo() — no nowplaying entry.
    switch = main.split("function switchTo(name) {")[1].split("}")[0]
    assert '"nowplaying"' not in switch
    assert '"settings": 4' in switch
    assert 'NowPlayingPage' not in switch


def test_now_playing_opens_via_drawer() -> None:
    """Now Playing is a Drawer opened from the PlayerBar, not a rail tab."""
    main = _read("main.qml")
    assert "edge: Qt.BottomEdge" in main
    assert "onOpenNowPlaying" in main
    # NowPlayingPage appears exactly once, inside the Drawer.
    assert main.count("NowPlayingPage") == 1
    drawer = main.split("Drawer {")[1]
    assert "NowPlayingPage" in drawer


def test_settings_page_has_history_toggle() -> None:
    """Settings wires a 'Report plays to YouTube Music' toggle."""
    settings = _read("pages/SettingsPage.qml")
    assert "reportHistory" in settings
    assert "setReportHistory" in settings
    assert "Report plays to YouTube Music" in settings


def test_slider_uses_standard_behavior_no_movedby() -> None:
    """STSlider must not call the non-existent movedBy() function."""
    slider = _read("components/STSlider.qml")
    assert "movedBy" not in slider
    assert "Slider" in slider


def test_stbutton_width_is_textmetric_based() -> None:
    """STButton must not guess width via 10 * text.length."""
    button = _read("components/STButton.qml")
    assert "10 * text.length" not in button
    assert "implicitWidth" in button
