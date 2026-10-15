#!/usr/bin/env python3
"""angelOS's own log history: the journal keeps ~50 MB here (a day or so), so "the logs of all
time" were gone when they were asked for (2026-10-15). Each finished day of the shell, niri
and the USB bridge is kept as one compressed file:

  ~/.local/state/angelos/logs/YYYY-MM-DD.log.zst   (.log.gz without zstd)

  log-archive.py [--days-back 3]     the finished days not kept yet (as far back as the journal
                                     still has them); quiet, idempotent, run by the shell daily
Files are only added; nothing is ever removed here.
"""
import argparse
import datetime
import gzip
import os
import shutil
import subprocess
from pathlib import Path

STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "angelos" / "logs"
UNITS = ["angelos.service", "niri.service", "mem-janitor.service"]


def day_log(day):
    since, until = day.isoformat() + " 00:00:00", (day + datetime.timedelta(days=1)).isoformat() + " 00:00:00"
    parts = []
    for args in (["--user"] + sum((["-u", u] for u in UNITS), []), ["-u", "angelos-usb-bridge.service"]):
        r = subprocess.run(["journalctl", "--no-pager", "-q", "-o", "short-iso", "--since", since, "--until", until] + args,
                           capture_output=True, text=True, timeout=120)
        if r.stdout.strip():
            parts.append(r.stdout)
    return "".join(parts)


def keep(day, text):
    STATE.mkdir(parents=True, exist_ok=True)
    if shutil.which("zstd"):
        dest = STATE / (day.isoformat() + ".log.zst")
        tmp = dest.with_suffix(".tmp")
        subprocess.run(["zstd", "-q", "-19", "-o", str(tmp), "-"], input=text.encode(), check=True)
    else:
        dest = STATE / (day.isoformat() + ".log.gz")
        tmp = dest.with_suffix(".tmp")
        with gzip.open(tmp, "wt") as f:
            f.write(text)
    os.replace(tmp, dest)
    return dest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days-back", type=int, default=3)
    a = ap.parse_args()
    today = datetime.date.today()
    for n in range(a.days_back, 0, -1):
        day = today - datetime.timedelta(days=n)
        if any((STATE / (day.isoformat() + ext)).exists() for ext in (".log.zst", ".log.gz")):
            continue
        text = day_log(day)
        if text:
            print(keep(day, text))


if __name__ == "__main__":
    main()
