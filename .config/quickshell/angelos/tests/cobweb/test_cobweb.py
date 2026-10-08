#!/usr/bin/env python3
"""The cobwebs' pure parts (services/CobwebWeb.js, CobwebLayout.js) in node: tests/cobweb/test_web.mjs.
Exit 77 without node (the CI image has none): skipped there."""
import pathlib
import shutil
import subprocess
import sys

node = shutil.which("node")
if not node:
    print("no node: the cobweb's JS tests can't run here")
    sys.exit(77)
sys.exit(subprocess.run([node, str(pathlib.Path(__file__).with_name("test_web.mjs"))]).returncode)
