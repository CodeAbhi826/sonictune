"""Backward-compatible import shim.

Phase 2 spec tests import ``from sonictune.daemon_proxy import DaemonProxy``;
the implementation lives in ``sonictune.ui.daemon_proxy``. This module
re-exports it so both import paths work.
"""
from __future__ import annotations

from sonictune.ui.daemon_proxy import DaemonProxy

__all__ = ["DaemonProxy"]
