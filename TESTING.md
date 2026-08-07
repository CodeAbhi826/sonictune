# SonicTune Testing Guide

This document outlines testing workflows for SonicTune, including MCP integration and visual regression testing.

## Table of Contents
- [MCP-Based Testing](#mcp-based-testing)
- [Visual Regression Testing](#visual-regression-testing)
- [Changelog Updates](#changelog-updates)

---

## MCP-Based Testing

### Overview
SonicTune uses the **Model Context Protocol (MCP)** for image handling and validation. MCP-related tests ensure:
- Images (JPEG, PNG, WEBP, GIF, SVG, etc.) load correctly.
- Data URIs (e.g., `data:image/png;base64,...`) are supported.
- UI components relying on MCP (e.g., album art, icons) render without glitches.

### Setup
1. **Enable MCP Server**:
   - Ensure the MCP server is running locally or in the sandbox.
   - Use `local-everything_toggle-simulated-logging` to debug MCP interactions.

2. **Test Image Validation**:
   - Verify allowed formats in MCP server configurations.
   - Test edge cases (e.g., malformed data URIs, unsupported formats).

### Test Cases
| Test Case                     | Description                                                                 | Tools/Commands                          |
|-------------------------------|-----------------------------------------------------------------------------|-----------------------------------------|
| Load PNG from data URI        | Ensure `data:image/png;base64,...` loads without errors.                   | `pytest tests/mcp/test_image_validation.py` |
| Load SVG from file            | Verify SVG icons render correctly in the UI.                              | `pytest tests/visual/test_icons.py`     |
| Unsupported format rejection  | Confirm unsupported formats (e.g., TIFF) are rejected gracefully.         | `pytest tests/mcp/test_validation.py`   |

---

## Visual Regression Testing

### Overview
Automated visual testing captures UI glitches (e.g., misaligned icons, broken album art) by comparing screenshots against baselines.

### Tools
- **Playwright**: For cross-platform UI testing.
- **Percy/Applitools**: For cloud-based visual diffing (optional).
- **Pytest-Qt**: For Qt-specific UI tests.

### Setup
1. **Install Dependencies**:
   ```bash
   pip install pytest-playwright pytest-qt
   playwright install
   ```

2. **Configure Playwright**:
   - Add `playwright.config.js` to the project root.
   - Define test targets (e.g., main window, mini-player).

### Test Cases
| Test Case                     | Description                                                                 | Tools/Commands                          |
|-------------------------------|-----------------------------------------------------------------------------|-----------------------------------------|
| Main Window Layout            | Verify all UI elements (play button, progress bar) are visible and aligned. | `pytest tests/visual/test_main_window.py` |
| Album Art Rendering           | Ensure album art loads without distortion or placeholder glitches.         | `pytest tests/visual/test_album_art.py` |
| Dark/Light Mode Switch         | Confirm UI adapts correctly to theme changes.                              | `pytest tests/visual/test_themes.py`    |

### Example Test
```python
# tests/visual/test_main_window.py
def test_main_window_layout(page):
    page.goto("qrc:/main.qml")
    screenshot = page.screenshot()
    assert compare_screenshots(screenshot, "baseline/main_window.png")
```

---

## Changelog Updates

### Rule
After every change (bug fix, feature addition, or refactor), update `CHANGELOG.md` with:
- A concise summary of the change.
- Links to relevant issues/PRs.
- MCP or visual testing impacts (if any).

### Example Entry
```markdown
## [Unreleased]
- Fixed base64 PNG loading in MCP image validation.
- Added SVG support for application icons.
- Implemented visual regression testing for UI glitches.
```

---

## Sandbox Environment

### Remote Sandbox (GitHub Codespaces)
1. **Setup**:
   - Open the project in GitHub Codespaces (automatically uses `.devcontainer.json`).
   - The container includes:
     - X11 forwarding for GUI testing.
     - `xvfb` for virtual display.
     - All dependencies (Qt, Playwright, etc.).

2. **Run Tests**:
   ```bash
   # Start Xvfb (if not already running)
   Xvfb :1 -screen 0 1024x768x24 &
   export DISPLAY=:1
   
   # Run visual tests
   pytest tests/visual/ -v
   ```

3. **Debugging**:
   - Use `local-everything_toggle-simulated-logging` for MCP logs.
   - Capture screenshots manually:
     ```bash
     import pyautogui
     pyautogui.screenshot("debug.png")
     ```

4. **Launch SonicTune**:
   ```bash
   python -m sonictune
   ```

---

## CI/CD Integration

### GitHub Actions
Visual regression tests run automatically on every push/pull request:

1. **Workflow**: `.github/workflows/visual-tests.yml`
2. **Environment**:
   - Ubuntu + Xvfb (virtual display).
   - Playwright for screenshot capture.
3. **Artifacts**:
   - Screenshots are uploaded as artifacts for debugging.

### Run Locally
```bash
# Start Xvfb
Xvfb :1 -screen 0 1024x768x24 &
export DISPLAY=:1

# Run tests
pytest tests/visual/ -v
```

---

## Next Steps
1. **Implement MCP image validation fixes** (e.g., allow data URIs).
2. **Set up visual regression tests** in the sandbox.
3. **Automate testing** in CI/CD (GitHub Actions).