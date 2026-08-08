"""SonicTune unified application — owns all services in a single process."""
from __future__ import annotations

import asyncio
import locale
import logging
import os
import signal
import sys
import time
from dataclasses import asdict, is_dataclass
from pathlib import Path
from typing import TYPE_CHECKING, Any

import qasync
import structlog
from PySide6.QtCore import QUrl
from PySide6.QtGui import QIcon, QPixmap, QPainter
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication

from sonictune import __version__
from sonictune.auth.oauth import OAuthManager
from sonictune.cache.art import ArtCache
from sonictune.cache.audio import AudioCache
from sonictune.config import DaemonConfig, load_config
from sonictune.db.database import Database
from sonictune.discord.rpc import DiscordRPC
from sonictune.integrations.lastfm import LastFmScrobbler
from sonictune.library.sync import LibrarySync
from sonictune.library.ytmusic import YTMusicLibrary
from sonictune.lyrics.lrclib import LrclibClient
from sonictune.mpris.server import MprisServer
from sonictune.player import get_player_class
from sonictune.player.queue import QueueManager
from sonictune.player.sleep_timer import SleepTimer
from sonictune.player.sponsorblock import SponsorBlock
from sonictune.stats.aggregator import StatsAggregator
from sonictune.ui.color_extractor import MaterialYouExtractor

if TYPE_CHECKING:
    from sonictune.player.mpv_player import MpvPlayer
from sonictune.ui.clipboard import ClipboardHelper
from sonictune.ui.daemon_proxy import DaemonProxy
from sonictune.ui.imageprovider import ArtImageProvider

log = structlog.get_logger()


def _camel(s: str) -> str:
    """snake_case -> camelCase."""
    head, *rest = s.split("_")
    return head + "".join(p.capitalize() for p in rest)


def _palette_to_qml_dict(palette: Any) -> dict[str, str]:
    """Serialize a MaterialPalette dataclass into a camelCase dict for QML."""
    if is_dataclass(palette):
        raw = asdict(palette)
    elif isinstance(palette, dict):
        raw = palette
    else:
        return {}
    return {_camel(k): v for k, v in raw.items() if isinstance(v, str)}


class SonicTuneApp:
    """Unified application — owns all services, runs in a single process."""

    def __init__(self, config: DaemonConfig, verbose: bool = False) -> None:
        self.config = config
        self.verbose = verbose
        self._configure_logging()
        self._set_locale()

        # Qt application
        # Try native Wayland first, only fall back to XWayland if Wayland
        # genuinely isn't available. Bare setdefault("QT_QPA_PLATFORM", "xcb")
        # would silently override Qt's own Wayland auto-detection on sessions
        # that don't set this var at all (most native Wayland sessions).
        os.environ.setdefault("QT_QPA_PLATFORM", "wayland;xcb")
        os.environ.setdefault("QT_LOGGING_RULES", "qt.qpa.*=warning")
        os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Material")
        # Forward SIGTERM/SIGINT (terminal Ctrl+C, systemd stop) to Qt's quit,
        # so aboutToQuit -> _on_about_to_quit -> shutdown() runs instead of the
        # process dying abruptly with resources (SQLite WAL, MPRIS, mpv, Discord
        # socket) left dangling.
        signal.signal(signal.SIGTERM, lambda *_: self.app.quit())
        signal.signal(signal.SIGINT, lambda *_: self.app.quit())

        self.app = QApplication(sys.argv[:1])
        # Set window icon from SVG file in data directory
        icon_path = Path(__file__).resolve().parents[2] / "data" / "org.sonicTune.svg"
        if icon_path.exists():
            try:
                renderer = QSvgRenderer(str(icon_path))
                pixmap = QPixmap(64, 64)
                pixmap.fill(0)
                painter = QPainter(pixmap)
                renderer.render(painter)
                painter.end()
                self.app.setWindowIcon(QIcon(pixmap))
            except Exception:
                self.app.setWindowIcon(QIcon(str(icon_path)))
        else:
            log.warning("app.icon_not_found", path=str(icon_path))
        self.app.setApplicationName("SonicTune")
        self.app.setApplicationDisplayName("SonicTune")
        self.app.setApplicationVersion(__version__)
        self.app.setOrganizationName("SonicTune")
        self.app.setDesktopFileName("org.sonicTune")
        self.app.setQuitOnLastWindowClosed(False)  # minimize to tray instead

        self._shutdown_task: asyncio.Task | None = None
        self._shutdown_started = False
        self._lastfm_scrobbled = False
        self._lastfm_start_time: int | None = None
        self.app.aboutToQuit.connect(self._on_about_to_quit)

        # qasync event loop
        self.loop = qasync.QEventLoop(self.app)
        asyncio.set_event_loop(self.loop)

        # Register bundled fonts
        self._register_fonts()

        QQuickStyle.setStyle("Material")

        # Services (initialized in async _init_services)
        self.db: Database | None = None
        self.oauth: OAuthManager | None = None
        self.library: YTMusicLibrary | None = None
        self.player: MpvPlayer | None = None
        self.queue = QueueManager()
        self.art_cache: ArtCache | None = None
        self.audio_cache: AudioCache | None = None
        self.lyrics: LrclibClient | None = None
        self.stats: StatsAggregator | None = None
        self.mpris: MprisServer | None = None
        self.discord: DiscordRPC | None = None
        self.lastfm: LastFmScrobbler | None = None
        self.sleep_timer: SleepTimer | None = None
        self.sponsorblock: SponsorBlock | None = None
        self.color_extractor: MaterialYouExtractor | None = None
        self.sync: LibrarySync | None = None

        # QML-facing proxy
        self.daemon: DaemonProxy | None = None

        # Phase 2 services (lazy-init via wiring)
        self._perf_profile: Any = None
        self._perf_flags: Any = None
        self._mini_player: Any = None

    def _set_locale(self) -> None:
        """CRITICAL: libmpv requires C locale. Set via ctypes at C level."""
        try:
            import ctypes
            libc = ctypes.CDLL("libc.so.6")
            libc.setlocale(0, b"C")  # LC_ALL = 0
        except OSError:
            pass
        locale.setlocale(locale.LC_ALL, "C")

    def _register_fonts(self) -> None:
        """Register bundled fonts so QML can use them."""
        try:
            from PySide6.QtGui import QFontDatabase
            font_dir = Path(__file__).resolve().parents[2] / "data" / "fonts"
            for font_file in font_dir.glob("*.ttf"):
                QFontDatabase.addApplicationFont(str(font_file))
            log.info("fonts.registered", count=len(list(font_dir.glob("*.ttf"))))
        except Exception as e:
            log.warning("fonts.register_failed", error=str(e))

    def _configure_logging(self) -> None:
        level = "DEBUG" if self.verbose else self.config.log_level
        structlog.configure(
            processors=[
                structlog.processors.add_log_level,
                structlog.processors.TimeStamper(fmt="iso"),
                structlog.dev.ConsoleRenderer(colors=sys.stderr.isatty()),
            ],
            wrapper_class=structlog.make_filtering_bound_logger(
                getattr(logging, level.upper(), logging.INFO)
            ),
        )

    def _on_about_to_quit(self) -> None:
        """Qt is about to tear down the event loop (tray Quit, SIGTERM/SIGINT
        via the handlers above, or the last window closing).

        ``aboutToQuit`` is synchronous and fires before ``exec()`` returns, so
        we can't await shutdown() directly. Schedule it on the still-running
        loop instead; ``main()`` drains it after ``run_forever()`` returns.
        """
        if self._shutdown_started or self._shutdown_task is not None or not self.loop.is_running():
            return
        self._shutdown_task = self.loop.create_task(self.shutdown())

    async def _init_services(self) -> None:
        """Initialize all services. Called once on startup."""
        log.info("app.starting", version=__version__)

        self.db = Database(self.config.db_path)
        await self.db.init()

        self.oauth = OAuthManager(self.config.oauth_path)
        await self.oauth.init()

        self.library = YTMusicLibrary(oauth=self.oauth, cookies_path=self.config.cookies_path)
        await self.library.init()

        # Player (MpvPlayer or NullPlayer). get_player_class() catches both
        # OSError (libmpv shared library missing) and ImportError (the mpv
        # pip package itself missing) and falls back to NullPlayer.
        PlayerClass = get_player_class()
        if PlayerClass.__name__ == "NullPlayer":
            log.warning("app.mpv_unavailable")
        self.player = PlayerClass(self.config.audio)
        await self.player.init()
        self._history_reported: bool = False
        self._wire_history_reporting()

        self.art_cache = ArtCache(self.config.cache.art_dir, max_size_mb=self.config.cache.art_size_mb)
        self.audio_cache = AudioCache(self.config.cache.audio_dir, max_size_mb=self.config.cache.audio_size_mb)
        self.lyrics = LrclibClient()
        self.stats = StatsAggregator(self.db)
        self.sync = LibrarySync(self.library, self.db, self.oauth)

        # MPRIS (external D-Bus — for desktop integration)
        if self.config.mpris.enabled:
            try:
                self.mpris = MprisServer(
                    player=self.player,
                    queue=self.queue,
                    library=self.library,
                    config=self.config,
                )
                await self.mpris.register()
            except Exception as e:
                log.warning("app.mpris_failed", error=str(e))
                self.mpris = None

        # Discord RPC (optional)
        if self.config.discord.enabled and self.config.discord.client_id:
            self.discord = DiscordRPC(client_id=self.config.discord.client_id)
            await self.discord.connect()
            self._wire_discord()

        # Last.fm scrobbling (optional)
        if self.config.lastfm.enabled and self.config.lastfm.api_key and self.config.lastfm.api_secret:
            self.lastfm = LastFmScrobbler(
                api_key=self.config.lastfm.api_key,
                api_secret=self.config.lastfm.api_secret,
                session_key=self.config.lastfm.session_key,
            )
            self._wire_lastfm()

        # Sleep timer
        self.sleep_timer = SleepTimer(self.player)
        self._wire_sleep_timer()

        # SponsorBlock (optional)
        if self.config.sponsorblock.enabled:
            self.sponsorblock = SponsorBlock(
                enabled=self.config.sponsorblock.enabled,
                categories=self.config.sponsorblock.categories,
            )
            self._wire_sponsorblock()

        # Color extractor for Material You theming
        if self.config.ui.dynamic_theme_enabled:
            self.color_extractor = MaterialYouExtractor()
            self._wire_color_extractor()

        # Create the QML-facing proxy
        self.daemon = DaemonProxy(
            player=self.player,
            queue=self.queue,
            library=self.library,
            oauth=self.oauth,
            lyrics=self.lyrics,
            stats=self.stats,
            art_cache=self.art_cache,
            audio_cache=self.audio_cache,
            db=self.db,
            sync=self.sync,
            config=self.config,
            sleep_timer=self.sleep_timer,
            sponsorblock=self.sponsorblock,
            color_extractor=self.color_extractor,
        )

        log.info("app.ready")

    def _wire_discord(self) -> None:
        """Wire DiscordRPC to player events."""
        if not self.discord or not self.player:
            return
        from sonictune.player.types import PlayerEvent

        def _on_event(event: object, data: dict) -> None:
            if event == PlayerEvent.TRACK_CHANGED:
                track = data.get("track")
                if track:
                    asyncio.create_task(
                        self.discord.update(
                            title=track.title,
                            artist=track.artist,
                            album=getattr(track, "album", None),
                            thumbnail_url=getattr(track, "thumbnail_url", None),
                            duration_ms=getattr(track, "duration_ms", None),
                        )
                    )
            elif event == PlayerEvent.STATE_CHANGED:
                asyncio.create_task(
                    self.discord.update(
                        title=self.player.current_track.title,
                        artist=self.player.current_track.artist,
                        paused=(data.get("state") != "playing"),
                    )
                )

        self.player.add_listener(_on_event)
        log.info("discord.wired")

    def _wire_lastfm(self) -> None:
        """Wire Last.fm scrobbling to player events."""
        if not self.lastfm or not self.player:
            return
        from sonictune.player.types import PlayerEvent

        def _on_event(event: object, data: dict) -> None:
            if event == PlayerEvent.TRACK_CHANGED:
                # Reset scrobble state for new track
                self._lastfm_scrobbled = False
                self._lastfm_start_time = None

                # Send "Now Playing" to Last.fm
                track = data.get("track")
                if track and self.player.current_track.duration_ms > 30000:  # Only tracks > 30s
                    asyncio.create_task(
                        self.lastfm.now_playing(
                            artist=track.artist,
                            title=track.title,
                            album=getattr(track, "album", ""),
                            duration=track.duration_ms // 1000,
                        )
                    )
            elif event == PlayerEvent.STATE_CHANGED:
                if data.get("state") == "playing" and not self._lastfm_start_time:
                    self._lastfm_start_time = int(time.time())
            elif event == PlayerEvent.POSITION_CHANGED:
                if (self._lastfm_start_time and not self._lastfm_scrobbled and
                    self.player.current_track.duration_ms > 30000):
                    # Scrobble after 50% or 4 minutes, whichever comes first
                    threshold = min(
                        self.player.current_track.duration_ms * 0.5,
                        240000  # 4 minutes
                    )
                    if data.get("position_ms", 0) >= threshold:
                        asyncio.create_task(
                            self.lastfm.scrobble(
                                artist=self.player.current_track.artist,
                                title=self.player.current_track.title,
                                timestamp=self._lastfm_start_time,
                                album=getattr(self.player.current_track, "album", ""),
                                duration=self.player.current_track.duration_ms // 1000,
                            )
                        )
                        self._lastfm_scrobbled = True
            elif event == PlayerEvent.END_REACHED:
                if (self._lastfm_start_time and not self._lastfm_scrobbled and
                    self.player.current_track.duration_ms > 30000):
                    asyncio.create_task(
                        self.lastfm.scrobble(
                            artist=self.player.current_track.artist,
                            title=self.player.current_track.title,
                            timestamp=self._lastfm_start_time,
                            album=getattr(self.player.current_track, "album", ""),
                            duration=self.player.current_track.duration_ms // 1000,
                        )
                    )
                    self._lastfm_scrobbled = True

        self.player.add_listener(_on_event)
        log.info("lastfm.wired")

    def _wire_sleep_timer(self) -> None:
        """Wire sleep timer to player events."""
        if not self.sleep_timer or not self.player:
            return
        from sonictune.player.types import PlayerEvent

        def _on_event(event: object, data: dict) -> None:
            if event == PlayerEvent.END_REACHED:
                asyncio.create_task(self.sleep_timer.on_track_ended())

        self.player.add_listener(_on_event)
        log.info("sleep_timer.wired")

    def _wire_sponsorblock(self) -> None:
        """Wire SponsorBlock skipping to player events."""
        if not self.sponsorblock or not self.player:
            return
        from sonictune.player.types import PlayerEvent

        def _on_event(event: object, data: dict) -> None:
            if event == PlayerEvent.TRACK_CHANGED:
                # Fetch segments for the new track
                track = data.get("track")
                if track and track.video_id:
                    asyncio.create_task(self._fetch_sponsorblock_segments(track.video_id))
            elif event == PlayerEvent.POSITION_CHANGED:
                # Check if we should skip a segment
                position_ms = data.get("position_ms", 0)
                skip_to_ms = self.sponsorblock.should_skip(
                    self.player.current_track.video_id, position_ms
                )
                if skip_to_ms:
                    asyncio.create_task(self.player.seek(skip_to_ms))
                    log.info("sponsorblock.skipped", position=position_ms, skip_to=skip_to_ms)

        self.player.add_listener(_on_event)
        log.info("sponsorblock.wired")

    async def _fetch_sponsorblock_segments(self, video_id: str) -> None:
        """Fetch SponsorBlock segments for a video."""
        if not self.sponsorblock:
            return
        segments = await self.sponsorblock.get_segments(video_id)
        if segments:
            log.info("sponsorblock.segments_fetched", video_id=video_id, count=len(segments))

    def _wire_color_extractor(self) -> None:
        """Wire Material You color extraction to art loading."""
        if not self.color_extractor or not self.art_cache:
            return

        # Monkey patch ArtCache.get_path to extract colors after art is loaded
        original_get_path = self.art_cache.get_path

        async def patched_get_path(url: str) -> Path | None:
            path = await original_get_path(url)
            if path and path.exists():
                try:
                    palette = await self.color_extractor.extract_palette(path)
                    if palette and self.daemon:
                        self.daemon.dynamicPaletteChanged.emit(_palette_to_qml_dict(palette))
                except Exception as e:
                    log.warning("color_extractor.failed", error=str(e))
            return path

        self.art_cache.get_path = patched_get_path
        log.info("color_extractor.wired")

    def _wire_history_reporting(self) -> None:
        """Report plays back to YouTube Music (for YTM Recap/history).

        A play is reported once per track, when the user has listened to
        50% of the track OR 30 seconds — whichever comes first. If the track
        ends before the threshold, it is reported on END_REACHED instead.
        """
        if not self.player or not self.library:
            return

        def _on_event(event: object, data: dict) -> None:
            asyncio.create_task(self._on_player_event(event, data))

        self.player.add_listener(_on_event)
        log.info("history.wired", enabled=self.config.ui.report_history)

    async def _on_player_event(self, event: object, data: dict) -> None:
        """Handle player events for YouTube Music history reporting."""
        from sonictune.player.types import PlayerEvent

        if event == PlayerEvent.TRACK_CHANGED:
            self._history_reported = False
        elif event == PlayerEvent.POSITION_CHANGED:
            if self._history_reported or not self.config.ui.report_history:
                return
            track = self.player.current_track
            if not track or not track.video_id:
                return
            pos = int(data.get("position_ms", 0))
            dur = int(data.get("duration_ms", 0))
            threshold = min(30000, dur * 0.5) if dur > 0 else 30000
            if pos >= threshold:
                await self._report_history(track.video_id)
        elif event == PlayerEvent.END_REACHED:
            track = data.get("track")
            if not track:
                track = self.player.current_track
            if (
                track
                and track.video_id
                and not self._history_reported
                and self.config.ui.report_history
            ):
                await self._report_history(track.video_id)

    async def _report_history(self, video_id: str) -> None:
        """Report a play to YT Music; guard against double-reporting."""
        if self._history_reported or not self.library:
            return
        ok = await self.library.add_to_history(video_id)
        if ok:
            self._history_reported = True

    def _setup_qml(self) -> None:
        """Set up QML engine and context properties."""
        engine = QQmlApplicationEngine()
        engine.addImportPath(str(Path(__file__).parent / "ui" / "qml"))

        # Register image provider
        engine.addImageProvider("art", ArtImageProvider(self.art_cache))

        # Performance flags (auto-detected, overridable from Settings)
        from sonictune.performance import detect_performance_tier
        self._perf_profile = detect_performance_tier()
        from sonictune.ui.performance_flags import PerformanceFlags
        self._perf_flags = PerformanceFlags(self._perf_profile)

        # Register context properties
        engine.rootContext().setContextProperty("Daemon", self.daemon)
        engine.rootContext().setContextProperty("Clipboard", ClipboardHelper())
        engine.rootContext().setContextProperty("AppVersion", __version__)
        engine.rootContext().setContextProperty("PerformanceFlags", self._perf_flags)

        # Load main.qml
        main_qml = Path(__file__).parent / "ui" / "qml" / "main.qml"
        engine.load(QUrl.fromLocalFile(str(main_qml)))

        if not engine.rootObjects():
            log.error("app.qml_load_failed", path=str(main_qml))
            sys.exit(1)

        log.info("app.qml_ready")
        self._engine = engine

        # Mini player
        from sonictune.ui.mini_player import MiniPlayerWindow
        self._mini_player = MiniPlayerWindow(self._engine, self.daemon)
        # Connect the QML signal to the Python mini-player toggle
        root = self._engine.rootObjects()[0]
        root.miniPlayerToggleRequested.connect(self._mini_player.toggle)

    def _setup_tray(self) -> None:
        """Set up system tray icon for minimize-to-tray."""
        from sonictune.ui.tray import TrayIcon
        self._tray = TrayIcon(self.app, self._engine.rootObjects()[0])
        self._tray.show()

    async def run(self) -> int:
        """Run the application."""
        await self._init_services()
        self._setup_qml()
        self._setup_tray()
        return 0

    async def shutdown(self) -> None:
        """Clean shutdown."""
        if self._shutdown_started:
            return
        self._shutdown_started = True
        log.info("app.stopping")
        if self.discord:
            await self.discord.close()
        if self.mpris:
            await self.mpris.unregister()
        if self.player:
            await self.player.shutdown()
        if self.library:
            await self.library.close()
        if self.db:
            await self.db.close()
        log.info("app.stopped")


def main(argv: list[str] | None = None) -> int:
    import argparse
    parser = argparse.ArgumentParser(prog="sonictune")
    parser.add_argument("--config", type=Path, default=None)
    parser.add_argument("--verbose", "-v", action="store_true")
    parser.add_argument("--no-mpris", action="store_true")
    parser.add_argument("--no-discord", action="store_true")
    parser.add_argument("--version", action="version", version=f"sonictune {__version__}")
    args = parser.parse_args(argv)

    config = load_config(args.config)
    if args.no_mpris:
        config.mpris.enabled = False
    if args.no_discord:
        config.discord.enabled = False

    app = SonicTuneApp(config, verbose=args.verbose)

    try:
        # Drive the qasync loop: it pumps the asyncio tasks AND the Qt event
        # loop from the same thread. Without this, `app.exec()` would block
        # the thread while the asyncio loop never runs, so every async proxy
        # call (home feed, search, playback) would hang forever.
        app.loop.create_task(app.run())
        try:
            result = app.loop.run_forever()
        finally:
            # aboutToQuit scheduled shutdown() on the loop but the loop has
            # stopped by now — pump it to completion so the DB is closed
            # cleanly, MPRIS unregistered, mpv terminated and the Discord
            # socket released before the process exits.
            if app._shutdown_task is not None and not app._shutdown_task.done():
                app.loop.run_until_complete(app._shutdown_task)
        return 0
    except KeyboardInterrupt:
        return 130
    except Exception:
        structlog.get_logger("app").exception("fatal")
        return 1


if __name__ == "__main__":
    sys.exit(main())
