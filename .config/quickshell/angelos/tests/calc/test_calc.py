#!/usr/bin/env python3
"""The launcher's currency and timer phrases (services/CalcCore.js, TimerCore.js) in node:
tests/calc/test_money.mjs, test_timers.mjs.
Exit 77 without node (the CI image has none): skipped there."""
import pathlib
import shutil
import subprocess
import sys

node = shutil.which("node")
if not node:
    print("no node: the calculator's JS tests can't run here")
    sys.exit(77)
here = pathlib.Path(__file__)
sys.exit(max(subprocess.run([node, str(here.with_name(t))]).returncode for t in ("test_money.mjs", "test_timers.mjs")))
