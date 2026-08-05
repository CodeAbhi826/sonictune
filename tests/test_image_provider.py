# tests/test_image_provider.py
"""
Test ArtImageProvider's data URI parsing logic (without Qt dependencies).
"""

import base64
import io
from unittest.mock import MagicMock, patch

from PIL import Image

from sonictune.ui.imageprovider import ArtImageProvider


def test_parse_data_uri_png():
    """Test parsing a base64-encoded PNG data URI."""
    # Create a 1x1 red PNG
    img = Image.new("RGBA", (1, 1), (255, 0, 0, 255))
    buffered = io.BytesIO()
    img.save(buffered, format="PNG")
    img_base64 = base64.b64encode(buffered.getvalue()).decode("utf-8")
    data_uri = f"data:image/png;base64,{img_base64}"

    # Mock ArtImageProvider._load_data_uri (avoid Qt)
    with patch.object(ArtImageProvider, '_load_data_uri') as mock_load:
        mock_load.return_value = Image.new("RGBA", (1, 1), (255, 0, 0, 255))

        provider = ArtImageProvider(MagicMock())
        img = provider._load_data_uri(data_uri)

        # Verify the image was parsed
        assert img is not None
        assert img.size == (1, 1)


def test_parse_data_uri_svg():
    """Test parsing a base64-encoded SVG data URI."""
    # Simple SVG (1x1 red rectangle)
    svg_data = """
    <svg xmlns="http://www.w3.org/2000/svg" width="1" height="1">
        <rect width="1" height="1" fill="red" />
    </svg>
    """
    svg_base64 = base64.b64encode(svg_data.encode("utf-8")).decode("utf-8")
    data_uri = f"data:image/svg+xml;base64,{svg_base64}"

    # Mock ArtImageProvider._load_data_uri
    with patch.object(ArtImageProvider, '_load_data_uri') as mock_load:
        mock_load.return_value = Image.new("RGBA", (1, 1), (255, 0, 0, 255))

        provider = ArtImageProvider(MagicMock())
        img = provider._load_data_uri(data_uri)

        # Verify the image was parsed
        assert img is not None
        assert img.size == (1, 1)


def test_non_data_uri_returns_none():
    """Test that non-data URIs return None."""
    provider = ArtImageProvider(MagicMock())
    assert provider._load_data_uri("http://example.com/image.png") is None
