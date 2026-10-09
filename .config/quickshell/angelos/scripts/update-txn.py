#!/usr/bin/env python3
"""angelOS: the snapshot an update starts from, and the way back (scripts/dotfiles-update.sh).

  update-txn.py snapshot DIR --home H --state S --repo R --rev OLD --rev NEW --stamp STAMP
      record every file the installer may write (the repository's files in both
      versions, the theme files, the installer's own state) and copy the existing
      ones into DIR/files, each read back and checked; fails before anything is
      changed when a copy fails
  update-txn.py finish DIR --status ok|failed [--stage X] [--message M]
      record what the update left behind (DIR/after.json): the changes it made
  update-txn.py restore DIR [--dry-run]
      put back what this update changed, file by file. A file changed again since
      (by hand, by angelOS's settings) stays as it is and is reported as a
      conflict; files the update created are removed; the installer's manifest
      (installed-files.sha256) is patched to match; then `niri validate` and,
      when it still points at the update, the repository goes back to the old
      commit (so Settings → Updates offers the update again)
  update-txn.py last --state S
      the last attempt, for Settings → Updates

Output lines for the shell: "» text" for the log, then RESTORED <files> <conflicts>
<shell 0|1>, CONFLICT <path>, RESTORE-FAILED <reason> <text>, REPO <commit>,
LAST <status> <stage> <dir> <old> <new>, MESSAGE <text>, CHANGED <files> <shell 0|1>.
"""
import argparse
import fcntl
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import time
from pathlib import Path

VERSION = 1
MANIFEST = "installed-files.sha256"
# what the installer installs (install.sh: install_configs, install_assets)
REPO_ROOTS = (".config/", ".local/bin/", ".local/share/", "Pictures/")
# written by install_shell, switch.py and render-templates.py besides the repository's files
EXTRAS = [
    ".local/bin/angelos", ".config/angelos/active", ".config/angelos/dotfiles-source",
    ".config/niri/config.kdl", ".config/niri/cfg/autostart.kdl", ".config/niri/cfg/keybinds.kdl",
    ".config/niri/cfg/keybinds-common.kdl", ".config/niri/cfg/keybinds-pixel.kdl", ".config/niri/cfg/keybinds-macos.kdl",
    ".config/niri/cfg/rules.kdl", ".config/niri/noctalia.kdl", ".config/niri/angelos.kdl",
    ".config/kitty/kitty.conf", ".config/foot/foot.ini", ".config/alacritty/alacritty.toml",
    ".config/gtk-3.0/gtk.css", ".config/gtk-4.0/gtk.css",
    # the user's own layer, made by the installer once (install.sh user_layer)
    ".config/niri/cfg/user.kdl", ".config/fish/user.fish",
]
# the installer's state besides the manifest: new versions it parked, the bases of its merges
STATE_DIRS = ("kept-updates", "key-profile-bases")
TEMPLATES = ".config/quickshell/angelos/templates/templates.json"
ABSENT = {"kind": "absent"}


def say(*a):
    print("»", *a, flush=True)


def out(*a):
    print(*a, flush=True)


class Fail(Exception):
    def __init__(self, reason, text, code=1):
        super().__init__(text)
        self.reason, self.text, self.code = reason, text, code


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def state_of(path):
    try:
        st = os.lstat(path)
    except (FileNotFoundError, NotADirectoryError):
        return dict(ABSENT)
    if stat.S_ISLNK(st.st_mode):
        return {"kind": "link", "target": os.readlink(path)}
    if stat.S_ISREG(st.st_mode):
        return {"kind": "file", "sha": sha256(path), "mode": stat.S_IMODE(st.st_mode)}
    return {"kind": "other"}


def write_json(path, data):
    tmp = Path(str(path) + ".tmp")
    tmp.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n")
    os.replace(tmp, path)


def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return default


def stored(d, path):
    """Where the snapshot keeps its copy of the absolute path `path`."""
    return Path(d) / "files" / path.lstrip("/")


def git(repo, *args, check=True):
    return subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, check=check)


# ---- what an update may touch ----

def destinations(rel):
    """install.sh destination(): where repository file `rel` can land (every variant)."""
    if not rel.startswith(REPO_ROOTS):
        return []
    if "/__pycache__/" in rel or rel.endswith(".pyc") or ".bak." in rel or rel.startswith(".config/quickshell/angelos/owner/"):
        return []
    out = [rel]
    if "-no-noctalia" in rel:
        out.append(rel.replace("-no-noctalia", ""))
    if rel.startswith(".local/bin/") and rel.endswith("-simple"):
        out.append(rel[: -len("-simple")])
    return out


def braces(s):
    """a{b,c}d → abd, acd (not nested): how an entry's "writes" lists many files"""
    m = re.search(r"\{([^{}]*)\}", s)
    if not m:
        return [s]
    return [x for alt in m.group(1).split(",") for x in braces(s[: m.start()] + alt + s[m.end():])]


def template_targets(text, home):
    """what a templates.json renders: each entry's "target", and the files its
    "command" writes, declared in "writes" (gtk-live's themes, the browsers' themes) —
    a file the snapshot doesn't know survives a restore"""
    try:
        data = json.loads(text)
    except ValueError:
        return []
    found = []
    for e in data if isinstance(data, list) else [data]:
        if not isinstance(e, dict):
            continue
        writes = e.get("writes") if isinstance(e.get("writes"), list) else []
        for t in [e.get("target")] + writes:
            if isinstance(t, str) and t.startswith("~/"):
                found.extend(os.path.join(home, x[2:]) for x in braces(t))
    return found


def candidates(home, state, repo, revs):
    paths = set()
    for rev in revs:
        listing = git(repo, "ls-tree", "-r", "-z", "--name-only", rev).stdout
        for rel in filter(None, listing.split("\0")):
            for dest in destinations(rel):
                paths.add(os.path.join(home, dest))
        shown = git(repo, "show", f"{rev}:{TEMPLATES}", check=False)
        if shown.returncode == 0:
            paths.update(template_targets(shown.stdout, home))
    for user in sorted(Path(home, ".config/angelos/templates").glob("*.json")):
        try:
            paths.update(template_targets(user.read_text(), home))
        except OSError:
            pass
    paths.update(os.path.join(home, rel) for rel in EXTRAS)
    paths.add(os.path.join(state, MANIFEST))
    for sub in STATE_DIRS:
        paths.update(walk(os.path.join(state, sub)))
    return paths


def walk(top):
    found = []
    for base, _dirs, files in os.walk(top):
        found.extend(os.path.join(base, f) for f in files)
    return found


# ---- snapshot / finish ----

def cmd_snapshot(a):
    d = Path(a.dir)
    try:
        d.mkdir(parents=True)          # a fresh folder: an existing one is never reused
    except OSError as e:
        raise Fail("snapshot", f"cannot create {d}: {e.strerror or e}", 5)
    try:
        paths = candidates(a.home, a.state, a.repo, a.rev)
    except subprocess.CalledProcessError as e:
        raise Fail("snapshot", f"git: {e.stderr.strip() or e}", 5)
    entries, dirs = {}, set()
    try:
        for p in sorted(paths):
            s = state_of(p)
            if s["kind"] == "file":
                dst = stored(d, p)
                dst.parent.mkdir(parents=True, exist_ok=True)
                for _ in range(3):     # the file may be rewritten while it is copied
                    shutil.copy2(p, dst, follow_symlinks=False)
                    if sha256(dst) == s["sha"]:
                        break
                    s = state_of(p)
                else:
                    raise Fail("snapshot", f"{p} keeps changing while it is copied", 5)
            entries[p] = s
            parent = os.path.dirname(p)
            while parent not in dirs and parent != "/" and os.path.isdir(parent):
                dirs.add(parent)
                parent = os.path.dirname(parent)
        shutil.copy2(__file__, d / "update-txn.py")
        write_json(d / "before.json", {"version": VERSION, "entries": entries, "dirs": sorted(dirs)})
        meta = {"version": VERSION, "stamp": a.stamp, "home": a.home, "state": a.state, "repo": a.repo,
                "old": a.rev[0], "new": a.rev[-1], "status": "started", "stage": "snapshot", "message": "",
                "started": time.strftime("%Y-%m-%dT%H:%M:%S")}
        write_json(d / "meta.json", meta)
        ptr = Path(a.state, "update-last")
        ptr.parent.mkdir(parents=True, exist_ok=True)
        tmp = Path(str(ptr) + ".tmp")
        tmp.write_text(str(d) + "\n")
        os.replace(tmp, ptr)
    except Fail:
        raise
    except OSError as e:
        raise Fail("snapshot", f"{getattr(e, 'filename', '') or ''}: {e.strerror or e}".strip(": "), 5)
    files = sum(1 for s in entries.values() if s["kind"] == "file")
    say(f"снимок: {files} файлов (+{len(entries) - files} отмечены как отсутствующие) в {d}")


def cmd_finish(a):
    d = Path(a.dir)
    meta, before = read_json(d / "meta.json"), read_json(d / "before.json")
    if not meta or not before:
        raise Fail("finish", f"{d} is not an update snapshot", 2)
    paths = set(before["entries"])
    for p in list(paths):                  # the installer's own backups of this run
        bak = f"{p}.bak.{meta['stamp']}"
        if os.path.lexists(bak):
            paths.add(bak)
    for sub in STATE_DIRS:
        paths.update(walk(os.path.join(meta["state"], sub)))
    after = {p: state_of(p) for p in sorted(paths)}
    write_json(d / "after.json", {"version": VERSION, "entries": after})
    man = Path(meta["state"], MANIFEST)
    if man.is_file():
        shutil.copy2(man, d / "manifest.after")
    changed = [p for p in after if after[p] != before["entries"].get(p, ABSENT)]
    meta.update(status=a.status, stage=a.stage or meta.get("stage", ""), message=a.message or "",
                finished=time.strftime("%Y-%m-%dT%H:%M:%S"), changed=len(changed))
    write_json(d / "meta.json", meta)
    say(f"обновление изменило файлов: {len(changed)}")
    # the shell's own files changed (a run over the same commit after a failed one too):
    # the running shell keeps the old code until it restarts
    out("CHANGED", len(changed), int(any("/.config/quickshell/angelos/" in p for p in changed)))


# ---- restore ----

def read_manifest(path):
    m = {}
    try:
        for line in Path(path).read_text().splitlines():
            sha, _, rel = line.partition("  ")
            if rel:
                m[rel] = sha
    except OSError:
        pass
    return m


def manifest_text(m):
    return "".join(f"{m[rel]}  {rel}\n" for rel in sorted(m))


def put(path, s, source):
    """Make `path` what state `s` describes; `source` holds the file's bytes."""
    if s["kind"] == "absent":
        if os.path.lexists(path):
            os.unlink(path)
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.angelos-restore"
    if os.path.lexists(tmp):
        os.unlink(tmp)
    if s["kind"] == "link":
        os.symlink(s["target"], tmp)
    else:
        shutil.copy2(source, tmp, follow_symlinks=False)
        os.chmod(tmp, s["mode"])
    os.replace(tmp, path)


def niri_check():
    niri = shutil.which(os.environ.get("NIRI_BIN") or "niri")
    if not niri:
        return None, "niri не найден: восстановленный конфиг проверить нельзя"
    r = subprocess.run([niri, "validate"], capture_output=True, text=True)
    return r.returncode == 0, (r.stderr or r.stdout).strip()


def cmd_restore(a):
    d = Path(a.dir).resolve()
    meta, before = read_json(d / "meta.json"), read_json(d / "before.json")
    if not meta or not before or meta.get("version") != VERSION:
        raise Fail("backup", f"{d} is not an update snapshot", 2)
    if meta["status"] == "restored":
        raise Fail("done", "это обновление уже откатено", 3)
    lock = open(d / ".lock", "a")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        raise Fail("busy", "обновление ещё идёт", 3)
    home, state = meta["home"], meta["state"]
    man_path = os.path.join(state, MANIFEST)
    after_doc = read_json(d / "after.json")
    if after_doc:
        after = after_doc["entries"]
    else:
        # the update was cut short before it wrote down what it changed: everything
        # that differs from the snapshot now counts as its change
        say("обновление прервалось и не записало, что изменило — возвращаю всё к снимку")
        after = {p: state_of(p) for p in before["entries"]}
        for sub in STATE_DIRS:
            for p in walk(os.path.join(state, sub)):
                after.setdefault(p, state_of(p))
    b_entries = before["entries"]
    changed = sorted(p for p in set(b_entries) | set(after)
                     if p != man_path and b_entries.get(p, ABSENT) != after.get(p, ABSENT))

    # the snapshot must be whole before anything is touched
    for p in changed:
        s = b_entries.get(p, ABSENT)
        if s["kind"] == "file":
            src = stored(d, p)
            if not src.is_file() or sha256(src) != s["sha"]:
                raise Fail("backup-corrupt", f"копия в снимке повреждена или пропала: {p}", 4)

    actions, conflicts, same = [], [], []
    for p in changed:
        b, af, cur = b_entries.get(p, ABSENT), after.get(p, ABSENT), state_of(p)
        if cur == b:
            same.append(p)
        elif cur == af and b["kind"] != "other":
            actions.append(p)
        else:
            conflicts.append(p)

    # installed-files.sha256: entries back to the snapshot's, except for the conflicts
    m_before = read_manifest(stored(d, man_path)) if b_entries.get(man_path, ABSENT)["kind"] == "file" else {}
    m_after = read_manifest(d / "manifest.after") if (d / "manifest.after").is_file() else read_manifest(man_path)
    m_now = read_manifest(man_path)
    kept = {os.path.relpath(p, home) for p in conflicts}
    for rel in set(m_before) | set(m_after):
        if m_before.get(rel) != m_after.get(rel) and rel not in kept:
            if rel in m_before:
                m_now[rel] = m_before[rel]
            else:
                m_now.pop(rel, None)
    man_new = None if not m_now and b_entries.get(man_path, ABSENT)["kind"] == "absent" else manifest_text(m_now)
    man_cur = Path(man_path).read_text() if os.path.isfile(man_path) else None
    man_changes = man_new != man_cur

    if a.dry_run:
        for p in actions:
            out("WOULD-RESTORE", p)
        for p in conflicts:
            out("CONFLICT", p)
        return 0

    # a copy of everything this restore overwrites, so a failure can be undone
    stamp = time.strftime("%Y%m%d-%H%M%S")
    undo = d / f"restore-{stamp}"
    n = 1
    while undo.exists():
        n += 1
        undo = d / f"restore-{stamp}-{n}"
    touched = actions + ([man_path] if man_changes else [])
    undo_states = {}
    try:
        undo.mkdir()
        for p in touched:
            s = state_of(p)
            undo_states[p] = s
            if s["kind"] == "file":
                dst = stored(undo, p)
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(p, dst, follow_symlinks=False)
                if sha256(dst) != s["sha"]:
                    raise OSError(f"copy differs: {p}")
        write_json(undo / "plan.json", {"restore": actions, "conflicts": conflicts, "undo": undo_states})
    except OSError as e:
        raise Fail("io", f"не удалось сохранить текущие файлы перед откатом: {e}", 5)

    applied = []
    try:
        for p in actions:
            put(p, b_entries.get(p, ABSENT), stored(d, p))
            applied.append(p)
        if man_changes:
            if man_new is None:
                put(man_path, ABSENT, None)
            else:
                tmp = Path(man_path + ".tmp")
                tmp.write_text(man_new)
                os.replace(tmp, man_path)
            applied.append(man_path)
    except OSError as e:
        for p in reversed(applied):        # back to how it was before the restore
            try:
                put(p, undo_states[p], stored(undo, p))
            except OSError:
                pass
        raise Fail("io", f"{getattr(e, 'filename', '') or ''} {e.strerror or e}".strip()
                   + f"; ничего не изменено, снимок: {d}", 5)

    # folders the update created and left empty now
    keep_dirs = set(before.get("dirs", []))
    for p in actions:
        if b_entries.get(p, ABSENT)["kind"] != "absent":
            continue
        parent = os.path.dirname(p)
        while parent not in keep_dirs and parent.startswith(home + "/"):
            try:
                os.rmdir(parent)
            except OSError:
                break
            parent = os.path.dirname(parent)

    for p in conflicts:
        out("CONFLICT", p)
    meta.update(conflicts=conflicts, restore_dir=str(undo), restored_files=len(actions))
    ok, text = niri_check()
    if not ok:
        meta.update(status="restore-failed", message=text.splitlines()[-1] if text else "")
        write_json(d / "meta.json", meta)
        for line in (text or "").splitlines()[-20:]:
            say("  " + line)
        reason = "niri-missing" if ok is None else "niri"
        msg = text if ok is None else "конфиг niri после отката не проходит проверку"
        raise Fail(reason, f"{msg}; файлы до отката: {undo}, снимок: {d}", 6)
    say("niri: конфиг валиден")

    # the repository back to the version that is installed again
    repo, old, new = meta.get("repo"), meta.get("old"), meta.get("new")
    if repo and old and new and old != new and os.path.isdir(repo):
        head = git(repo, "rev-parse", "HEAD", check=False).stdout.strip()
        clean = git(repo, "status", "--porcelain", check=False).stdout.strip() == ""
        if head == new and clean and git(repo, "merge-base", "--is-ancestor", old, new, check=False).returncode == 0:
            r = git(repo, "reset", "--keep", old, check=False)
            if r.returncode == 0:
                out("REPO", old)
            else:
                say("репозиторий не вернулся на прежнюю версию:", r.stderr.strip())
        elif head != new:
            say("репозиторий уже на другой версии — его не трогаю")

    meta.update(status="restored", message="", restored=time.strftime("%Y-%m-%dT%H:%M:%S"))
    write_json(d / "meta.json", meta)
    shell = int(any("/.config/quickshell/angelos/" in p for p in actions))
    say(f"восстановлено файлов: {len(actions)}, без изменений: {len(same)}, конфликтов: {len(conflicts)}")
    out("RESTORED", len(actions), len(conflicts), shell)
    return 0


def cmd_last(a):
    try:
        d = Path(Path(a.state, "update-last").read_text().strip())
    except OSError:
        return 0
    meta = read_json(d / "meta.json")
    if not meta:
        return 0
    out("LAST", meta.get("status") or "-", meta.get("stage") or "-", d, meta.get("old") or "-", meta.get("new") or "-")
    if meta.get("message"):
        out("MESSAGE", meta["message"].replace("\n", " "))
    for c in meta.get("conflicts", []):
        out("CONFLICT", c)
    return 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("snapshot")
    s.add_argument("dir")
    s.add_argument("--home", required=True)
    s.add_argument("--state", required=True)
    s.add_argument("--repo", required=True)
    s.add_argument("--rev", action="append", required=True)
    s.add_argument("--stamp", required=True)
    f = sub.add_parser("finish")
    f.add_argument("dir")
    f.add_argument("--status", required=True)
    f.add_argument("--stage", default="")
    f.add_argument("--message", default="")
    r = sub.add_parser("restore")
    r.add_argument("dir")
    r.add_argument("--dry-run", action="store_true")
    la = sub.add_parser("last")
    la.add_argument("--state", required=True)
    a = ap.parse_args()
    try:
        return {"snapshot": cmd_snapshot, "finish": cmd_finish, "restore": cmd_restore, "last": cmd_last}[a.cmd](a) or 0
    except Fail as e:
        if a.cmd == "restore":
            out("RESTORE-FAILED", e.reason, e.text)
        else:
            say(e.text)
        return e.code


if __name__ == "__main__":
    sys.exit(main())
