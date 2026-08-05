"""Material You dynamic color extraction from album art."""

import asyncio
import colorsys
import logging
from dataclasses import dataclass
from pathlib import Path

import structlog
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


class MaterialYouExtractor:
    """Extracts Material You color palette from album artwork."""

    DEFAULT_PRIMARY = "#6750A4"
    DEFAULT_SURFACE = "#1C1B1F"
    DEFAULT_BACKGROUND = "#0F0F0F"

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
            tones[tone] = MaterialYouExtractor._rgb_to_hex(
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
    def _process_image(image_path: str) -> Image.Image | None:
        """Process image to extract colors (runs in executor)."""
        try:
            with Image.open(image_path) as img:
                img = img.convert("RGB")
                img.thumbnail((100, 100), Image.Resampling.LANCZOS)
                return img
        except Exception:
            return None

    @staticmethod
    def _get_dominant_color(img: Image.Image) -> tuple[int, int, int]:
        """Get dominant color using simple quantization."""
        img_small = img.resize((20, 20), Image.Resampling.LANCZOS)
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
            background=neutral_tones[4],
            fg_background=neutral_tones[95],
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
        fallback_rgb = cls._hex_to_rgb(cls.DEFAULT_PRIMARY)
        return cls._build_palette(fallback_rgb)


async def extract_palette_from_url(image_url: str, cache_dir: Path) -> MaterialPalette:
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
                    return MaterialYouExtractor._fallback_palette()

        return await MaterialYouExtractor.extract_palette(cache_path)
    except Exception as e:
        log.error("palette_from_url_failed", url=image_url, error=str(e))
        return MaterialYouExtractor._fallback_palette()
