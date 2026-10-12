#!/usr/bin/env python3
"""The keys on screen (scripts/key-cast.py): labels, typing only when asked, silence for passwords."""
import pathlib
import subprocess
import sys

sys.exit(subprocess.run([sys.executable, str(pathlib.Path(__file__).resolve().parents[2] / "scripts/key-cast.py"), "--self-test"]).returncode)
