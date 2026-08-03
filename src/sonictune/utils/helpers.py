"""Common utilities — time formatting, IDs, etc."""
from __future__ import annotations

import re


def format_duration(ms: int) -> str:
    """Format milliseconds as 'M:SS' or 'H:MM:SS'."""
    if ms <= 0:
        return "0:00"
    seconds = ms // 1000
    hours, remainder = divmod(seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    if hours > 0:
        return f"{hours}:{minutes:02d}:{seconds:02d}"
    return f"{minutes}:{seconds:02d}"


def parse_duration(text: str) -> int:
    """Parse 'M:SS' or 'H:MM:SS' to milliseconds."""
    parts = text.strip().split(":")
    try:
        nums = [int(p) for p in parts]
    except ValueError:
        return 0
    if len(nums) == 2:
        return (nums[0] * 60 + nums[1]) * 1000
    if len(nums) == 3:
        return (nums[0] * 3600 + nums[1] * 60 + nums[2]) * 1000
    return 0


_YT_VIDEO_ID_RE = re.compile(r"^[A-Za-z0-9_-]{11}$")


def is_valid_video_id(vid: str) -> bool:
    return bool(_YT_VIDEO_ID_RE.match(vid))


def humanize_bytes(n: int) -> str:
    """Format bytes as '1.2 MB', '342 KB', etc."""
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(n) < 1024:
            return f"{int(n)} B" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} PB"


def truncate(s: str, max_len: int, ellipsis: str = "…") -> str:
    if len(s) <= max_len:
        return s
    return s[: max_len - 1] + ellipsis


__all__ = [
    "format_duration",
    "humanize_bytes",
    "is_valid_video_id",
    "parse_duration",
    "truncate",
]
