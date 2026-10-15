#!/usr/bin/env python3
"""«Обслуживание» (Device Care) for angelOS: one button that looks the computer over and cleans
what is safe to clean (services/Care, Settings → System → Maintenance, `angelos care`).

  care.py scan            JSON {"items": [...], "checks": [...], "score": 0-100}
                          items: what can be cleaned, with the bytes it frees (nothing changes)
                            {id, ru, en, hintRu, hintEn, bytes, root, default}
                          checks: how things are {id, level: ok|info|warn|bad, ru, en, open}
  care.py run --events ID…
                          cleans those: one admin password (pkexec → scripts/apps-root.py) for
                          the ones that need root, progress as lines EV {"ev": item|check|done, …}

Safe means: only caches that fill themselves again (and only their old files), never models,
music, browser profiles, game shader caches or wine prefixes; angelOS's backups are archived
before they leave; the journal is copied (log-archive) before it is shortened; the trash only
when ticked.
"""
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
HOME = Path.home()
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache")
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share")
DAY = 86400
OLD = 30 * DAY
LANG = (os.environ.get("ANGELOS_LANG") or os.environ.get("LANG") or "en")[:2].lower()
JOURNAL_KEEP = 500 * 1024 * 1024

# caches that fill themselves again — their files older than OLD go (content-addressed: a missing
# one is fetched or built next time). Not here on purpose: huggingface (models), spotify (music
# kept offline), nvidia / mesa / steam / dxvk (game shaders: CS2 compiles 3 minutes), wine,
# browsers (Helium, Firefox: they hold their own), angelos, quickshell.
DEV_CACHES = [CACHE / "pip", CACHE / "go-build", CACHE / "bun/install/cache", CACHE / "yay", CACHE / "paru/clone",
              HOME / ".npm/_cacache", CACHE / "pnpm", CACHE / "electron", CACHE / "node-gyp", CACHE / "typescript",
              HOME / ".cargo/registry/cache"]


def t(ru, en):
    return ru if LANG == "ru" else en


def run(cmd, timeout=30, **kw):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout,
                              env=dict(os.environ, LC_ALL="C"), **kw)
    except (OSError, subprocess.SubprocessError):
        return subprocess.CompletedProcess(cmd, 127, "", "")


def ev(kind, **data):
    print("EV " + json.dumps({"ev": kind} | data, ensure_ascii=False), flush=True)


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, HERE / file)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


# ---------------------------------------------------------------- what is old where

def old_files(root, age=OLD, pattern=None):
    """[(path, size)] of files under root not touched for `age` (by mtime and atime both)"""
    out = []
    if not root.exists():
        return out
    now = time.time()
    for dirpath, dirs, files in os.walk(root, onerror=lambda e: None):
        for n in files:
            if pattern and not pattern.search(n):
                continue
            p = os.path.join(dirpath, n)
            try:
                st = os.lstat(p)
            except OSError:
                continue
            if now - max(st.st_mtime, st.st_atime if st.st_atime < now else 0) > age:
                out.append((p, st.st_size))
    return out


def tree_size(p):
    total = 0
    for dirpath, _, files in os.walk(p, onerror=lambda e: None):
        for n in files:
            try:
                total += os.lstat(os.path.join(dirpath, n)).st_size
            except OSError:
                pass
    return total


def leftovers():
    """mktemp dirs left in ~/.cache and the test stands' /tmp/aos-* — a day old at least"""
    now = time.time()
    out = []
    for base, rx in ((CACHE, re.compile(r"^tmp\.[A-Za-z0-9]{6,}$")), (Path("/tmp"), re.compile(r"^aos-[a-z]+\.[A-Za-z0-9]{6}$"))):
        try:
            entries = list(os.scandir(base))
        except OSError:
            continue
        for e in entries:
            try:
                if rx.match(e.name) and e.is_dir(follow_symlinks=False) and e.stat(follow_symlinks=False).st_uid == os.getuid() \
                        and now - e.stat(follow_symlinks=False).st_mtime > DAY:
                    out.append((e.path, tree_size(e.path)))
            except OSError:
                continue
    return out


def trash_old():
    """the trash's files deleted more than OLD ago (by their .trashinfo)"""
    files = DATA / "Trash/files"
    info = DATA / "Trash/info"
    out = []
    if not info.exists():
        return out
    now = time.time()
    for n in os.listdir(info):
        if not n.endswith(".trashinfo"):
            continue
        try:
            text = (info / n).read_text(errors="replace")
            m = re.search(r"DeletionDate=(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)", text)
            when = time.mktime(time.strptime(m.group(1), "%Y-%m-%dT%H:%M:%S")) if m else 0
        except (OSError, ValueError):
            continue
        if when and now - when > OLD:
            target = files / n[:-len(".trashinfo")]
            size = tree_size(target) if target.is_dir() else (target.lstat().st_size if target.exists() or target.is_symlink() else 0)
            out.append((str(target), size, str(info / n)))
    return out


def pacman_cache():
    """bytes paccache would free: older versions (keep 2) and packages not installed any more"""
    total = 0
    if not shutil.which("paccache"):
        return None
    for args in (["-dk2"], ["-duk0"]):
        r = run(["paccache", *args, "-v"], timeout=60)
        m = re.search(r"disk space saved:\s*([\d.]+)\s*([KMGT]?i?B)", r.stdout + r.stderr)
        if m:
            k = {"B": 1, "KiB": 1024, "MiB": 1024 ** 2, "GiB": 1024 ** 3, "TiB": 1024 ** 4}.get(m.group(2), 1)
            total += int(float(m.group(1)) * k)
    return total


def journal_usage():
    r = run(["journalctl", "--disk-usage"])
    m = re.search(r"take up ([\d.]+)([KMGT]?)", r.stdout)
    if not m:
        return 0
    return int(float(m.group(1)) * {"": 1, "K": 1024, "M": 1024 ** 2, "G": 1024 ** 3, "T": 1024 ** 4}[m.group(2)])


def coredumps():
    d = Path("/var/lib/systemd/coredump")
    now = time.time()
    total = 0
    try:
        for e in os.scandir(d):
            st = e.stat(follow_symlinks=False)
            if now - st.st_mtime > 7 * DAY:
                total += st.st_size
    except OSError:
        pass
    return total


def disks():
    """the real disks for SMART (not zram, loop or a card reader without media)"""
    r = run(["lsblk", "-dnpo", "NAME,TYPE,SIZE"])
    out = []
    for line in r.stdout.splitlines():
        f = line.split()
        if len(f) >= 2 and f[1] == "disk" and re.match(r"^/dev/(sd[a-z]+|nvme\d+n\d+|vd[a-z]+)$", f[0]) and (len(f) < 3 or f[2] != "0B"):
            out.append(f[0])
    return out


# ---------------------------------------------------------------- scan

def scan():
    items = []

    def item(i, ru, en, hru, hen, b, root=False, default=True):
        items.append({"id": i, "ru": ru, "en": en, "hintRu": hru, "hintEn": hen, "bytes": b, "root": root, "default": default})

    thumbs = old_files(CACHE / "thumbnails")
    item("thumbnails", "Старые миниатюры", "Old thumbnails", "картинки-превью файлов, которые давно не открывали", "previews of files not opened in a long time", sum(s for _, s in thumbs))
    dev = [f for d in DEV_CACHES for f in old_files(d)]
    item("devcaches", "Кэши разработки и сборки", "Build and package caches", "pip, uv, go, npm, bun, cargo, yay/paru — старше 30 дней; скачаются заново, если понадобятся", "pip, uv, go, npm, bun, cargo, yay/paru — older than 30 days; fetched again if needed", sum(s for _, s in dev))
    left = leftovers()
    item("leftovers", "Забытые временные папки", "Forgotten temporary folders", "tmp.* в кэше и остатки тестов angelOS старше суток", "tmp.* in the cache and angelOS test leftovers older than a day", sum(s for _, s in left))
    try:
        bt = json.loads(run(["python3", str(HERE / "backups-tidy.py"), "--json"], timeout=60).stdout or "{}")
    except ValueError:
        bt = {}
    item("backups", "Бэкапы angelOS → архив", "angelOS backups → archive", "старые бэкапы настроек сжимаются в ~/angelos-archive (ничего не теряется)", "old settings backups are packed into ~/angelos-archive (nothing is lost)", int(bt.get("bytes") or 0))
    trash = trash_old()
    item("trash", "Корзина: старше 30 дней", "Trash: older than 30 days", "файлы, удалённые больше месяца назад", "files deleted more than a month ago", sum(s for _, s, _ in trash), default=False)
    pc = pacman_cache()
    if pc is not None:
        item("pacman", "Кэш пакетов", "Package cache", "старые версии пакетов (две последние остаются) и пакеты, которых больше нет", "old package versions (the last two stay) and packages no longer installed", pc, root=True)
    try:
        orph = module("programs", "programs.py").orphans()
    except Exception:
        orph = []
    item("orphans", "Ненужные зависимости", "Orphaned dependencies", (", ".join(o["name"] for o in orph[:6]) + ("…" if len(orph) > 6 else "")) or "нет", (", ".join(o["name"] for o in orph[:6]) + ("…" if len(orph) > 6 else "")) or "none", sum(o["size"] for o in orph), root=True)
    ju = journal_usage()
    if ju > JOURNAL_KEEP:
        item("journal", "Системный журнал до 500 МБ", "System journal down to 500 MB", "сначала дни журнала копируются в ~/.local/state/angelos/logs", "the journal's days are copied to ~/.local/state/angelos/logs first", ju - JOURNAL_KEEP, root=True)
    cd = coredumps()
    if cd:
        item("coredumps", "Дампы падений программ", "Crash dumps", "старше недели", "older than a week", cd, root=True)
    if shutil.which("flatpak") and run(["flatpak", "list", "--columns=application"]).stdout.strip():
        item("flatpak", "Неиспользуемое Flatpak", "Unused Flatpak runtimes", "среды, которые больше ни одной программе не нужны", "runtimes no app uses any more", 0)
    if shutil.which("smartctl") and disks():
        item("smart", "Проверить здоровье дисков", "Check the disks' health", "SMART: " + ", ".join(disks()), "SMART: " + ", ".join(disks()), 0, root=True)

    checks = []

    def check(i, level, ru, en, open_=""):
        checks.append({"id": i, "level": level, "ru": ru, "en": en, "open": open_})

    # space
    r = run(["df", "-B1", "--output=target,size,avail,fstype"])
    seen = set()
    for line in r.stdout.splitlines()[1:]:
        f = line.split()
        if len(f) < 4 or f[3] in ("tmpfs", "devtmpfs", "efivarfs", "overlay", "squashfs", "vfat", "zram") or f[0].startswith(("/run", "/dev", "/sys", "/proc", "/boot", "/efi", "/var/lib/docker")):
            continue
        size, avail = int(f[1]), int(f[2])
        key = (size, f[3])
        if key in seen or size < 2 * 1024 ** 3:
            continue
        seen.add(key)
        free = avail / size if size else 1
        lvl = "bad" if free < 0.05 else "warn" if free < 0.15 else "ok"
        check("disk:" + f[0], lvl, "Свободно на %s: %s из %s (%d %%)" % (f[0], human(avail, "ru"), human(size, "ru"), free * 100),
              "Free on %s: %s of %s (%d %%)" % (f[0], human(avail, "en"), human(size, "en"), free * 100), "disks")
    # memory and swap
    mi = {}
    try:
        for line in open("/proc/meminfo"):
            k, v = line.split(":", 1)
            mi[k] = int(v.split()[0]) * 1024
    except OSError:
        pass
    if mi.get("MemTotal"):
        avail = mi.get("MemAvailable", 0) / mi["MemTotal"]
        swap = (mi.get("SwapTotal", 0) - mi.get("SwapFree", 0))
        swapf = swap / mi["SwapTotal"] if mi.get("SwapTotal") else 0
        lvl = "bad" if avail < 0.05 else "warn" if avail < 0.12 or swapf > 0.7 else "ok"
        check("memory", lvl, "Память: свободно %s из %s, своп занят %s" % (human(mi.get("MemAvailable", 0), "ru"), human(mi["MemTotal"], "ru"), human(swap, "ru")),
              "Memory: %s of %s available, %s of swap in use" % (human(mi.get("MemAvailable", 0), "en"), human(mi["MemTotal"], "en"), human(swap, "en")), "perf")
    # failed services
    sysf = [l.split()[0] for l in run(["systemctl", "--failed", "--plain", "--no-legend"]).stdout.splitlines() if l.strip()]
    usrf = [l.split()[0] for l in run(["systemctl", "--user", "--failed", "--plain", "--no-legend"]).stdout.splitlines() if l.strip()]
    failed = sysf + usrf
    check("failed", "warn" if failed else "ok",
          ("Упавшие службы: " + ", ".join(failed[:5]) + ("…" if len(failed) > 5 else "")) if failed else "Все службы работают",
          ("Failed services: " + ", ".join(failed[:5]) + ("…" if len(failed) > 5 else "")) if failed else "All services are running", "failed")
    # .pacnew
    pacnew = []
    for dirpath, _, files in os.walk("/etc", onerror=lambda e: None):
        pacnew += [os.path.join(dirpath, n) for n in files if n.endswith((".pacnew", ".pacsave"))]
    check("pacnew", "info" if pacnew else "ok",
          ("Новые версии настроек ждут сравнения (.pacnew): %d" % len(pacnew)) if pacnew else "Нет непросмотренных .pacnew",
          ("New config versions wait to be merged (.pacnew): %d" % len(pacnew)) if pacnew else "No .pacnew files waiting", "pacnew")
    # errors since boot
    errs = len(run(["journalctl", "-p", "3", "-b", "-q", "--no-pager", "-o", "cat"], timeout=20).stdout.splitlines())
    check("errors", "info" if errs > 50 else "ok", "Ошибок в журнале с загрузки: %d" % errs, "Errors in the journal since boot: %d" % errs, "errors")

    reclaim = sum(i["bytes"] for i in items if i["default"])
    score = 100 - sum({"bad": 20, "warn": 8, "info": 2}.get(c["level"], 0) for c in checks)
    score -= min(10, reclaim // (2 * 1024 ** 3) * 2)
    print(json.dumps({"items": items, "checks": checks, "score": max(0, min(100, score)), "reclaim": reclaim}, ensure_ascii=False))


def human(n, lang):
    units = ["Б", "КБ", "МБ", "ГБ", "ТБ"] if lang == "ru" else ["B", "KB", "MB", "GB", "TB"]
    n = float(n)
    i = 0
    while n >= 1024 and i < 4:
        n /= 1024
        i += 1
    return ("%d %s" if n >= 10 or i == 0 else "%.1f %s") % (n, units[i])


# ---------------------------------------------------------------- run

def remove_paths(paths):
    freed = 0
    for p, size in paths:
        try:
            if os.path.isdir(p) and not os.path.islink(p):
                shutil.rmtree(p)
            else:
                os.unlink(p)
            freed += size
        except OSError:
            pass
    return freed


def disk_free():
    st = os.statvfs(str(HOME))
    return st.f_bavail * st.f_frsize


def clean(ids):
    need_root = {"pacman", "orphans", "journal", "coredumps", "smart"} & set(ids)
    ai = module("apps_install", "apps-install.py") if need_root else None
    helper = None
    if need_root:
        ev("auth")
        helper, why = ai.start_root()
        if why:
            ev("done", freed=0, auth=why)
            return 2
        root = ai.root
    total = 0
    try:
        for n, i in enumerate(ids):
            ev("item", id=i, state="start", n=n, of=len(ids))
            ok, freed, note = True, 0, ""
            before = disk_free()
            if i == "thumbnails":
                freed = remove_paths(old_files(CACHE / "thumbnails"))
            elif i == "devcaches":
                freed = remove_paths([f for d in DEV_CACHES for f in old_files(d)])
                if shutil.which("uv"):
                    run(["uv", "cache", "prune"], timeout=120)
                    freed = max(freed, disk_free() - before)
            elif i == "leftovers":
                freed = remove_paths(leftovers())
            elif i == "backups":
                r = run(["python3", str(HERE / "backups-tidy.py"), "--apply", "--json"], timeout=600)
                ok = r.returncode == 0
                try:
                    freed = int(json.loads(r.stdout.strip().splitlines()[-1]).get("bytes") or 0) if ok else 0
                except (ValueError, IndexError):
                    freed = 0
            elif i == "trash":
                for target, size, info in trash_old():
                    if remove_paths([(target, size)]) or not os.path.lexists(target):
                        freed += size
                        try:
                            os.unlink(info)
                        except OSError:
                            pass
            elif i == "flatpak":
                ok = run(["flatpak", "uninstall", "--user", "--unused", "-y", "--noninteractive"], timeout=600).returncode == 0
                freed = max(0, disk_free() - before)
            elif i == "pacman":
                ok = subprocess.run(root("paccache", "-rk2"), stdout=subprocess.DEVNULL).returncode == 0
                subprocess.run(root("paccache", "-ruk0"), stdout=subprocess.DEVNULL)
                freed = max(0, disk_free() - before)
            elif i == "orphans":
                pr = module("programs", "programs.py")
                names = [o["name"] for o in pr.orphans()]
                if names:
                    # as Programs → Clean up: with what only they needed, unless a part of the system would go along
                    deep = pr.plan(["pacman:" + x for x in names], flags=("-Rns",))
                    flags = "-Rn" if deep.get("refused") else "-Rns"
                    ok = subprocess.run(root("pacman", flags, "--noconfirm", *names), stdout=subprocess.DEVNULL).returncode == 0
                freed = max(0, disk_free() - before)
            elif i == "journal":
                # the days the journal still holds are copied out first: the logs of all time stay
                run(["python3", str(HERE / "log-archive.py"), "--days-back", "30"], timeout=600)
                ok = subprocess.run(root("journalctl", "--vacuum-size=500M"), stdout=subprocess.DEVNULL).returncode == 0
                freed = max(0, disk_free() - before)
            elif i == "coredumps":
                ok = subprocess.run(root("find", "/var/lib/systemd/coredump", "-type", "f", "-mtime", "+7", "-delete"), stdout=subprocess.DEVNULL).returncode == 0
                freed = max(0, disk_free() - before)
            elif i == "smart":
                bad = []
                for d in disks():
                    r = subprocess.run(root("smartctl", "-H", "-j", d), capture_output=True, text=True)
                    try:
                        j = json.loads(r.stdout[r.stdout.index("{"):r.stdout.rindex("}") + 1])
                        passed = j.get("smart_status", {}).get("passed")
                    except ValueError:
                        passed = None
                    if passed is False:
                        bad.append(d)
                    ev("check", id="smart:" + d, level="ok" if passed else "bad" if passed is False else "info",
                       ru=("%s: здоров" if passed else "%s: SMART ПРЕДУПРЕЖДАЕТ — сделайте копию данных" if passed is False else "%s: SMART не ответил") % d,
                       en=("%s: healthy" if passed else "%s: SMART WARNS — back the data up" if passed is False else "%s: no SMART answer") % d)
                ok = not bad
            total += freed
            ev("item", id=i, state="done" if ok else "fail", freed=freed, n=n + 1, of=len(ids), note=note)
    finally:
        if helper is not None or need_root:
            ai.stop_root(helper)
    ev("done", freed=total)
    return 0


def main():
    a = sys.argv[1:]
    if a[:1] == ["scan"]:
        scan()
        return 0
    if a[:1] == ["run"]:
        ids = [x for x in a[1:] if not x.startswith("--")]
        return clean(ids)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
