"""Player layer — libmpv wrapper + queue management.

The MpvPlayer import is deferred because `import mpv` requires libmpv
to be installed at the system level. By using lazy imports here, the
rest of the daemon can be loaded even when libmpv is unavailable
(useful for testing, CI, and partial development environments).

Use get_player() to get the best available player implementation:
- MpvPlayer if libmpv is installed
- NullPlayer otherwise (no-op stub)
"""

# These are always importable (pure Python, no libmpv dependency)
from sonictune.player.queue import QueueManager, RepeatMode
from sonictune.player.types import PlayerEvent, PlayerState, TrackInfo

__all__ = [
    "MpvPlayer",
    "NullPlayer",
    "PlayerEvent",
    "PlayerState",
    "QueueManager",
    "RepeatMode",
    "TrackInfo",
    "get_player_class",
]


def get_player_class():
    """Return MpvPlayer if libmpv is available, else NullPlayer.

    BUGFIX: previously only caught OSError, which is what python-mpv raises
    when the *libmpv shared library* can't be dlopen()'d. If the `mpv` pip
    package itself isn't installed at all (a distinct, equally common case),
    `import mpv` raises ModuleNotFoundError (a subclass of ImportError)
    instead, which went uncaught and crashed the app at startup instead of
    degrading to NullPlayer as intended.
    """
    try:
        from sonictune.player.mpv_player import MpvPlayer
        return MpvPlayer
    except (ImportError, OSError):
        from sonictune.player.null_player import NullPlayer
        return NullPlayer


def __getattr__(name: str):  # type: ignore[no-untyped-def]
    """Lazy-load mpv-dependent symbols on first access."""
    if name == "MpvPlayer":
        try:
            from sonictune.player.mpv_player import MpvPlayer
            return MpvPlayer
        except (ImportError, OSError):
            from sonictune.player.null_player import NullPlayer
            return NullPlayer
    if name == "NullPlayer":
        from sonictune.player.null_player import NullPlayer
        return NullPlayer
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
