"""Material 3 dark design tokens, mirrored from ``Theme.qml``.

This module exists so the Python test-suite can assert on the exact token
values that the QML singleton ships. The QML file is the source of truth at
runtime; these class attributes must stay in sync with it.
"""
from __future__ import annotations


class Theme:
    """Material 3 dark token values (mirror of ``Theme.qml``)."""

    # PERFORMANCE FLAGS
    reduced_motion: bool = False
    low_end_mode: bool = False
    disable_shadows: bool = False
    disable_image_cache: bool = False
    image_source_size: int = 512
    list_cache_buffer: int = 200
    smooth_scrolling: bool = True

    # MATERIAL 3 DARK SURFACES
    background = "#0F0F0F"
    fg_background = "#E6E1E5"
    surface = "#1C1B1F"
    surface_dim = "#141218"
    surface_bright = "#3B383E"
    surface_container_lowest = "#0F0D13"
    surface_container_low = "#1D1B20"
    surface_container = "#211F26"
    surface_container_high = "#2B2930"
    surface_container_highest = "#36343B"
    surface_variant = "#49454F"
    fg_surface = "#E6E1E5"
    fg_surface_variant = "#CAC4D0"

    # PRIMARY
    primary = "#D0BCFF"
    fg_primary = "#381E72"
    primary_container = "#4F378B"
    fg_primary_container = "#EADDFF"
    inverse_primary = "#6750A4"

    # SECONDARY
    secondary = "#CCC2DC"
    fg_secondary = "#332D41"
    secondary_container = "#4A4458"
    fg_secondary_container = "#E8DEF8"

    # TERTIARY
    tertiary = "#EFB8C8"
    fg_tertiary = "#492532"
    tertiary_container = "#633B48"
    fg_tertiary_container = "#FFD8E4"

    # ERROR
    error = "#F2B8B5"
    fg_error = "#601410"
    error_container = "#8C1D18"
    fg_error_container = "#F9DEDC"

    # OUTLINES
    outline = "#938F99"
    outline_variant = "#49454F"

    # PLAYER
    player_bar_bg = "#1C1B1F"
    player_bar_border = "#2B2930"
    player_progress = "#D0BCFF"
    player_progress_bg = "#49454F"

    # QML property names are camelCase; expose both spellings so tests can
    # assert on the QML-facing names (e.g. ``reducedMotion``) directly.
    reducedMotion = reduced_motion
    lowEndMode = low_end_mode
    fgSurface = fg_surface
    fgSurfaceVariant = fg_surface_variant
    fgSurfaceMuted = fg_surface_variant


__all__ = ["Theme"]
