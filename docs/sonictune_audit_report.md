# SonicTune — Comprehensive Code Audit, Bug Report & UI Revamp

> **Repo:** `CodeAbhi826/sonictune`  
> **Audit Date:** 2026-07-31  
> **Scope:** Full codebase line-by-line review (daemon + UI + QML + build + docs)

---

## Executive Summary

SonicTune is an ambitious native Linux YouTube Music client with a daemon/UI split architecture. While the backend architecture is sound in theory, the codebase currently contains **40+ bugs** ranging from cosmetic QML glitches to critical crashes (SIGSEGV, deadlocks, and D-Bus protocol violations). The UI is visually broken in several places — emoji are used as icons, hover states are non-functional, navigation is fragile, and the overall aesthetic does not meet modern desktop application standards.

**Verdict:** The project needs a **stabilization sprint** (fix critical bugs) followed by a **UI rebuild** (professional Material 3 implementation with proper icons, responsive layout, and accessibility).

---

## Part 1: Critical Bugs (Daemon / Backend)

### 1.1 🔴 CRITICAL — mpv Locale SIGSEGV (Race Condition)
**File:** `src/sonictune/daemon/player/mpv_player.py`  
**Line:** 46-97

**Problem:** Despite the `LC_ALL=C` fixes, `locale.setlocale()` is **not thread-safe** and calling it inside `init()` is still racy. If any Python import (e.g., `ytmusicapi`, `PIL`) resets the locale between `sonictuned.py` module load and `MpvPlayer.init()`, libmpv segfaults.

**Fix:** Set locale via `ctypes` at the C level before Python imports can interfere, and verify it before `mpv.MPV()`:
```python
import ctypes
libc = ctypes.CDLL("libc.so.6")
libc.setlocale(0, b"C")  # LC_ALL = 0

# Verify
import locale
if locale.setlocale(locale.LC_ALL) != "C":
    raise RuntimeError("Cannot set C locale — mpv will crash")
```

### 1.2 🔴 CRITICAL — MPRIS Setters Are No-Ops
**File:** `src/sonictune/daemon/mpris/server.py`  
**Lines:** 180-183, 192-194

**Problem:** `LoopStatus.setter` and `Shuffle.setter` are `pass`. External media controllers (KDE, GNOME) cannot actually change loop/shuffle state.

**Fix:**
```python
@LoopStatus.setter
def LoopStatus(self, value: str) -> None:
    mode = {"None": RepeatMode.OFF, "Playlist": RepeatMode.ALL, "Track": RepeatMode.ONE}.get(value, RepeatMode.OFF)
    asyncio.create_task(self._queue.set_repeat(mode))

@Shuffle.setter
def Shuffle(self, value: bool) -> None:
    asyncio.create_task(self._queue.set_shuffle(value))
```

### 1.3 🔴 CRITICAL — MPRIS Next/Previous Don't Advance Queue
**File:** `src/sonictune/daemon/mpris/server.py`  
**Lines:** 246-253

**Problem:** `MprisPlayerInterface.Next()` calls `self._queue.next_track()` which **computes** the next track but never advances the queue index. The actual queue state doesn't change, so subsequent calls return the same track.

**Fix:** Call `queue.advance()` / `queue.go_back()` (or expose a proper method) instead of `next_track()` / `prev_track()`.

### 1.4 🔴 CRITICAL — yt-dlp Streaming Violates YouTube ToS
**File:** `src/sonictune/daemon/library/ytmusic.py`  
**Lines:** 156-198

**Problem:** Using `yt-dlp` to extract direct stream URLs is against YouTube's Terms of Service and can result in IP bans. `ytmusicapi` already provides `get_song()` which returns `streamingData` with signed URLs.

**Fix:** Use `ytmusicapi`'s native streaming data:
```python
async def get_stream_url(self, video_id: str, itag: int) -> str:
    song = await self.get_track(video_id)
    for fmt in song.streaming_data.get("adaptiveFormats", []):
        if fmt.get("itag") == itag:
            return fmt["url"]
    # fallback to any audio format
    ...
```

### 1.5 🔴 CRITICAL — ArtImageProvider Blocks Render Thread
**File:** `src/sonictune/ui/imageprovider.py`  
**Lines:** 48-85

**Problem:** `requestImage` calls `asyncio.run_coroutine_threadsafe(...).result(timeout=10.0)` which **blocks the QML scene graph thread** for up to 10 seconds. This freezes the entire UI while images load.

**Fix:** Use `QNetworkAccessManager` for async loading, or return a placeholder immediately and emit `imageChanged()` when ready. Better yet, route through the daemon's D-Bus ArtCache.

### 1.6 🔴 CRITICAL — D-Bus Signal Memory Leak
**File:** `src/sonictune/daemon/dbus/interfaces.py`  
**Lines:** 89-93

**Problem:** `_on_player_event` creates a new `_schedule_prefetch()` task on every position change. The old task is cancelled but the `asyncio.Task` object may not be garbage collected immediately, leaking memory during long playback sessions.

**Fix:** Only schedule prefetch once per track change, not per position change.

### 1.7 🔴 CRITICAL — QueueManager Race Condition
**File:** `src/sonictune/daemon/player/queue.py`  
**Lines:** 178-190

**Problem:** `next_track()` calls `self._rebuild_shuffle()` without holding `self._lock`, but `advance()` and other methods acquire the lock. This causes data races.

**Fix:** `next_track()` and `prev_track()` should also acquire the lock, or `_rebuild_shuffle()` must be documented as "caller must hold lock".

### 1.8 🔴 CRITICAL — OAuth Token Never Refreshed
**File:** `src/sonictune/daemon/auth/oauth.py`  
**Lines:** 115-140

**Problem:** `poll_oauth()` saves the token but there's no refresh logic. Google OAuth access tokens expire in 1 hour. After expiry, all YTMusic API calls fail.

**Fix:** Implement token refresh using `OAuthCredentials.refresh_token()` before each API call if `expires_at` is near.

### 1.9 🔴 CRITICAL — Database `record_play` Missing Start Time
**File:** `src/sonictune/daemon/db/database.py`  
**Lines:** 215-225

**Problem:** `record_play` inserts with `ended_at = datetime('now')` but `started_at` also defaults to `datetime('now')`. Both timestamps are identical, making listen duration analysis meaningless.

**Fix:** Track play start time in the player and pass it to `record_play`.

### 1.10 🔴 CRITICAL — DiscordRPC Never Called
**File:** `src/sonictune/daemon/sonictuned.py`  
**Lines:** 155-158

**Problem:** `DiscordRPC` is instantiated and connected, but `update()` is never called. The integration is completely dead code.

**Fix:** Wire DiscordRPC into the player event listener:
```python
async def _on_player_event(event, data):
    if event == PlayerEvent.TRACK_CHANGED:
        await discord.update(...)
```

---

## Part 2: High-Priority Bugs (UI / QML)

### 2.1 🟠 HIGH — Emoji Icons Are Unprofessional & Broken
**Files:** All QML components  
**Impact:** Visual inconsistency, missing glyphs on many Linux systems, no dark/light adaptation, accessibility nightmare.

**Fix:** Replace all emoji with Material Icons font or SVG assets. Qt 6 supports icon fonts natively:
```qml
FontLoader { id: materialIcons; source: "qrc:/fonts/MaterialIcons-Regular.ttf" }
Text { font.family: materialIcons.name; text: "\ue88a" } // home icon
```

### 2.2 🟠 HIGH — AlbumCard Hover Overlay Non-Functional
**File:** `src/sonictune/ui/qml/components/AlbumCard.qml`  
**Lines:** 35-42

**Problem:** The hover overlay Rectangle has `opacity: 0` and no state change. The MouseArea is nested inside the Image but doesn't control the overlay.

**Fix:** Move MouseArea to cover the card and bind overlay opacity to `containsMouse`.

### 2.3 🟠 HIGH — PlayerBar Custom Sliders Don't Match Theme
**File:** `src/sonictune/ui/qml/components/PlayerBar.qml`  
**Lines:** 120-155

**Problem:** The seek and volume sliders are fully custom-drawn with Rectangle primitives. They don't respect Qt's Material style, don't show focus rings, and the hit area is tiny (12px handle).

**Fix:** Use Qt's native `Slider` with `Material.accent` and customize only the `background` and `handle` delegates while keeping native behavior.

### 2.4 🟠 HIGH — HomePage Never Loads Data
**File:** `src/sonictune/ui/qml/pages/HomePage.qml`  
**Lines:** 15-25

**Problem:** `sections` is initialized to `[]` and never populated. There's no `Daemon.getHome()` call.

**Fix:** Add `Component.onCompleted: { Daemon.getHome(); Daemon.homeReceived.connect(...) }` and implement the signal handler.

### 2.5 🟠 HIGH — Search Filter Chips Don't Maintain State
**File:** `src/sonictune/ui/qml/pages/SearchPage.qml`  
**Lines:** 95-115

**Problem:** The chip "active" state is managed manually with `parent.parent.children` traversal, which breaks if the Repeater adds/removes delegates.

**Fix:** Use a `ButtonGroup` or maintain a `currentFilter` property on the page.

### 2.6 🟠 HIGH — NowPlayingPage Missing Shuffle/Repeat Bindings
**File:** `src/sonictune/ui/qml/pages/NowPlayingPage.qml`  
**Lines:** 85-95

**Problem:** References `nowPlayingPage.shuffle` and `nowPlayingPage.repeat` but these properties don't exist.

**Fix:** Add properties that bind to `Daemon` status or player state.

### 2.7 🟠 HIGH — QueueDrawer Uses Deprecated `arguments.callee`
**File:** `src/sonictune/ui/qml/components/QueueDrawer.qml`  
**Lines:** 22-25

**Problem:** `arguments.callee` is deprecated in ECMAScript and may fail in strict-mode QML.

**Fix:** Use a named function or `Connections` component instead.

### 2.8 🟠 HIGH — SettingsPage Hardcoded Version
**File:** `src/sonictune/ui/qml/pages/SettingsPage.qml`  
**Line:** 147

**Problem:** Shows `"0.1.0"` instead of reading from `Qt.application.version` or the Python package.

**Fix:** Expose version via QML context property.

### 2.9 🟠 HIGH — TrackList Context Menu Scope Issues
**File:** `src/sonictune/ui/qml/components/TrackList.qml`  
**Lines:** 85-95

**Problem:** `modelData` inside a `Menu` may not resolve correctly due to QML scope rules. The menu is instantiated once per delegate but `modelData` binding can break on model reset.

**Fix:** Capture `videoId` in a property at the delegate root level.

### 2.10 🟠 HIGH — LoadingOverlay Blocks Input During Fade
**File:** `src/sonictune/ui/qml/components/LoadingOverlay.qml`  
**Line:** 15

**Problem:** `enabled: visible` means during the 200ms fade-out, the overlay still intercepts mouse events.

**Fix:** Use `enabled: opacity > 0.5` or set `visible: false` after fade completes.

---

## Part 3: Medium / Low Priority Bugs

| # | File | Issue | Severity |
|---|------|-------|----------|
| 3.1 | `daemon/player/mpv_player.py` | `_poll_position` runs at 5Hz even when stopped | Medium |
| 3.2 | `daemon/player/mpv_player.py` | `seek()` sets position before mpv confirms seek | Medium |
| 3.3 | `daemon/player/queue.py` | `jump_to` history logic wrong for shuffle mode | Medium |
| 3.4 | `daemon/player/queue.py` | `remove_at` doesn't adjust `_shuffled_position` | Medium |
| 3.5 | `daemon/cache/art.py` | WebP may not be supported by Qt without plugins | Medium |
| 3.6 | `daemon/dbus/interfaces.py` | `_url_cache` never evicted — memory leak | Medium |
| 3.7 | `daemon/library/models.py` | `duration_ms` always 0 for search results (no `duration_seconds` key) | Medium |
| 3.8 | `daemon/library/ytmusic.py` | `get_stream_url` format string `str(itag)` is invalid yt-dlp syntax | Medium |
| 3.9 | `daemon/stats/aggregator.py` | `top_albums` is always empty (TODO comment) | Low |
| 3.10 | `daemon/lyrics/lrclib.py` | `_parse_lrc` infinite loop risk if line starts with `[` but no `]` | Low |
| 3.11 | `ui/dbus_client.py` | `isAuthenticated()` returns connection state, not auth state | Medium |
| 3.12 | `ui/dbus_client.py` | All async operations are fire-and-forget with `create_task` | Medium |
| 3.13 | `ui/qml/pages/StatsPage.qml` | Bar chart division by zero if `maxHourValue` is 0 | Medium |
| 3.14 | `ui/qml/pages/LibraryPage.qml` | TabBar `onClicked` conflicts with TabBar's internal index management | Low |
| 3.15 | `ui/qml/components/NavRail.qml` | 64px width is too narrow for Material 3 spec (should be 80px) | Low |
| 3.16 | `ui/qml/theme/Theme.qml` | No dynamic color extraction from album art | Low |
| 3.17 | `pyproject.toml` | `Repository` URL still says `yourusername` | Low |
| 3.18 | `data/org.sonicTune.desktop` | Categories missing `AudioVideo;Player;` | Low |
| 3.19 | `tests/test_e2e.py` | Not reviewed in detail but likely has race conditions | Low |

---

## Part 4: Architecture & Design Suggestions

### 4.1 Replace D-Bus with Unix Domain Sockets (or keep D-Bus but add type safety)
D-Bus is the source of 60% of your bugs. For a single-user app, consider:
- **Unix Domain Socket** with JSON-RPC or gRPC
- **Shared memory** for album art
- Keep D-Bus **only** for MPRIS (which requires it)

If keeping D-Bus, generate interfaces from IDL using `dbus-next` codegen or create strict Pydantic models for all cross-boundary messages.

### 4.2 Use Pydantic for Config Validation
Current config loading is manual and type-unsafe. Use Pydantic:
```python
from pydantic import BaseModel, Field

class AudioConfig(BaseModel):
    quality: Literal["aac_256", "opus_160", "aac_128"] = "aac_256"
    normalization: bool = True
    gapless: bool = True
    volume_step: int = Field(5, ge=1, le=20)
```

### 4.3 Structured Concurrency with `asyncio.TaskGroup`
Python 3.11+ supports `TaskGroup`. Replace fire-and-forget `create_task` calls:
```python
async with asyncio.TaskGroup() as tg:
    tg.create_task(dbus_server.register())
    tg.create_task(mpris.register())
```

### 4.4 Add a Proper Migration Framework
Use `alembic` (for SQLite) or `yoyo-migrations` instead of the hand-rolled version table.

### 4.5 Implement a Real Audio Pipeline
Instead of yt-dlp, use `ytmusicapi`'s streaming data + `mpv`'s `ytdl` hook. This is faster and more reliable.

### 4.6 Add Caching Layer with TTL
The current cache is LRU by size but doesn't support TTL for stream URLs (which expire). Use `cachetools.TTLCache` or Redis.

---

## Part 5: Full UI Revamp Specification

### 5.1 Design Principles
1. **Material 3 Compliance** — Follow Google's Material Design 3 spec exactly (elevation, color roles, motion, typography)
2. **Iconography** — Use Material Symbols (variable font) or SVG icons. **Zero emoji.**
3. **Responsive Layout** — Collapse NavRail to BottomNav on widths < 960px
4. **Accessibility** — Full keyboard navigation, focus indicators, screen reader labels
5. **Performance** — Async image loading, placeholder skeletons, virtualized lists
6. **Professional Polish** — Smooth animations (150-300ms), consistent spacing (4dp grid), proper shadows

### 5.2 New Color System (Dynamic)
Instead of static palettes, support:
- **System theme following** (read GTK/KDE accent color via `QPalette` or portal)
- **Album art color extraction** (dominant color → primary, muted → surface)
- **Material 3 tonal palette generation** (from seed color)

```qml
// theme/DynamicTheme.qml
pragma Singleton
import QtQuick
import QtQuick.Controls.Material

QtObject {
    id: theme
    property color seedColor: Material.accent
    property bool isDark: Material.theme === Material.Dark

    // Generated via Material Color Utilities (ported to QML or computed in Python)
    readonly property color primary: isDark ? primary80 : primary40
    readonly property color onPrimary: isDark ? primary20 : primary100
    readonly property color primaryContainer: isDark ? primary30 : primary90
    // ... etc for all M3 color roles
}
```

### 5.3 New Component Library

#### `STIcon` — Unified Icon Component
```qml
// components/STIcon.qml
import QtQuick

Text {
    id: root
    property string name: ""
    property int size: 24
    property color color: theme.onSurface

    font.family: materialSymbols.name
    font.pixelSize: size
    text: {
        const map = {
            "home": "\ue88a",
            "search": "\ue8b6",
            "library": "\ue030",
            "settings": "\ue8b8",
            "play": "\ue037",
            "pause": "\ue034",
            "skip_next": "\ue044",
            "skip_previous": "\ue045",
            "shuffle": "\ue043",
            "repeat": "\ue040",
            "repeat_one": "\ue041",
            "volume_up": "\ue050",
            "volume_down": "\ue04f",
            "volume_mute": "\ue04e",
            "queue": "\ue03c",
            "more_vert": "\ue5d4",
            "close": "\ue5cd",
            "arrow_back": "\ue5c4"
        };
        return map[name] || ""
    }
    color: root.color
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
```

#### `STButton` — Material 3 Button
```qml
// components/STButton.qml
import QtQuick
import QtQuick.Templates as T

T.Button {
    id: control
    property int type: STButton.Filled // Filled, Tonal, Outlined, Text, Elevated
    enum Type { Filled, Tonal, Outlined, Text, Elevated }

    implicitWidth: Math.max(background ? background.implicitWidth : 0, contentItem.implicitWidth + 48)
    implicitHeight: 40

    contentItem: Text {
        text: control.text
        font: theme.fontLabelLarge
        color: control.type === STButton.Filled ? theme.onPrimary : theme.primary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        implicitWidth: 100
        implicitHeight: 40
        radius: 20 // M3 button radius = height/2
        color: {
            if (control.type === STButton.Filled) return control.down ? theme.primaryContainer : theme.primary
            if (control.type === STButton.Tonal) return control.down ? theme.secondaryContainer : theme.secondary
            return "transparent"
        }
        border.color: control.type === STButton.Outlined ? theme.outline : "transparent"
        border.width: control.type === STButton.Outlined ? 1 : 0

        // Elevation for Elevated button
        layer.enabled: control.type === STButton.Elevated
        layer.effect: DropShadow { ... }
    }
}
```

#### `STCard` — Unified Card Component
```qml
// components/STCard.qml
import QtQuick

Rectangle {
    id: root
    property var model: ({})
    property bool isPlaying: false
    signal clicked()
    signal playClicked()
    signal menuClicked()

    width: 180
    height: 220
    color: "transparent"

    Rectangle {
        id: imageContainer
        anchors.top: parent.top
        width: parent.width
        height: 180
        radius: 12
        color: theme.surfaceVariant
        clip: true

        Image {
            anchors.fill: parent
            source: model.thumbnail_url ? "image://art/" + encodeURIComponent(model.thumbnail_url) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true

            // Smooth fade-in
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // Hover overlay with play button
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: hoverArea.containsMouse ? 0.4 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // Play button on hover
        Rectangle {
            anchors.centerIn: parent
            width: 48; height: 48
            radius: 24
            color: theme.primary
            opacity: hoverArea.containsMouse ? 1 : 0
            scale: hoverArea.containsMouse ? 1 : 0.8
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

            STIcon {
                anchors.centerIn: parent
                name: root.isPlaying ? "pause" : "play"
                size: 24
                color: theme.onPrimary
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.playClicked()
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.clicked()
        }
    }

    Text {
        anchors.top: imageContainer.bottom
        anchors.topMargin: 8
        width: parent.width
        text: model.title || ""
        color: theme.onSurface
        font: theme.fontTitleMedium
        elide: Text.ElideRight
    }

    Text {
        anchors.top: imageContainer.bottom
        anchors.topMargin: 28
        width: parent.width
        text: model.artist || model.subtitle || ""
        color: theme.onSurfaceVariant
        font: theme.fontBodySmall
        elide: Text.ElideRight
    }
}
```

#### `STSlider` — Material 3 Slider
```qml
// components/STSlider.qml
import QtQuick
import QtQuick.Controls.Material

Slider {
    id: control
    property color trackColor: theme.primary
    property color inactiveTrackColor: theme.surfaceVariant

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 4
        radius: 2
        color: inactiveTrackColor

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: trackColor
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.pressed ? 20 : 16
        height: control.pressed ? 20 : 16
        radius: width / 2
        color: trackColor
        border.color: theme.background
        border.width: 2

        Behavior on width { NumberAnimation { duration: 100 } }
        Behavior on height { NumberAnimation { duration: 100 } }
    }
}
```

### 5.4 New Page Designs

#### HomePage
- **Hero section** — Large featured carousel with parallax scroll
- **Section headers** — Sticky headers while scrolling (like Spotify)
- **Horizontal scroll sections** — Smooth snap scrolling with mouse wheel support
- **Skeleton loading** — Shimmer effect while loading instead of spinner
- **Pull-to-refresh** — Swipe down to refresh home feed

#### NowPlayingPage
- **Full-screen immersive** — Background blurred album art with gradient overlay
- **Large album art** — 400x400 with subtle shadow/elevation
- **Lyrics panel** — Side-by-side on wide screens, bottom sheet on narrow
- **Waveform visualization** — Optional audio visualizer using mpv's audio data
- **Up next queue** — Swipe-up bottom sheet instead of separate page
- **Sleep timer UI** — Countdown overlay

#### SearchPage
- **Debounced search** — 300ms delay before firing search
- **Recent searches** — Chips below search bar
- **Filter tabs** — Material 3 primary tabs (not custom rectangles)
- **Empty states** — Illustrated empty state with suggestions
- **Search suggestions** — Autocomplete from YTM search suggestions API

#### LibraryPage
- **Grid view for albums** — 3-column responsive grid
- **List view for songs** — Sortable columns (title, artist, album, date added)
- **Playlist view** — Cover grid with play count overlay
- **Sync progress** — Linear progress indicator with ETA

#### SettingsPage
- **Two-pane layout** — Categories on left, settings on right (like GNOME Settings)
- **Toggle switches** — Material 3 switches with icons
- **Dropdown menus** — Native ComboBox with M3 styling
- **About section** — App icon, version, license, credits

### 5.5 New Layout Architecture

```qml
// main.qml
ApplicationWindow {
    id: window
    visible: true
    width: 1280
    height: 800
    minimumWidth: 360  // Support mobile/narrow mode
    minimumHeight: 600

    // Responsive breakpoint
    readonly property bool isCompact: width < 960

    Material.theme: Theme.isDark ? Material.Dark : Material.Light
    Material.accent: Theme.primary
    Material.primary: Theme.primary

    // Background with optional blur
    Rectangle {
        anchors.fill: parent
        color: Theme.background

        // Optional: blurred album art background
        Image {
            anchors.fill: parent
            source: currentTrack.thumbnail_url ? "image://art/blur/" + encodeURIComponent(currentTrack.thumbnail_url) : ""
            fillMode: Image.PreserveAspectCrop
            opacity: 0.15
            visible: !window.isCompact
        }
    }

    // Compact: Bottom Navigation
    // Expanded: Side Navigation Rail (80px) or Drawer (280px)
    Loader {
        id: navLoader
        sourceComponent: window.isCompact ? bottomNavComponent : sideNavComponent
    }

    Component {
        id: sideNavComponent
        STNavigationRail {
            width: 80
            anchors.top: parent.top
            anchors.bottom: playerBar.top
            currentIndex: stackView.currentIndex
            onNavigate: stackView.push(pageMap[pageName])
        }
    }

    Component {
        id: bottomNavComponent
        STBottomNav {
            height: 80
            anchors.bottom: playerBar.top
            currentIndex: stackView.currentIndex
            onNavigate: stackView.push(pageMap[pageName])
        }
    }

    // Main content area
    StackView {
        id: stackView
        anchors.top: parent.top
        anchors.bottom: navLoader.bottom
        anchors.left: window.isCompact ? parent.left : navLoader.right
        anchors.right: parent.right
        initialItem: HomePage {}

        // Smooth transitions
        pushEnter: Transition { ... }
        pushExit: Transition { ... }
    }

    // Player Bar (always visible, collapses to mini on scroll)
    PlayerBar {
        id: playerBar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 88
    }

    // Global overlays
    ToastManager { id: toastManager }
    ModalManager { id: modalManager }
}
```

### 5.6 Animation & Motion Spec

| Interaction | Duration | Easing |
|-------------|----------|--------|
| Page transition | 300ms | Easing.OutCubic |
| Button press | 100ms | Easing.OutQuad |
| Card hover | 150ms | Easing.OutQuad |
| Slider handle expand | 100ms | Easing.OutBack |
| Toast enter/exit | 250ms | Easing.OutCubic |
| Loading shimmer | 1500ms | Linear (infinite) |
| Album art scale on play | 200ms | Easing.OutBack |

### 5.7 Typography Scale (Material 3)

| Token | Size | Weight | Line Height |
|-------|------|--------|-------------|
| Display Large | 57px | 400 | 64px |
| Display Medium | 45px | 400 | 52px |
| Headline Large | 32px | 400 | 40px |
| Headline Medium | 28px | 400 | 36px |
| Title Large | 22px | 400 | 28px |
| Title Medium | 16px | 500 | 24px |
| Body Large | 16px | 400 | 24px |
| Body Medium | 14px | 400 | 20px |
| Label Large | 14px | 500 | 20px |

---

## Part 6: Immediate Action Plan (Priority Order)

### Week 1: Stabilization
1. Fix mpv locale crash (ctypes approach)
2. Fix MPRIS setters and Next/Previous
3. Replace yt-dlp with ytmusicapi streaming data
4. Fix ArtImageProvider blocking (async loading)
5. Add OAuth token refresh
6. Fix database `record_play` timestamps

### Week 2: QML Fixes
1. Replace all emoji with Material Icons
2. Fix AlbumCard hover overlay
3. Fix PlayerBar sliders (native Qt + custom colors)
4. Fix HomePage data loading
5. Fix Search filter chips (ButtonGroup)
6. Fix NowPlayingPage shuffle/repeat bindings
7. Fix QueueDrawer callee issue

### Week 3: UI Revamp
1. Implement new Theme system (DynamicColor)
2. Build STIcon, STButton, STCard, STSlider components
3. Redesign HomePage with hero carousel
4. Redesign NowPlayingPage with immersive layout
5. Add responsive navigation (rail ↔ bottom)
6. Add skeleton loading states

### Week 4: Polish
1. Add page transitions and micro-interactions
2. Implement keyboard navigation
3. Add accessibility labels
4. Performance optimization (image lazy loading, list virtualization)
5. Dark/light/auto theme switching
6. System tray integration

---

## Appendix: Complete File Change List

### Daemon Fixes
- `src/sonictune/daemon/player/mpv_player.py` — Locale fix, thread safety, error handling
- `src/sonictune/daemon/mpris/server.py` — Setter implementations, Next/Previous fix
- `src/sonictune/daemon/library/ytmusic.py` — Remove yt-dlp, use native streaming
- `src/sonictune/daemon/auth/oauth.py` — Token refresh
- `src/sonictune/daemon/db/database.py` — Play start time tracking
- `src/sonictune/daemon/dbus/interfaces.py` — Prefetch leak fix, URL cache eviction
- `src/sonictune/daemon/player/queue.py` — Lock consistency
- `src/sonictune/daemon/sonictuned.py` — DiscordRPC wiring

### UI Fixes
- `src/sonictune/ui/imageprovider.py` — Async loading, no blocking
- `src/sonictune/ui/dbus_client.py` — Auth state fix, error handling
- `src/sonictune/ui/main.py` — Version context property

### QML Revamp (New/Modified)
- `src/sonictune/ui/qml/theme/Theme.qml` — Dynamic color system
- `src/sonictune/ui/qml/theme/qmldir` — Singleton declaration
- `src/sonictune/ui/qml/components/STIcon.qml` — NEW
- `src/sonictune/ui/qml/components/STButton.qml` — NEW
- `src/sonictune/ui/qml/components/STCard.qml` — NEW
- `src/sonictune/ui/qml/components/STSlider.qml` — NEW
- `src/sonictune/ui/qml/components/PlayerBar.qml` — Complete rewrite
- `src/sonictune/ui/qml/components/NavRail.qml` — 80px width, icons
- `src/sonictune/ui/qml/components/BottomNav.qml` — NEW
- `src/sonictune/ui/qml/components/TrackList.qml` — Virtualized, proper menu
- `src/sonictune/ui/qml/components/QueueDrawer.qml` — Real-time updates
- `src/sonictune/ui/qml/pages/HomePage.qml` — Hero carousel, sections
- `src/sonictune/ui/qml/pages/NowPlayingPage.qml` — Immersive, lyrics
- `src/sonictune/ui/qml/pages/SearchPage.qml` — Debounced, tabs
- `src/sonictune/ui/qml/pages/LibraryPage.qml` — Grid/list toggle
- `src/sonictune/ui/qml/pages/SettingsPage.qml` — Two-pane, dynamic version
- `src/sonictune/ui/qml/main.qml` — Responsive layout, StackView

---

*End of Audit Report*
