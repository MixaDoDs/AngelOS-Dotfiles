#!/usr/bin/env python3
"""Discord's call for the widget (scripts/discord-voice.py) against a stand-in Discord: the token,
its renewal, who is in the call, speaking, leaving; WebSocket frames. No network."""
import pathlib
import subprocess
import sys

sys.exit(subprocess.run([sys.executable, str(pathlib.Path(__file__).resolve().parents[2] / "scripts/discord-voice.py"), "--self-test"], timeout=60).returncode)
