#!/usr/bin/env python3
"""angelOS Recovery: the game's progress and every setting, kept on the user's own GitHub (a
private repository, angelos-save) or in a file, and brought back on another computer or after a
reinstall. gh holds the login; angelOS keeps no token.

  recovery.py status                 JSON {gh, login, repo, exists, last, files}
  recovery.py push                   save to GitHub (creates the private repo the first time)
  recovery.py pull [--restart]       restore from GitHub
  recovery.py export FILE            save into a file (.tar.gz)
  recovery.py import FILE [--restart]
  recovery.py files                  what is kept, one path per line

What is kept (paths under $HOME): the settings (~/.config/angelos/settings.json), the game's save
(save.json: the story, the achievements), heaven's stars, the login rewards, the novel's place,
the plugins you installed (~/.config/angelos/plugins) and your keyboard shortcuts (niri's key
profiles). Not kept: the clipboard, notifications, the owner's marker, anything machine-only.
A restore first copies what is there now into ~/.local/state/angelos/backups/recovery-<time>/,
then (--restart) restarts the shell so it reads the restored files.
"""
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
from pathlib import Path

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
STATE = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state")
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache")
REPO = "angelos-save"
KEEP = [
    CONFIG / "angelos/settings.json",
    CONFIG / "angelos/save.json",
    CONFIG / "angelos/plugins",
    STATE / "angelos/heaven-stars.json",
    STATE / "angelos/lock-stream.json",
    STATE / "angelos/novel.json",
    CONFIG / "niri/cfg/keybinds-common.kdl",
    CONFIG / "niri/cfg/keybinds-pixel.kdl",
    CONFIG / "niri/cfg/keybinds-macos.kdl",
]
SHELL = Path(__file__).resolve().parents[1]


def rel(p):
    return str(Path(p).relative_to(HOME))


def run(cmd, **kw):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, **kw)


def say(text):
    print(text, flush=True)


def gh_login():
    if not shutil.which("gh"):
        return None
    r = run(["gh", "api", "user", "--jq", ".login"])
    return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else ""


def pack(fileobj):
    with tarfile.open(fileobj=fileobj, mode="w:gz") as tar:
        meta = {"angelos": "recovery", "version": 1, "time": time.strftime("%Y-%m-%d %H:%M"),
                "host": os.uname().nodename, "files": []}
        for p in KEEP:
            if p.exists():
                tar.add(p, arcname=rel(p), filter=lambda ti: None if "__pycache__" in ti.name else ti)
                meta["files"].append(rel(p))
        data = json.dumps(meta, ensure_ascii=False, indent=2).encode()
        ti = tarfile.TarInfo("angelos-recovery.json")
        ti.size = len(data)
        ti.mtime = int(time.time())
        tar.addfile(ti, io.BytesIO(data))
    return meta


def digest():
    """what is kept, as one hash (the archive itself differs every time: dates inside)"""
    import hashlib
    h = hashlib.sha256()
    for p in KEEP:
        files = sorted(x for x in p.rglob("*") if x.is_file() and "__pycache__" not in x.parts) if p.is_dir() else [p] if p.exists() else []
        for f in files:
            h.update(rel(f).encode() + b"\0" + f.read_bytes() + b"\0")
    return h.hexdigest()


def snapshot():
    """what is there now, before a restore replaces it"""
    dst = STATE / "angelos/backups" / time.strftime("recovery-%Y%m%d-%H%M%S")
    dst.mkdir(parents=True, exist_ok=True)
    with open(dst / "before.tar.gz", "wb") as f:
        pack(f)
    return dst


def unpack(path_or_obj):
    """restore a pack into $HOME; only the kept paths, nothing outside them"""
    allowed = [rel(p) for p in KEEP]
    with tarfile.open(path_or_obj, mode="r:gz") if isinstance(path_or_obj, (str, Path)) else \
            tarfile.open(fileobj=path_or_obj, mode="r:gz") as tar:
        names = tar.getnames()
        if "angelos-recovery.json" not in names:
            raise SystemExit("✕ это не сохранение angelOS")
        meta = json.loads(tar.extractfile("angelos-recovery.json").read())
        before = snapshot()
        say(f"» то, что было, отложено в {before}")
        # whole folders (the plugins) are replaced, not merged
        for a in allowed:
            if any(n == a or n.startswith(a + "/") for n in names) and (HOME / a).is_dir():
                shutil.rmtree(HOME / a)
        members = [m for m in tar.getmembers() if any(m.name == a or m.name.startswith(a + "/") for a in allowed)
                   and not m.issym() and not m.islnk() and ".." not in Path(m.name).parts]
        tar.extractall(HOME, members=members, filter="data") if sys.version_info >= (3, 12) else tar.extractall(HOME, members=members)
    say(f"» восстановлено: сохранение от {meta.get('time', '?')} ({meta.get('host', '?')}), файлов {len(meta.get('files', []))}")
    return meta


def restart():
    exe = SHELL / "bin/angelos"
    subprocess.Popen(["setsid", "sh", "-c", f'sleep 1; "{exe}" restart'], stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


def git(repo_dir, *args):
    # gh is the credential helper: no token of ours anywhere
    return run(["git", "-C", str(repo_dir), "-c", "credential.helper=", "-c",
                "credential.helper=!gh auth git-credential"] + list(args))


def clone(login):
    d = CACHE / "angelos/recovery-repo"
    url = f"https://github.com/{login}/{REPO}.git"
    if (d / ".git").exists():
        git(d, "remote", "set-url", "origin", url)
        r = git(d, "fetch", "--quiet", "origin")
        if r.returncode != 0:
            raise SystemExit("✕ GitHub не ответил: " + r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "✕ GitHub не ответил")
        if git(d, "rev-parse", "--verify", "--quiet", "origin/main").returncode == 0:
            git(d, "reset", "--quiet", "--hard", "origin/main")
        return d
    shutil.rmtree(d, ignore_errors=True)
    d.parent.mkdir(parents=True, exist_ok=True)
    r = run(["git", "-c", "credential.helper=", "-c", "credential.helper=!gh auth git-credential",
             "clone", "--quiet", url, str(d)])
    if r.returncode != 0:
        raise SystemExit("✕ не удалось скачать " + url)
    return d


def repo_info(login):
    r = run(["gh", "api", f"repos/{login}/{REPO}", "--jq", "[.private, .pushed_at] | @tsv"])
    if r.returncode != 0:
        return None
    private, pushed = (r.stdout.strip().split("\t") + [""])[:2]
    return {"private": private == "true", "pushed": pushed}


def status():
    login = gh_login()
    out = {"gh": login is not None, "login": login or "", "repo": REPO, "exists": False, "last": "",
           "files": [rel(p) for p in KEEP if p.exists()]}
    if login:
        info = repo_info(login)
        if info:
            out["exists"] = True
            r = run(["gh", "api", f"repos/{login}/{REPO}/commits?per_page=1", "--jq", ".[0].commit.message"])
            out["last"] = r.stdout.strip() if r.returncode == 0 else info["pushed"]
    print(json.dumps(out, ensure_ascii=False))


def push():
    login = gh_login()
    if not login:
        raise SystemExit("✕ нет входа в GitHub (gh auth login)")
    if not repo_info(login):
        r = run(["gh", "repo", "create", f"{login}/{REPO}", "--private",
                 "--description", "angelOS Recovery: my progress and settings (private)"])
        if r.returncode != 0:
            raise SystemExit("✕ не удалось создать приватный репозиторий: " + r.stderr.strip())
        say(f"» создан приватный репозиторий {login}/{REPO}")
    elif not repo_info(login)["private"]:
        raise SystemExit(f"✕ {login}/{REPO} публичный — angelOS сохраняет только в приватный")
    d = clone(login)
    now = digest()
    if (d / "content.sha256").exists() and (d / "content.sha256").read_text().strip() == now:
        say("» на GitHub уже то же самое ♡")
        return
    for f in d.iterdir():
        if f.name != ".git":
            shutil.rmtree(f) if f.is_dir() else f.unlink()
    with open(d / "angelos-recovery.tar.gz", "wb") as f:
        meta = pack(f)
    (d / "content.sha256").write_text(now + "\n")
    (d / "README.md").write_text("# angelOS Recovery\n\nYour angelOS progress and settings. Keep this repository "
                                 "private. Restore: Settings → Account → Recovery, or the setup wizard's GitHub step.\n")
    git(d, "checkout", "--quiet", "-B", "main")
    git(d, "add", "-A")
    if git(d, "diff", "--cached", "--quiet").returncode == 0 and git(d, "rev-parse", "--verify", "--quiet", "origin/main").returncode == 0:
        say("» на GitHub уже то же самое ♡")
        return
    msg = f"{meta['time']} · {meta['host']}"
    git(d, "-c", f"user.name={login}", "-c", f"user.email={login}@users.noreply.github.com", "commit", "--quiet", "-m", msg)
    r = git(d, "push", "--quiet", "-u", "origin", "main")
    if r.returncode != 0:
        raise SystemExit("✕ не отправилось: " + r.stderr.strip())
    say(f"» сохранено на GitHub: {login}/{REPO} — {msg}")


def pull(do_restart):
    login = gh_login()
    if not login:
        raise SystemExit("✕ нет входа в GitHub (gh auth login)")
    if not repo_info(login):
        raise SystemExit(f"✕ сохранения нет: {login}/{REPO} не найден")
    d = clone(login)
    f = d / "angelos-recovery.tar.gz"
    if not f.exists():
        raise SystemExit("✕ в репозитории нет сохранения")
    unpack(f)
    if do_restart:
        restart()


if __name__ == "__main__":
    a = sys.argv[1:]
    cmd = a[0] if a else ""
    try:
        if cmd == "status":
            status()
        elif cmd == "push":
            push()
        elif cmd == "pull":
            pull("--restart" in a)
        elif cmd == "export" and len(a) > 1:
            with open(a[1], "wb") as f:
                meta = pack(f)
            os.chmod(a[1], 0o600)
            say(f"» сохранено в файл {a[1]}: файлов {len(meta['files'])}")
        elif cmd == "import" and len(a) > 1:
            unpack(a[1])
            if "--restart" in a:
                restart()
        elif cmd == "files":
            print("\n".join(rel(p) for p in KEEP if p.exists()))
        else:
            print(__doc__)
            sys.exit(2)
    except tarfile.TarError as e:
        print(f"✕ файл повреждён: {e}", file=sys.stderr)
        sys.exit(1)
    except SystemExit as e:
        if isinstance(e.code, str):
            print(e.code, file=sys.stderr)
            sys.exit(1)
        raise
