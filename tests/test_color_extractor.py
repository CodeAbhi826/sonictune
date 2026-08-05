"""Tests for the Material You color extractor."""

from unittest.mock import MagicMock, patch

import pytest
from PIL import Image

from sonictune.library.local_scanner import LocalScanner


@pytest.fixture
def create_test_image(tmp_path):
    """Create a test image with known colors."""
    img_path = tmp_path / "test_image.jpg"
    img = Image.new('RGB', (100, 100), color=(103, 80, 164))  # Default Material You primary
    img.save(img_path)
    return img_path


@pytest.mark.asyncio
async def test_extract_palette_from_image(create_test_image):
    """Test palette extraction from an image."""
    palette = await LocalScanner.extract_palette(create_test_image)

    # Check that we got a valid palette object
    assert hasattr(palette, 'primary')
    assert hasattr(palette, 'fg_primary')
    assert palette.primary.startswith('#')


@pytest.mark.asyncio
async def test_extract_palette_with_dominant_color(tmp_path):
    """Test palette extraction with a custom dominant color."""
    img_path = tmp_path / "test_image.jpg"
    img = Image.new('RGB', (100, 100), color=(200, 50, 50))  # Reddish color
    img.save(img_path)

    palette = await LocalScanner.extract_palette(img_path)

    # Should generate palette based on the red color
    assert hasattr(palette, 'primary')
    assert palette.primary.startswith('#')
    assert len(palette.primary) == 7  # Should be #RRGGBB format


@pytest.mark.asyncio
async def test_extract_palette_fallback():
    """Test that the extractor falls back to default palette on error."""
    with patch('sonictune.library.local_scanner.LocalScanner._process_image') as mock_process:
        mock_process.return_value = None

        palette = await LocalScanner.extract_palette("/nonexistent/path.jpg")

        # Should return a valid palette object
        assert hasattr(palette, 'primary')
        assert palette.primary.startswith('#')


@pytest.mark.asyncio
async def test_generate_tonal_palette():
    """Test tonal palette generation."""
    tones = LocalScanner._generate_tonal_palette((103, 80, 164))

    # Should have 11 tones (0-100 in steps of 10)
    assert len(tones) == 11
    for tone, color in tones.items():
        assert isinstance(tone, int)
        assert 0 <= tone <= 100
        assert isinstance(color, str)
        assert color.startswith('#')
        assert len(color) == 7


@pytest.mark.asyncio
async def test_adjust_lightness():
    """Test lightness adjustment in HSL space."""
    # Test darkening
    r, g, b = LocalScanner._adjust_lightness(100, 100, 100, 0.5)
    assert 0 <= r <= 255
    assert 0 <= g <= 255
    assert 0 <= b <= 255

    # Test lightening
    r, g, b = LocalScanner._adjust_lightness(50, 50, 50, 2.0)
    assert 0 <= r <= 255
    assert 0 <= g <= 255
    assert 0 <= b <= 255


@pytest.mark.asyncio
async def test_extract_palette_from_url(tmp_path):
    """Test palette extraction from a URL."""
    # Skip this test if aiohttp is not available
    pytest.importorskip("aiohttp")

    # Mock aiohttp to return test image data
    with patch('aiohttp.ClientSession') as mock_session:
        mock_resp = MagicMock()
        mock_resp.status = 200
        mock_resp.read.return_value = b"dummy image data"

        mock_session.return_value.__aenter__.return_value.get.return_value.__aenter__.return_value = mock_resp

        # Create a cache directory
        cache_dir = tmp_path / "cache"

        palette = await LocalScanner.extract_palette_from_url(
            "https://example.com/album_art.jpg",
            cache_dir
        )

        # Should return a valid palette object
        assert hasattr(palette, 'primary')
        assert palette.primary.startswith('#')
