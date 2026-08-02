# SonicTune — Independent Code Audit & UI Revamp

**Date:** 2026-08-01
**Scope:** Full line-by-line review of `daemon/` (~4,600 lines) and `ui/` (~3,500 lines),
cross-checked against the project's existing `docs/BUG_REPORT.md`, followed by fixes
for every confirmed bug and a full rebuild of the QML UI layer.

This audit found the existing `BUG_REPORT.md`'s "all known bugs fixed" claims to be
largely accurate for the bugs it lists — but it missed a systemic bug that explains
most of what "the UI looks broken" actually looks like in practice, plus several
smaller correctness issues. All of the below are now fixed in this checkout.

---

## 1. The headline bug: D-Bus `Variant` objects were never unwrapped

**Files:** `ui/dbus_client.py` (systemic — nearly every method)
**Severity:** Critical — this is almost certainly what "the UI is kinda broken" was pointing at.

Every daemon method that returns structured data uses D-Bus's `a{sv}` / `aa{sv}`
signatures — a dict/list where each **value** is individually wrapped in a
`dbus_next.Variant(signature, value)` object, not a plain Python primitive. The old
`dbus_client.py` did `dict(result)` / `list(result)` before handing data to Qt
signals — which only copies the *container*. Every leaf value stayed a `Variant`
instance. QML then bound directly to these (`track.title`, `status.volume`,
`modelData.artist`, …) and got back non-primitive objects it can't render.

Concretely, this meant:

- The **Now Playing bar** always showed its "Nothing playing" fallback, even while
  music was actually playing, because `track.title` was never a real string.
- The **window title** never updated.
- **Stats page** showed all zeros — and I can point to exactly where this throws:
  `getStats()`'s own post-processing did `json.loads(parsed[key])` where
  `parsed[key]` was a `Variant`, not a string → `TypeError`, silently swallowed by
  the existing `except (json.JSONDecodeError, TypeError)`. Same story for the
  `.lstrip("-").isdigit()` branch → `AttributeError`, also swallowed.
- **Search results, queue contents, library listings, lyrics** — all affected the
  same way.

**Fix:** added a recursive `_unwrap()` helper in `dbus_client.py` that walks
Variant → dict → list structures and converts everything to plain Python values,
applied at every point a D-Bus result crosses into a Qt signal (`.emit(...)`) or a
signal handler receives daemon-pushed data.

---

## 2. Home page could never load anything

**Files:** `ui/dbus_client.py`, `ui/qml/pages/HomePage.qml`
**Severity:** Critical

`LibraryInterface.GetHome()` was fully implemented on the daemon side, but
`dbus_client.py` never wrapped it in a callable `Slot` — `Daemon.getHome()` simply
didn't exist. `HomePage.qml` never called anything else either, so `sections`
stayed `[]` forever and the page sat on its "loading…" placeholder permanently,
regardless of daemon or auth state.

**Fix:** added `getHome()` / `homeReceived` / `homeError` to `dbus_client.py`, and
`HomePage.qml` now calls it on load/reconnect and renders horizontally-scrolling
sections. Also fixed `GetHome()` on the daemon side to `json.dumps()` nested
**dicts**, not just lists (it previously only special-cased `list` values, so a
section value that was itself a dict fell through to `str(v)` — a Python repr, not
valid JSON — same class of bug as issue #3 below).

---

## 3. `Search()` mangled nested fields with `str()` instead of JSON

**File:** `daemon/dbus/interfaces.py` (`LibraryInterface.Search`)
**Severity:** High

`Search()` flattened every result field via `str(v)`, including nested
lists/dicts like `thumbnails`, `artists`, `album`. `str([{'name': 'Foo', ...}])`
produces a Python-repr string, not JSON — unusable by the QML side, which expects
the same `json.dumps()`-for-non-primitives convention `GetHome()` already used
(inconsistently applied only to `list` values, not `dict`s — see #2). This broke
album/artist/playlist search results specifically (song results happened to work
since their fields are mostly flat strings).

**Fix:** `Search()` now uses the same `json.dumps(v, default=str)` convention for
list/dict fields as the fixed `GetHome()`.

---

## 4. OAuth token persisted but unusable after every daemon restart

**Files:** `daemon/auth/oauth.py`, `daemon/dbus/interfaces.py`, `daemon/library/ytmusic.py`
**Severity:** Critical for anyone who signs in

`OAuthManager.init()` loaded the saved access token from disk, but never
reconstructed the `OAuthCredentials` object (`self._oauth`) — that was only ever
set inside `start_oauth()`, in memory, never persisted. `build_ytmusic()` requires
**both** `self._token` and `self._oauth` before it'll use the saved token:

```python
if self._token and self._oauth:
    return YTMusic(oauth_credentials=self._oauth, auth=self._token)
```

So on every daemon restart, `is_authenticated` reported `True` (it only checks the
token), but the library silently fell back to cookies/anonymous mode for actual API
calls — sign-in appeared to "not stick."

**Fix:** `save_token()` now persists `client_id`/`client_secret` alongside the token
(`{"client_id", "client_secret", "token": {...}}`), and `init()` reconstructs
`OAuthCredentials` from them. Old token files (pre-fix format) still load but log a
warning asking the user to sign in once more, since the client credentials weren't
captured before.

### 4b. Auth state didn't account for cookie-based login

`is_authenticated` only ever reflected OAuth-token presence. A user who signed in
via cookie import instead was reported as "not authenticated" forever, and
`ImportCookies()` emitted `AuthChanged(self._oauth.is_authenticated)` — always
`False` for a cookie-only login, so the UI would flash "signed in" then immediately
flip back.

**Fix:** added `YTMusicLibrary.is_authenticated`, which tracks what the client was
*actually* built with (OAuth **or** cookies). `AuthInterface.IsAuthenticated()`,
`ImportCookies()`, and the new `PollOAuth()` success path (see 4c) all use this now.

### 4c. `PollOAuth` never emitted `AuthChanged` on success

Nothing outside the `OAuthDialog`'s own local callback chain was ever told "login
succeeded" via the signal the rest of the app listens to. It happened to *look*
like it worked because the client-side `isAuthenticated()` bug (#5 below) made it
return `True` regardless. Now `PollOAuth()` re-inits the library and emits the real
state on success.

---

## 5. `isAuthenticated()` didn't check real auth state

**File:** `ui/dbus_client.py`
**Severity:** High

```python
def isAuthenticated(self) -> bool:
    return self._connected and self._auth_iface is not None
```

This is `True` for **every** user the instant the UI connects to the daemon,
whether or not they've ever signed in — it checks D-Bus connectivity, not
authentication. Settings and Home pages showed "Signed in" unconditionally.

**Fix:** `dbus_client.py` now keeps a real `_authenticated` flag, initialized by an
explicit `IsAuthenticated()` D-Bus call right after connecting (important for the
case where a token was already on disk from a previous session) and kept current
via the `AuthChanged` signal (now correctly emitted per #4b/4c above).

---

## 6. Next-track prefetch used stale duration/position

**Files:** `daemon/dbus/interfaces.py`, `daemon/player/mpv_player.py`
**Severity:** Medium

Prefetch used to be scheduled once, synchronously, the moment `TRACK_CHANGED`
fired — but at that exact instant `MpvPlayer` hadn't reset (or mpv hadn't yet
reported) the *new* track's duration/position, so "80% through" was computed
against the **previous** track's numbers.

**Fix:** `MpvPlayer.load_url()` now resets `position_ms`/`duration_ms` to `0` the
moment a new track starts loading (honest "no data yet" instead of stale data), and
prefetch scheduling moved to fire off live `POSITION_CHANGED` events instead
(guarded to schedule once per track via `_prefetch_scheduled_for`), using whatever
the first real non-zero duration reading is for that track.

---

## 7. MPRIS Shuffle / LoopStatus setters were no-ops

**File:** `daemon/mpris/server.py`
**Severity:** Medium

Toggling shuffle or repeat from KDE's media widget / GNOME Shell / a lock screen
did nothing — the property setters were empty `pass` stubs.

**Fix:** wired to `self._queue.set_shuffle(...)` / `self._queue.set_repeat(...)`.
`Rate` is left as an intentional no-op with a comment — the player doesn't support
variable playback rate, and MPRIS's `MinimumRate == MaximumRate == 1.0` means
spec-compliant clients shouldn't offer the control at all.

---

## 8. `GetStatus()` didn't actually include shuffle/repeat

**File:** `daemon/dbus/interfaces.py`
**Severity:** Medium — found while fixing the UI, see note below

Shuffle/repeat state lives on the *queue*, not the player, so `status_to_dict()`
never included it. The redesigned transport bar (see Part 2) needs live
shuffle/repeat state to highlight those buttons — binding to `status.shuffle` would
have silently been `undefined` forever, i.e. **the same bug class as #9 below,
about to be reintroduced by this very audit.** Caught it before shipping.

**Fix:** `GetStatus()` now merges in `shuffle`/`repeat` from `self._queue.get_status()`.

---

## 9. Now Playing page's shuffle/repeat buttons read undefined properties

**File:** `ui/qml/pages/NowPlayingPage.qml`
**Severity:** Medium

```qml
onClicked: Daemon.setShuffle(!nowPlayingPage.shuffle)
```

`nowPlayingPage.shuffle` / `.repeat` were never declared anywhere on the page —
always `undefined`, so `!undefined` is always `true`: the shuffle button always
sent `setShuffle(true)` regardless of actual state, and neither button ever
visually reflected reality.

**Fix:** both pages (`PlayerBar`, `NowPlayingPage`) now read from `status`
(populated via `getStatus()` + the `statusReceived`/`queueChanged` signals, see #8).

---

## 10. `QueueDrawer` leaked signal connections on every open

**File:** `ui/qml/components/QueueDrawer.qml`
**Severity:** Medium (grows over a session)

`refresh()` called `Daemon.queueReceived.connect(new closure)` and
`Daemon.statusReceived.connect(new closure)` fresh **every time the drawer
opened**, without disconnecting the previous ones. The `statusReceived` handler
tried to self-disconnect via `arguments.callee`, which is deprecated/unreliable in
QML's JS engine. Over a long session of repeatedly opening the queue, handlers
accumulated — memory growth and increasingly redundant work per signal.

**Fix:** rebuilt on a top-level `Connections { target: Daemon }` block, which Qt
manages as a single subscription for the component's lifetime — opening the
drawer just re-requests fresh data, nothing accumulates.

---

## 11. `QT_QPA_PLATFORM` forced XCB, silently breaking native Wayland

**File:** `ui/main.py`
**Severity:** High, environment-dependent — likely relevant to you specifically

```python
os.environ.setdefault("QT_QPA_PLATFORM", "xcb")  # fallback if Wayland unavailable
```

`setdefault()` only has an effect when the variable is **unset**. Most native
Wayland sessions (including Plasma Wayland) don't set `QT_QPA_PLATFORM` at all,
since Qt auto-detects Wayland on its own — so this line silently **overrode** Qt's
detection and forced every such user through XWayland (blurry fractional scaling,
wrong DPI, extra input latency) even though native Wayland was available and
preferred. Given you're on Arch + KDE, this is a strong candidate for part of what
"looks off."

**Fix:** `os.environ.setdefault("QT_QPA_PLATFORM", "wayland;xcb")` — Qt's documented
list syntax: try Wayland first, only fall back to `xcb` if Wayland genuinely isn't
available.

---

## 12. Daemon's on-disk art cache was fully built but never reachable

**Files:** `daemon/dbus/interfaces.py` (`CacheInterface`), `ui/imageprovider.py`
**Severity:** Low/Medium (efficiency + dead code)

`ArtCache` (WebP, downscaled, disk + in-memory LRU) was instantiated and wired into
`DBusServer`, but no D-Bus method ever exposed it — only audio-cache methods
existed on `CacheInterface`. Separately, `ArtImageProvider` accepted a
`daemon_client` argument in its constructor but never actually used it — every
image was fetched independently via a fresh `httpx` client per request, duplicating
network traffic and never touching the daemon's cache at all.

**Fix:** added `CacheInterface.GetArtPath(url) -> s`, and rewrote
`ArtImageProvider` to ask the daemon for a cached local path first, falling back to
a direct fetch only if the daemon is unreachable or returns nothing.

---

## 13. A few smaller robustness fixes

- **`daemon/player/__init__.py`** — `get_player_class()` only caught `OSError`
  when falling back to `NullPlayer`. If the `mpv` **pip package** itself isn't
  installed (distinct from libmpv the shared library missing), `import mpv` raises
  `ModuleNotFoundError` — uncaught, crashing the daemon instead of degrading
  gracefully. Now catches `(ImportError, OSError)`.
- **`daemon/player/mpv_player.py`** — `load_url()` had no exception handling
  around `mpv.play(url)`. A failed load (bad stream, network error) left state
  stuck at `LOADING` forever with nothing surfaced beyond a log line. Now
  transitions to a proper `ERROR` state and emits a `PlayerEvent.ERROR`.
- **`daemon/library/ytmusic.py`** — `_url_locks` was an unbounded plain dict,
  growing by one `asyncio.Lock()` per distinct `video_id` played/searched for the
  life of the process. Now an `OrderedDict` bounded at 512 entries with LRU
  eviction.
- **Settings page never exposed audio cache management** — the daemon had
  `GetAudioCacheSize`/`ClearAudioCache` and the UI even had a `_cache_iface` proxy
  set up, but nothing in the old UI ever called them. Added a Cache section to the
  rebuilt Settings page.

---

## Part 2 — UI revamp

### What was wrong visually, independent of the bugs above

Even with correct data, the old UI leaned on the stock Material-You purple
(`#6750A4` / `#D0BCFF` — literally Android's default seed color) and raw color
emoji as icons (🔀⏮⏭🔁🔉…), which render inconsistently across systems depending on
the installed emoji font and read as unfinished next to a deliberate design.

### Design direction

Rebuilt around the idea of a piece of **audio hardware** rather than another
Spotify clone: a near-black chassis, a warm amber accent (`#EFAB47`, the "VU
needle"), and a cool signal-teal (`#4FD3C4`) reserved for anything genuinely live.
Kept dark / light / archive modes, refined all three palettes under the same token
system (`theme/Theme.qml`).

- **Typography** — a humanist sans for UI text, plus a monospace face
  (`JetBrains Mono`, falls back gracefully via Qt's normal font matching if
  unavailable) reserved specifically for numeric/technical readouts — timestamps,
  bitrate-style stats, the OAuth device code. That's content that's genuinely
  tabular, so a second type family is earned rather than decorative.
- **Icons** — replaced every emoji with a small hand-drawn vector icon set
  (`components/Icon.qml`, Canvas-based, 24×24 grid convention), so icons are
  monochrome, theme-colored, and consistent regardless of what's installed on the
  system. No new asset/font dependency.
- **Signature control** — the seek bar in the player bar and Now Playing page is a
  stylized bar pattern (`components/WaveformSeekBar.qml`) rather than a flat
  Material slider — deterministic per track (hashed from the track ID, not real
  waveform analysis — it's honestly decorative, not pretending otherwise), themed
  fill up to playback position. This is the one place I gave the app a genuine
  visual signature rather than reskinning stock controls.
- **Elevation** — no drop shadows (avoids depending on the optional
  `Qt5Compat.GraphicalEffects` module); elevation is tonal instead (Material 3's
  actual recommended approach) — higher surfaces get incrementally lighter
  background tints (`surface` → `surfaceContainer` → `surfaceContainerHigh`).
- **Navigation** — rebuilt the left rail with a thin accent indicator on the
  active item instead of a filled pill, and centralized the `QueueDrawer` at the
  window level (previously only reachable from the Now Playing page) so it's
  accessible from the persistent player bar too, plus a `Ctrl+Q` shortcut.

### Files touched

Every file under `ui/qml/` was rewritten: `theme/Theme.qml`, `main.qml`, all of
`components/*.qml` (plus two new ones — `Icon.qml`, `WaveformSeekBar.qml`), and all
of `pages/*.qml`. All the bug fixes from Part 1 that touch QML (getHome wiring,
shuffle/repeat state, QueueDrawer connection leak) are baked into the rebuild
rather than patched separately.

### A note on how this was verified

There's no display server or D-Bus session in the environment this audit ran in,
so none of this could be visually rendered or run end-to-end — that's still worth
doing yourself before trusting it completely. What I could do, and did:

- Every `daemon/*.py` and `ui/*.py` file compiles (`python3 -m py_compile`).
- Cross-referenced **every** `Connections { function onXxx(...) }` handler in QML
  against the actual `Signal` names in `dbus_client.py` — full match, no typos.
- Cross-referenced **every** `Daemon.method(...)` call in QML against the actual
  `@Slot` methods in `dbus_client.py` — full match, no typos.
- Cross-referenced every `Icon { name: "..." }` usage against the cases
  implemented in `Icon.qml` — full match.
- Manually re-derived the daemon's actual field names for `status`/`track`/`queue`
  dicts from `dbus/interfaces.py` rather than assuming, since a field-name
  mismatch here would be exactly the kind of bug this audit was about.
- Installed PySide6 and ran Qt's own `qmllint` static analyzer against every file
  — real tooling, not just manual review. It caught three genuine bugs the manual
  pass above had missed. Full details, and the final verified state, are in
  **Part 3** below.

---

## Part 3 — Follow-up: real static verification with `qmllint`

The first pass of this audit (Parts 1–2) was verified by hand — balanced braces,
manual cross-referencing of signal names, careful re-derivation of field names from
the daemon source. That's real verification, but it's not a substitute for actual
tooling. So: installed PySide6 in the sandbox this ran in and ran `pyside6-qmllint`
(Qt's own static QML analyzer) against every `.qml` file in the project. It found
three genuine bugs the manual pass missed, and confirmed the rest of the codebase
is clean.

### 3a. Property shadowing in the new `WaveformSeekBar`

```qml
property bool enabled: durationMs > 0
```

`Item` already has a built-in `enabled` property (it controls whether the item
accepts input at all). Redeclaring it like this shadows the built-in instead of
using it — `qmllint` flags this class of mistake directly
(`[property-override]`). Fixed by *assigning* to the inherited property instead of
redeclaring it, which also means disabling the bar now properly blocks input via
Qt Quick's normal mechanism rather than only doing a cosmetic dim.

### 3b. Anchors combined with Layout management — real undefined behavior

```qml
RowLayout {
    Layout.preferredWidth: 260
    ...
    MouseArea { anchors.fill: parent; onClicked: playerBar.openNowPlaying() }
}
```

`qmllint` flags this specifically (`[Quick.layout-positioning]`, message: *"Detected
anchors on an item that is managed by a layout. This is undefined behavior"*) —
found in two places: the click-to-open-Now-Playing overlay in `PlayerBar.qml`, and
the Player/Lyrics tab toggles in `NowPlayingPage.qml`. A `MouseArea` that is
directly a child of a `RowLayout`/`ColumnLayout` gets its geometry set by the
layout *and* by `anchors.fill: parent` at the same time — two systems fighting
over the same properties, with no guaranteed winner. Fixed by wrapping each in a
plain `Item` (which the Layout manages normally via `Layout.preferredWidth` /
implicit size) and anchoring the `MouseArea` to *that* instead — the layout only
ever manages the wrapper, never anything using anchors.

### 3c. Ambiguous `parent` reference in the Stats hourly chart

```qml
Row {
    readonly property real maxVal: ...
    Repeater {
        delegate: Rectangle { readonly property real frac: modelData.count / parent.maxVal }
    }
}
```

`qmllint` couldn't resolve `parent.maxVal` and reported it as a missing property on
type `Repeater` (`[missing-property]`). This is very likely a known limitation of
the static analyzer rather than a real runtime bug — `Repeater` is documented to
reparent its generated delegates to its own parent (the `Row`, here), which is
exactly the kind of dynamic behavior a purely static analyzer can't always model —
but rather than leave that ambiguity in place, the `Row` now has an explicit `id`
and the delegate references it directly (`hourlyRow.maxVal`) instead of walking
through `parent`. Removes the ambiguity for both the tool and any future reader,
regardless of which explanation is correct.

### 3d. Modernization: `pragma ComponentBehavior: Bound`

Beyond the three bugs above, `qmllint` flagged pervasive use of QML's *implicit*
`modelData`/`index` injection inside `Repeater`/`ListView` delegates — a pattern
Qt has been moving away from in favor of explicit `required property` declarations
(enabled via `pragma ComponentBehavior: Bound`). Nothing here was broken — implicit
injection still works in Qt 6 — but it's a real deprecation trajectory, so every
delegate in the project (`NavRail`, `WaveformSeekBar`, `LyricsView`, `TrackList`,
`QueueDrawer`, and the `Repeater`s in `HomePage`, `SearchPage`, `LibraryPage`,
`StatsPage`, `SettingsPage`) now declares its model data explicitly instead of
relying on the implicit names.

### Final state

After all of the above, a full `qmllint` pass across every file in the project
comes back with:
- **Zero** errors
- **Zero** `layout-positioning`, `missing-property`, or `property-override` warnings
- **Zero** unresolved imports
- The **only** remaining warnings (77, all expected) are "unqualified access" on
  `Daemon` — which is correct: `Daemon` is a context property injected by Python at
  runtime (`rootContext().setContextProperty(...)`), not a real QML-importable type,
  so a static analyzer has no way to resolve it. That's inherent to this
  architecture (and was equally true of the original code before this audit), not
  something to fix here.

This is also verified independently of the manual checks in Part 2 — full
`python3 -m compileall` still passes, and every `Connections { onXxx }` handler and
`Daemon.method()` call was re-cross-referenced against `dbus_client.py` after all
of these edits, with zero mismatches.

---

## Suggestions for future work (not implemented here)

- **Album/Artist/Playlist detail pages don't exist yet.** Clicking a card
  anywhere (search, home, library) currently falls back to re-searching by
  title/name as the best available action, since there's no browseId-based detail
  view to navigate to. A real detail page (full tracklist for an album, discography
  for an artist) would be a solid v2 feature and is the main thing keeping
  navigation from feeling "finished."
- **`history/sync.py` is a stub**, never instantiated in `sonictuned.py`'s
  `amain()` — matches the README's own "Phase 2" note, just flagging it's still
  fully unwired.
- **The waveform seek bar is decorative**, not real audio analysis. If you ever
  want genuine waveforms, `librosa` or a lightweight FFT pass over cached audio at
  index time would be the natural next step — the component's `trackKey` prop is
  already there to key real per-track data instead of the hash if you build that.
- **Icon.qml is hand-drawn Canvas vector icons**, chosen specifically to avoid a
  new font-asset dependency. If you'd rather have a proper icon font (Lucide,
  Material Symbols, etc.) later, everything routes through this one file, so it's a
  single-file swap.
