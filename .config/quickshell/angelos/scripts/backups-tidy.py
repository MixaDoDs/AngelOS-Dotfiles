#!/usr/bin/env python3
"""angelOS's own backups (~/.local/state/angelos/backups) without the pile-up: every settings
page, every niri change and every agent session leaves a folder there (850 of them, 1.5 GB by
2026-10-15). Of each kind (cursor, anim, window-layout, claude, update, …) the newest KEEP (3
of whole copies of the shell) and everything younger than DAYS stay as they are; the rest goes into one tar.zst in
~/angelos-archive/ (with an INDEX.md line per folder), then out of the backups folder.

  backups-tidy.py [--days 14] [--keep 20] [--apply] [--json]
      without --apply it only says what it would do (nothing is moved)

Nothing is deleted that is not in a written, read-back archive first.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import time
from pathlib import Path

HOME = Path.home()
STATE = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state") / "angelos"
SRC = STATE / "backups"
ARCHIVE = Path(os.environ.get("ANGELOS_ARCHIVE") or HOME / "angelos-archive")
BIG = 5_000_000            # a backup bigger than this is a whole copy
BIG_KEEP = 3
STAMP = re.compile(r"^(\d{8}-\d{6})(?:-(.*))?$")


FAMILIES = ("claude", "codex", "update", "hang-logs", "switch", "before")


def kind_of(name):
    """the backup's kind: its name without the time and the random tail; an agent's session
    backups (before-claude-…, claude-…-before-…) are one kind whatever they say after"""
    for fam in FAMILIES:
        if fam in name:
            return fam
    m = STAMP.match(name)
    rest = (m.group(2) or "") if m else name
    rest = re.sub(r"[-_.]?[0-9a-z]{6,8}$", "", rest) if re.search(r"\d", rest[-8:] or "") else rest
    rest = re.sub(r"[-_]\d.*$", "", rest)
    return rest or "other"


def when(path):
    m = re.search(r"(\d{8}-\d{6})", path.name)
    if m:
        try:
            return time.mktime(time.strptime(m.group(1), "%Y%m%d-%H%M%S"))
        except ValueError:
            pass
    return path.stat().st_mtime


def size(path):
    if path.is_file() or path.is_symlink():
        return path.lstat().st_size
    return sum(f.lstat().st_size for f in path.rglob("*") if f.is_file() or f.is_symlink())


def plan(days, keep, src=SRC):
    now = time.time()
    entries = [p for p in src.iterdir()] if src.is_dir() else []
    groups = {}
    for p in entries:
        groups.setdefault(kind_of(p.name), []).append(p)
    out = []
    for kind, items in groups.items():
        items.sort(key=when, reverse=True)
        # whole copies of the shell (an agent's session, an update, a switch: tens of MB each)
        # are kept fewer than the small settings snapshots
        sizes = sorted(size(p) for p in items)
        limit = min(keep, BIG_KEEP) if sizes[len(sizes) // 2] > BIG else keep
        for n, p in enumerate(items):
            if n >= limit and now - when(p) > days * 86400:
                out.append({"path": str(p), "kind": kind, "when": time.strftime("%Y-%m-%d %H:%M", time.localtime(when(p))), "bytes": size(p)})
    return out, {k: len(v) for k, v in groups.items()}


def apply(moves, archive_dir=ARCHIVE):
    if not moves:
        return None
    stamp = time.strftime("%Y%m%d-%H%M%S")
    archive_dir.mkdir(parents=True, exist_ok=True)
    tar_path = archive_dir / f"angelos-backups-{stamp}.tar"
    with tarfile.open(tar_path, "w") as t:
        for m in moves:
            t.add(m["path"], arcname=Path(m["path"]).name)
    # read back: every folder must be in it before anything goes
    with tarfile.open(tar_path) as t:
        names = {n.split("/")[0] for n in t.getnames()}
    missing = [m for m in moves if Path(m["path"]).name not in names]
    if missing:
        raise SystemExit("the archive lacks %d entries: nothing removed (%s)" % (len(missing), tar_path))
    final = tar_path
    if shutil.which("zstd"):
        r = subprocess.run(["zstd", "-q", "-19", "-T0", "--rm", str(tar_path)])
        if r.returncode == 0:
            final = Path(str(tar_path) + ".zst")
    with open(archive_dir / "INDEX.md", "a") as f:
        f.write(f"\n## {final.name} — angelOS backups older than kept ({len(moves)})\n\n")
        for m in moves:
            f.write(f"- `{Path(m['path']).name}` · {m['kind']} · {m['when']} · {m['bytes'] // 1024} KB\n")
    for m in moves:
        p = Path(m["path"])
        if p.is_dir() and not p.is_symlink():
            shutil.rmtree(p)
        else:
            p.unlink(missing_ok=True)
    return str(final)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=14)
    ap.add_argument("--keep", type=int, default=20)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    moves, kinds = plan(a.days, a.keep)
    total = sum(m["bytes"] for m in moves)
    done = apply(moves) if a.apply else None
    if a.json:
        print(json.dumps({"move": len(moves), "bytes": total, "kinds": kinds, "archive": done}))
        return
    by = {}
    for m in moves:
        by.setdefault(m["kind"], [0, 0])
        by[m["kind"]][0] += 1
        by[m["kind"]][1] += m["bytes"]
    for k, (n, b) in sorted(by.items(), key=lambda kv: -kv[1][1]):
        print("%-24s %4d   %8.1f MB" % (k, n, b / 1e6))
    print("%s: %d entries, %.1f MB%s" % ("archived" if done else "would archive", len(moves), total / 1e6, " → " + done if done else ""))


if __name__ == "__main__":
    main()
