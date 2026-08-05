"""Local audio library scanner using mutagen for metadata extraction."""

import asyncio
import colorsys
import contextlib
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any, ClassVar

import structlog
from mutagen import File as MutagenFile
from mutagen.easyid3 import EasyID3
from mutagen.flac import FLAC
from mutagen.id3 import ID3NoHeaderError
from mutagen.mp3 import MP3
from mutagen.mp4 import MP4, MP4Cover
from mutagen.oggopus import OggOpus
from mutagen.oggvorbis import OggVorbis
from PIL import Image

log = structlog.get_logger()

logger = logging.getLogger(__name__)


@dataclass
class MaterialPalette:
    """Material You color palette extracted from an image."""
    primary: str
    fg_primary: str
    primary_container: str
    fg_primary_container: str
    secondary: str
    fg_secondary: str
    secondary_container: str
    fg_secondary_container: str
    tertiary: str
    fg_tertiary: str
    tertiary_container: str
    fg_tertiary_container: str
    surface: str
    fg_surface: str
    surface_variant: str
    fg_surface_variant: str
    background: str
    fg_background: str
    outline: str
    outline_variant: str
    shadow: str
    scrim: str
    error: str
    fg_error: str
    error_container: str
    fg_error_container: str


class LocalScanner:
    """Scans local directories for audio files and extracts metadata using mutagen."""

    SUPPORTED_EXTENSIONS: ClassVar[set[str]] = {
        '.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.opus', '.wma'
    }

    def __init__(self, cache_dir: Path | None = None):
        self.cache_dir = cache_dir or Path.home() / '.cache/sonictune'
        self.cache_dir.mkdir(parents=True, exist_ok=True)

    async def scan_directory(self, root_path: str | Path) -> list[dict[str, Any]]:
        """Scan a directory for audio files and extract metadata."""
        root = Path(root_path)
        if not root.exists() or not root.is_dir():
            log.warning("local_scan_invalid_path", path=str(root_path))
            return []

        try:
            # Find all supported audio files
            files = await self._find_audio_files(root)
            log.info("local_scan_found_files", count=len(files), root=str(root_path))

            # Extract metadata from files
            tracks = []
            for file_path in files:
                try:
                    metadata = await self._extract_metadata(file_path)
                    if metadata:
                        tracks.append(metadata)
                except Exception as e:
                    log.warning(
                        "local_scan_metadata_failed",
                        path=str(file_path),
                        error=str(e)
                    )

            return tracks

        except Exception as e:
            log.error("local_scan_failed", error=str(e), root=str(root_path))
            return []

    async def _find_audio_files(self, root: Path) -> list[Path]:
        """Find all audio files in directory tree."""
        def _find():
            files = []
            for ext in self.SUPPORTED_EXTENSIONS:
                files.extend(root.rglob(f'*{ext}'))
            return files

        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, _find)

    async def _extract_metadata(self, file_path: Path) -> dict[str, Any] | None:
        """Extract metadata from an audio file using mutagen."""
        def _extract():
            try:
                audio = MutagenFile(file_path, easy=True)
                if not audio:
                    audio = MutagenFile(file_path)
                if not audio:
                    return None

                metadata = {
                    'id': f"local_{file_path.stem}",
                    'path': str(file_path),
                    'uri': file_path.as_uri(),
                    'is_local': True,
                    'title': file_path.stem,
                    'artist': 'Unknown Artist',
                    'album': 'Unknown Album',
                    'duration_ms': 0,
                    'track_number': 0,
                    'disc_number': 0,
                    'genre': '',
                    'year': 0,
                    'bitrate': 0,
                    'sample_rate': 0,
                    'channels': 0,
                    'file_size': file_path.stat().st_size,
                    'file_extension': file_path.suffix.lower(),
                    'last_modified': file_path.stat().st_mtime,
                }

                # Extract duration
                if hasattr(audio.info, 'length'):
                    metadata['duration_ms'] = int(audio.info.length * 1000)

                # Extract bitrate, sample rate, channels
                if hasattr(audio.info, 'bitrate'):
                    metadata['bitrate'] = audio.info.bitrate
                if hasattr(audio.info, 'sample_rate'):
                    metadata['sample_rate'] = audio.info.sample_rate
                if hasattr(audio.info, 'channels'):
                    metadata['channels'] = audio.info.channels

                # Format-specific metadata extraction
                if file_path.suffix.lower() == '.mp3':
                    self._extract_mp3_metadata(audio, metadata, file_path)
                elif file_path.suffix.lower() in ('.flac', '.ogg', '.opus'):
                    self._extract_flac_vorbis_metadata(audio, metadata)
                elif file_path.suffix.lower() in ('.m4a', '.aac'):
                    self._extract_mp4_metadata(audio, metadata)

                return metadata

            except ID3NoHeaderError:
                # Try again without easy=True
                try:
                    audio = MP3(file_path)
                    return self._extract_mp3_metadata(audio, {
                        'id': f"local_{file_path.stem}",
                        'path': str(file_path),
                        'uri': file_path.as_uri(),
                        'is_local': True,
                        'title': file_path.stem,
                        'artist': 'Unknown Artist',
                        'album': 'Unknown Album',
                        'duration_ms': int(audio.info.length * 1000) if hasattr(audio.info, 'length') else 0,
                        'track_number': 0,
                        'disc_number': 0,
                        'genre': '',
                        'year': 0,
                        'bitrate': audio.info.bitrate if hasattr(audio.info, 'bitrate') else 0,
                        'sample_rate': audio.info.sample_rate if hasattr(audio.info, 'sample_rate') else 0,
                        'channels': audio.info.channels if hasattr(audio.info, 'channels') else 0,
                        'file_size': file_path.stat().st_size,
                        'file_extension': file_path.suffix.lower(),
                        'last_modified': file_path.stat().st_mtime,
                    }, file_path)
                except Exception as e:
                    log.warning("local_scan_mp3_fallback_failed", path=str(file_path), error=str(e))
                    return None
            except Exception as e:
                log.warning("local_scan_extract_failed", path=str(file_path), error=str(e))
                return None

        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, _extract)

    def _extract_mp3_metadata(self, audio: MP3, metadata: dict[str, Any], file_path: str | Path):
        """Extract metadata from MP3 files."""
        try:
            tags = audio if isinstance(audio, EasyID3) else EasyID3(file_path)

            if 'title' in tags:
                metadata['title'] = tags['title'][0]
            if 'artist' in tags:
                metadata['artist'] = tags['artist'][0]
            if 'album' in tags:
                metadata['album'] = tags['album'][0]
            if 'tracknumber' in tags:
                try:
                    track_num = tags['tracknumber'][0].split('/')[0]
                    metadata['track_number'] = int(track_num)
                except (ValueError, IndexError):
                    pass
            if 'discnumber' in tags:
                try:
                    disc_num = tags['discnumber'][0].split('/')[0]
                    metadata['disc_number'] = int(disc_num)
                except (ValueError, IndexError):
                    pass
            if 'genre' in tags:
                metadata['genre'] = tags['genre'][0]
            if 'date' in tags:
                with contextlib.suppress(ValueError, IndexError):
                    metadata['year'] = int(tags['date'][0][:4])

        except Exception as e:
            log.warning("local_scan_mp3_tags_failed", error=str(e))

    def _extract_flac_vorbis_metadata(self, audio: FLAC | OggVorbis | OggOpus, metadata: dict[str, Any]):
        """Extract metadata from FLAC, Ogg Vorbis, and Ogg Opus files."""
        if 'title' in audio:
            metadata['title'] = audio['title'][0]
        if 'artist' in audio:
            metadata['artist'] = audio['artist'][0]
        if 'album' in audio:
            metadata['album'] = audio['album'][0]
        if 'tracknumber' in audio:
            try:
                track_num = audio['tracknumber'][0].split('/')[0]
                metadata['track_number'] = int(track_num)
            except (ValueError, IndexError):
                pass
        if 'discnumber' in audio:
            try:
                disc_num = audio['discnumber'][0].split('/')[0]
                metadata['disc_number'] = int(disc_num)
            except (ValueError, IndexError):
                pass
        if 'genre' in audio:
            metadata['genre'] = audio['genre'][0]
        if 'date' in audio:
            with contextlib.suppress(ValueError, IndexError):
                metadata['year'] = int(audio['date'][0][:4])

    def _extract_mp4_metadata(self, audio: MP4, metadata: dict[str, Any]):
        """Extract metadata from MP4/AAC files."""
        if 'a9nam' in audio:
            metadata['title'] = audio['a9nam'][0]
        if 'a9ART' in audio:
            metadata['artist'] = audio['a9ART'][0]
        if 'a9alb' in audio:
            metadata['album'] = audio['a9alb'][0]
        if 'trkn' in audio:
            try:
                track_num = audio['trkn'][0][0]
                metadata['track_number'] = int(track_num)
            except (ValueError, IndexError):
                pass
        if 'disk' in audio:
            try:
                disc_num = audio['disk'][0][0]
                metadata['disc_number'] = int(disc_num)
            except (ValueError, IndexError):
                pass
        if 'a9gen' in audio:
            metadata['genre'] = audio['a9gen'][0]
        if 'a9day' in audio:
            with contextlib.suppress(ValueError, IndexError):
                metadata['year'] = int(audio['a9day'][0][:4])

    async def get_album_art(self, file_path: str | Path) -> bytes | None:
        """Extract album art from audio file."""
        def _extract():
            try:
                path = Path(file_path)
                audio = MutagenFile(path)
                if not audio:
                    return None

                if path.suffix.lower() == '.mp3':
                    return self._extract_mp3_album_art(audio)
                elif path.suffix.lower() in ('.flac', '.ogg', '.opus'):
                    return self._extract_flac_vorbis_album_art(audio)
                elif path.suffix.lower() in ('.m4a', '.aac'):
                    return self._extract_mp4_album_art(audio)

                return None

            except Exception as e:
                log.warning("local_scan_album_art_failed", path=str(file_path), error=str(e))
                return None

        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, _extract)

    def _extract_mp3_album_art(self, audio: MP3) -> bytes | None:
        """Extract album art from MP3 files."""
        if 'APIC:' in audio.tags:
            for tag in audio.tags.getall('APIC:'):
                if tag.type == 3:  # Front cover
                    return tag.data
        return None

    def _extract_flac_vorbis_album_art(self, audio: FLAC | OggVorbis | OggOpus) -> bytes | None:
        """Extract album art from FLAC/Ogg files."""
        if isinstance(audio, FLAC) and audio.pictures:
            for picture in audio.pictures:
                if picture.type == 3:  # Front cover
                    return picture.data
        return None

    def _extract_mp4_album_art(self, audio: MP4) -> bytes | None:
        """Extract album art from MP4/AAC files."""
        if 'covr' in audio:
            cover_data = audio['covr'][0]
            if isinstance(cover_data, (bytes, MP4Cover)):
                return cover_data
        return None

    @staticmethod
    def _rgb_to_hex(r: int, g: int, b: int) -> str:
        return f"#{r:02x}{g:02x}{b:02x}"

    @staticmethod
    def _hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
        hex_color = hex_color.lstrip("#")
        return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

    @staticmethod
    def _adjust_lightness(r: int, g: int, b: int, factor: float) -> tuple[int, int, int]:
        """Adjust lightness in HSL space."""
        h, lightness, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
        lightness = max(0.0, min(1.0, lightness * factor))
        r, g, b = colorsys.hls_to_rgb(h, lightness, s)
        return (int(r * 255), int(g * 255), int(b * 255))

    @staticmethod
    def _generate_tonal_palette(base_rgb: tuple[int, int, int]) -> dict[int, str]:
        """Generate Material 3 tonal palette (0-100 tones)."""
        r, g, b = base_rgb
        h, _lightness, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)

        tones = {}
        for tone in range(0, 101, 10):
            target_l = tone / 100.0
            new_r, new_g, new_b = colorsys.hls_to_rgb(h, target_l, s)
            tones[tone] = LocalScanner._rgb_to_hex(
                int(new_r * 255), int(new_g * 255), int(new_b * 255)
            )
        return tones

    @classmethod
    async def extract_palette(cls, image_path: str | Path) -> MaterialPalette:
        """Extract Material You palette from an image file."""
        try:
            loop = asyncio.get_running_loop()
            img = await loop.run_in_executor(
                None, cls._process_image, str(image_path)
            )

            if not img:
                return cls._fallback_palette()

            dominant = cls._get_dominant_color(img)
            return cls._build_palette(dominant)

        except Exception as e:
            log.error("color_extract_failed", error=str(e), path=str(image_path))
            return cls._fallback_palette()

    @staticmethod
    def _process_image(image_path: str) -> Any:
        """Process image to extract colors (runs in executor)."""
        try:
            from PIL import Image
            with Image.open(image_path) as img:
                img = img.convert("RGB")
                img.thumbnail((100, 100), Image.LANCZOS)
                return img
        except Exception:
            return None

    @staticmethod
    def _get_dominant_color(img: Any) -> tuple[int, int, int]:
        """Get dominant color using simple quantization."""
        img_small = img.resize((20, 20), Image.LANCZOS)
        colors = img_small.getcolors(400)
        if not colors:
            return (103, 80, 164)

        colors.sort(key=lambda x: x[0], reverse=True)
        for _, color in colors:
            r, g, b = color
            if not (r > 240 and g > 240 and b > 240) and not (r < 20 and g < 20 and b < 20):
                return color
        return colors[0][1]

    @classmethod
    def _build_palette(cls, primary_rgb: tuple[int, int, int]) -> MaterialPalette:
        """Build full Material 3 palette from primary color."""
        primary_tones = cls._generate_tonal_palette(primary_rgb)
        secondary_tones = cls._generate_tonal_palette(
            cls._adjust_lightness(*primary_rgb, 1.2)
        )
        tertiary_tones = cls._generate_tonal_palette(
            cls._adjust_lightness(*primary_rgb, 0.8)
        )

        neutral_tones = cls._generate_tonal_palette((28, 27, 31))
        neutral_variant_tones = cls._generate_tonal_palette((73, 69, 79))
        error_tones = cls._generate_tonal_palette((242, 184, 181))

        return MaterialPalette(
            primary=primary_tones[40],
            fg_primary=primary_tones[100],
            primary_container=primary_tones[90],
            fg_primary_container=primary_tones[10],
            secondary=secondary_tones[40],
            fg_secondary=secondary_tones[100],
            secondary_container=secondary_tones[90],
            fg_secondary_container=secondary_tones[10],
            tertiary=tertiary_tones[40],
            fg_tertiary=tertiary_tones[100],
            tertiary_container=tertiary_tones[90],
            fg_tertiary_container=tertiary_tones[10],
            surface=neutral_tones[10],
            fg_surface=neutral_tones[90],
            surface_variant=neutral_variant_tones[30],
            fg_surface_variant=neutral_variant_tones[80],
            background=neutral_tones[10],
            fg_background=neutral_tones[90],
            outline=neutral_variant_tones[50],
            outline_variant=neutral_variant_tones[30],
            shadow=cls._rgb_to_hex(0, 0, 0),
            scrim=cls._rgb_to_hex(0, 0, 0),
            error=error_tones[40],
            fg_error=error_tones[100],
            error_container=error_tones[90],
            fg_error_container=error_tones[10],
        )

    @classmethod
    def _fallback_palette(cls) -> MaterialPalette:
        """Return default Material 3 dark palette."""
        fallback_rgb = cls._hex_to_rgb("#6750A4")
        return cls._build_palette(fallback_rgb)


    @classmethod
    async def extract_palette_from_url(cls, image_url: str, cache_dir: Path) -> "MaterialPalette":
        """Download image from URL and extract palette."""
        try:
            import aiohttp

            cache_dir.mkdir(parents=True, exist_ok=True)

            filename = image_url.split("/")[-1].split("?")[0]
            if not filename or "." not in filename:
                filename = "album_art.jpg"
            cache_path = cache_dir / filename

            if not cache_path.exists():
                async with aiohttp.ClientSession() as session, session.get(image_url) as resp:
                    if resp.status == 200:
                        data = await resp.read()
                        cache_path.write_bytes(data)
                    else:
                        return cls._fallback_palette()

            return await cls.extract_palette(cache_path)
        except Exception as e:
            log.error("palette_from_url_failed", url=image_url, error=str(e))
            return cls._fallback_palette()
