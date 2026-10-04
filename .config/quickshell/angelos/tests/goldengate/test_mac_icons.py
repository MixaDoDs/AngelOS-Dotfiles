#!/usr/bin/env python3
"""The Golden Gate Dock's icons (scripts/mac-icons.py) — offline, on a made-up release archive,
in a throw-away XDG_DATA_HOME (nothing is downloaded, nothing of yours is touched):

  python3 tests/goldengate/test_mac_icons.py      exit 0 = all good

  build       the default variant put together as its install.sh does it: src/ folders, the
              status sizes it copies, links/ over them; nothing else of the archive (install.sh,
              cursors, the budgie icons)
  links       links inside the theme kept (also ../ ones); absolute ones and ones leading out
              of the theme dropped
  install     a download that fails its checksum installs nothing; a good one lands in
              angelos/icons/MacTahoe and status lists its apps and places
  remove      only the copy this script made goes
"""
import hashlib
import importlib.util
import io
import json
import os
import shutil
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
failures = []


def check(name, ok, detail=""):
    print("  %s %s %s" % ("✓" if ok else "✕", name, "" if ok else detail))
    if not ok:
        failures.append(name)


tmp = Path(tempfile.mkdtemp(prefix="aos-macicons."))
os.environ["XDG_DATA_HOME"] = str(tmp / "data")
spec = importlib.util.spec_from_file_location("mac_icons", ROOT / "scripts/mac-icons.py")
mi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mi)
mi.OTHERS = []          # a MacTahoe installed on this machine must not count


def archive():
    buf = io.BytesIO()
    top = "MacTahoe-icon-theme-test/"
    with tarfile.open(fileobj=buf, mode="w:gz") as t:
        def add(name, data=b"<svg/>", link=None, folder=False):
            info = tarfile.TarInfo(top + name)
            if folder:
                info.type = tarfile.DIRTYPE
                t.addfile(info)
            elif link is not None:
                info.type = tarfile.SYMTYPE
                info.linkname = link
                t.addfile(info)
            else:
                info.size = len(data)
                t.addfile(info, io.BytesIO(data))
        add("install.sh", b"#!/bin/sh\nrm -rf ~\n")
        add("COPYING", b"GPL-3.0")
        add("AUTHORS", b"Vince Liuice")
        add("src", folder=True)
        add("src/index.theme", b"[Icon Theme]\nName=MacTahoe\n")
        add("src/apps/scalable/firefox.svg")
        add("src/places/scalable/user-trash.svg")
        add("src/status/16/battery.svg")
        add("src/status/symbolic-budgie/budgie.svg")
        add("cursors/dist/cursor", b"x")
        add("links/apps/scalable/org.mozilla.firefox.svg", link="firefox.svg")
        add("links/places/scalable/trash-empty.svg", link="../../places/scalable/user-trash.svg")
        add("links/apps/scalable/passwd.svg", link="/etc/passwd")
        add("links/apps/scalable/out.svg", link="../../../../outside.svg")
        add("links/../escape.svg", b"x")
    return buf.getvalue()


try:
    data = archive()
    staging = tmp / "staging"
    staging.mkdir()
    mi.build(data, staging)
    files = sorted(str(p.relative_to(staging)) for p in staging.rglob("*") if not p.is_dir())
    check("build", files == [".angelos", "AUTHORS", "COPYING", "apps/scalable/firefox.svg",
                             "apps/scalable/org.mozilla.firefox.svg", "index.theme",
                             "places/scalable/trash-empty.svg", "places/scalable/user-trash.svg",
                             "status/16/battery.svg"], files)
    link = staging / "apps/scalable/org.mozilla.firefox.svg"
    up = staging / "places/scalable/trash-empty.svg"
    check("links", link.is_symlink() and link.read_bytes() == b"<svg/>" and up.is_symlink() and up.exists()
          and not (staging / "apps/scalable/passwd.svg").exists() and not (staging / "apps/scalable/out.svg").is_symlink()
          and not (tmp / "escape.svg").exists(), files)

    mi.fetch = lambda: (_ for _ in ()).throw(ValueError("Checksum mismatch"))
    bad = None
    try:
        mi.install()
    except ValueError as e:
        bad = str(e)
    ok_bad = bad == "Checksum mismatch" and not mi.OURS.exists() and not mi.status()["installed"]
    mi.SHA256 = hashlib.sha256(data).hexdigest()
    mi.fetch = lambda: data
    st = mi.install()
    check("install", ok_bad and st["installed"] and st["ours"] and st["dir"] == str(tmp / "data/angelos/icons/MacTahoe")
          and st["names"] == {"apps": ["firefox", "org.mozilla.firefox"], "places": ["trash-empty", "user-trash"]}
          and not list(mi.OURS.parent.glob(".install-*")), json.dumps(st))

    foreign = tmp / "foreign"
    foreign.mkdir()
    (foreign / "index.theme").write_text("x")
    mi.OURS.rename(tmp / "ours")
    foreign.rename(mi.OURS)                 # someone else's folder at our place: no marker
    mi.remove()
    kept = (mi.OURS / "index.theme").exists()
    shutil.rmtree(mi.OURS)
    (tmp / "ours").rename(mi.OURS)
    gone = mi.remove()
    check("remove", kept and not mi.OURS.exists() and gone["removed"] and not gone["installed"])
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print("mac-icons: %s" % ("all good" if not failures else "FAILED: " + ", ".join(failures)))
sys.exit(1 if failures else 0)
