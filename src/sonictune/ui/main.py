"""SonicTune UI entry point — thin wrapper around app.py."""
from __future__ import annotations

import sys

from sonictune.app import main

if __name__ == "__main__":
    sys.exit(main())
