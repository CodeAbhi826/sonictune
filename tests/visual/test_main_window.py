# tests/visual/test_main_window.py
"""
Visual regression test for SonicTune's main window.

Launches the real Qt/QML app under Xvfb (pyvirtualdisplay), captures the
window with ImageMagick `import`, and pixel-diffs against a baseline PNG.

Baselines:
  export UPDATE_BASELINE=1 && QT_QPA_PLATFORM=xcb pytest tests/visual/ -v
"""

import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
import pytest
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
BASELINE_DIR = Path(__file__).parent / "baseline"
SCREENSHOT_DIR = Path(__file__).parent / "screenshots"
WIDTH, HEIGHT = 1280, 800

APP_READY = "app.qml_ready"


def compare_images(actual_path: Path, baseline_path: Path, threshold: float = 0.02) -> float:
    """Return the fraction of differing pixels between two images."""
    actual = Image.open(actual_path).convert("RGB")
    baseline = Image.open(baseline_path).convert("RGB")
    if actual.size != baseline.size:
        actual = actual.resize(baseline.size)
    diff = ImageChops.difference(actual, baseline)
    diff_array = np.asarray(diff)
    return float(np.count_nonzero(diff_array) / max(diff_array.size, 1))


@pytest.fixture(scope="module")
def xvfb():
    from pyvirtualdisplay import Display

    display = Display(visible=0, size=(WIDTH, HEIGHT), color_depth=24)
    display.start()
    # pyvirtualdisplay sets os.environ["DISPLAY"]; keep a copy for helpers.
    display_name = os.environ["DISPLAY"]
    yield display_name
    display.stop()


@pytest.fixture(scope="module")
def app_process(xvfb):
    """Launch SonicTune under Xvfb and wait for the QML engine to be ready."""
    env = dict(os.environ)
    env["QT_QPA_PLATFORM"] = "xcb"
    proc = subprocess.Popen(
        [
            sys.executable, "-m", "sonictune.app",
            "--no-mpris", "--no-discord", "--verbose",
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    ready = False
    deadline = time.time() + 90
    try:
        while time.time() < deadline and not ready:
            line = proc.stdout.readline()
            if not line:
                if proc.poll() is not None:
                    break
                time.sleep(0.25)
                continue
            if APP_READY in line:
                ready = True
            if "qml_load_failed" in line:
                break
        time.sleep(3)  # let the first frame render
        if not ready:
            raise RuntimeError("app did not reach app.qml_ready; see captured output")
        yield
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()


def capture_window(screenshot_dir: Path) -> Path:
    screenshot_dir.mkdir(parents=True, exist_ok=True)
    path = screenshot_dir / "main_window.png"
    subprocess.run(
        ["import", "-window", "root", str(path)],
        env={**os.environ, "QT_QPA_PLATFORM": "xcb"},
        check=True,
    )
    return path


def test_main_window_layout(app_process, tmp_path):
    """Capture the running main window and compare to the baseline."""
    actual = capture_window(tmp_path)
    baseline = BASELINE_DIR / "main_window.png"

    if os.environ.get("UPDATE_BASELINE") == "1":
        BASELINE_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(actual, baseline)
        pytest.skip("Baseline updated; re-run without UPDATE_BASELINE to verify.")

    if not baseline.exists():
        pytest.skip("No baseline screenshot yet. Set UPDATE_BASELINE=1 to create one.")

    diff_ratio = compare_images(actual, baseline)
    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(actual, SCREENSHOT_DIR / "main_window.png")
    assert diff_ratio < 0.02, (
        f"Main window differs from baseline ({diff_ratio * 100:.1f}% pixels changed). "
        f"Review {SCREENSHOT_DIR / 'main_window.png'}"
    )


if __name__ == "__main__":
    from pyvirtualdisplay import Display

    with Display(visible=0, size=(WIDTH, HEIGHT), color_depth=24):
        os.environ["QT_QPA_PLATFORM"] = "xcb"
        import subprocess as sp
        proc = sp.Popen(
            [sys.executable, "-m", "sonictune.app", "--no-mpris", "--no-discord"],
            cwd=ROOT,
        )
        time.sleep(30)
        capture_window(BASELINE_DIR)
        proc.terminate()
        print("Baseline captured at", BASELINE_DIR / "main_window.png")
