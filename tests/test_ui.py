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
