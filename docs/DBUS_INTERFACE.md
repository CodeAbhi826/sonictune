# D-Bus Interface Specification

As of the Phase A unification (v10), SonicTune is a **single-process
application**. The custom `org.sonicTune.Daemon` D-Bus API has been
removed — the UI talks to services via direct Python calls.

The only D-Bus surface remaining is **MPRIS v2** (the standard desktop
integration protocol), used so that media keys, lockscreens, and
GNOME/KDE playback widgets can control playback.

Bus name: **`org.mpris.MediaPlayer2.sonictune`**

Object path: **`/org/mpris/MediaPlayer2`**

## Interfaces

| Interface | Purpose |
|---|---|
| `org.mpris.MediaPlayer2` | Root MPRIS interface (Identity, Raise, Quit) |
| `org.mpris.MediaPlayer2.Player` | Standard MPRIS transport (Next, Previous, Play, Pause, etc.) |

## `org.mpris.MediaPlayer2`

| Property | Type | Description |
|---|---|---|
| `Identity` | `s` | `"SonicTune"` |
| `CanQuit` | `b` | `true` |
| `CanRaise` | `b` | `true` |
| `HasTrackList` | `b` | `false` |

## `org.mpris.MediaPlayer2.Player`

| Property | Type | Description |
|---|---|---|
| `PlaybackStatus` | `s` | `"Playing"` / `"Paused"` / `"Stopped"` |
| `LoopStatus` | `s` | `"None"` / `"Playlist"` / `"Track"` |
| `Shuffle` | `b` | Shuffle state |
| `Position` | `x` | Current position (µs) |
| `Metadata` | `a{sv}` | `mpris:trackid`, `mpris:length`, `xesam:title`, `xesam:artist`, `xesam:album`, `mpris:artUrl` |
| `Volume` | `d` | 0.0–1.0 |

| Method | Description |
|---|---|
| `Play` / `Pause` / `PlayPause` / `Stop` | Transport control |
| `Next` / `Previous` | Advance / go back in the queue |
| `Seek` / `SetPosition` | Seek |
| `SetVolume` | Set volume |

## Examples

### Play / pause from CLI

```bash
dbus-send --session --dest=org.mpris.MediaPlayer2.sonictune \
  --type=method_call /org/mpris/MediaPlayer2 \
  org.mpris.MediaPlayer2.Player.PlayPause
```

### Query playback status

```bash
dbus-send --session --dest=org.mpris.MediaPlayer2.sonictune \
  --type=method_call --print-reply /org/mpris/MediaPlayer2 \
  org.freedesktop.DBus.Properties.Get \
  string:org.mpris.MediaPlayer2.Player string:PlaybackStatus
```

### Introspect

```bash
gdbus introspect --session \
  --dest org.mpris.MediaPlayer2.sonictune \
  --object-path /org/mpris/MediaPlayer2
```

## MPRIS in the codebase

- `src/sonictune/mpris/server.py` — MPRIS v2 server (dbus-next). Registered
  on startup when `config.mpris.enabled` is true; can be disabled with
  `--no-mpris`.
