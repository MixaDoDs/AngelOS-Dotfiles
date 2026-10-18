#!/usr/bin/env python3
"""«Доктор игр» for angelOS (Settings → Maintenance → Games, services/Care): what games need,
looked over in one go, and the three fixes that help most when a game stops starting.

  game-doctor.py scan                 JSON {checks, games, protons, edition, missing}
                                        checks: {id, level: ok|info|warn|bad, ru, en} as care.py's
                                        games: {id, name, prefix, shaderBytes}
  game-doctor.py reset-prefix ID      the game's Proton prefix (steamapps/compatdata/ID) is moved
                                        aside, never deleted (steamapps/angelos-prefix-backups/):
                                        Steam makes a clean one on the next start; saves inside it
                                        stay in the moved copy
  game-doctor.py clear-shaders ID|all Steam's shader cache of that game (all: of every game, and
                                        the NVIDIA / Mesa caches): compiled again on the next start
  game-doctor.py ge-proton            the newest GE-Proton from its GitHub release, checked with the
                                        release's own sha512, into compatibilitytools.d

Each action prints one JSON line {ok, ru, en}. Which Proton a game runs and its launch options are
not touched here (that is the user's pick in Steam).
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
HOME = Path.home()
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache")
STATE = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state") / "angelos"
LIST = HERE.parent / "data/gaming-packages.txt"
GE_API = "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest"
# Steam's own tools in the library: not games
TOOL_NAME = re.compile(r"^(Proton|Steam Linux Runtime|Steamworks Common|SteamVR)", re.I)
GPU = {"0x10de": ("NVIDIA", "lib32-nvidia-utils"), "0x1002": ("AMD", "lib32-vulkan-radeon"),
       "0x8086": ("Intel", "lib32-vulkan-intel")}


def run(cmd, timeout=20):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=dict(os.environ, LC_ALL="C"))
    except (OSError, subprocess.SubprocessError):
        return subprocess.CompletedProcess(cmd, 127, "", "")


def installed(*names):
    return run(["pacman", "-Q", *names]).returncode == 0


def check(cid, level, ru, en):
    return {"id": cid, "level": level, "ru": ru, "en": en}


def du(p):
    total = 0
    for root, _, files in os.walk(p):
        for f in files:
            try:
                total += os.lstat(os.path.join(root, f)).st_size
            except OSError:
                pass
    return total


def steam_roots():
    seen, out = set(), []
    for p in (HOME / ".local/share/Steam", HOME / ".steam/steam", HOME / ".steam/root",
              HOME / ".var/app/com.valvesoftware.Steam/.local/share/Steam"):
        if (p / "steamapps").is_dir():
            r = p.resolve()
            if r not in seen:
                seen.add(r)
                out.append(r)
    return out


def libraries():
    seen, out = set(), []
    for root in steam_roots():
        paths = [root]
        try:
            vdf = (root / "steamapps/libraryfolders.vdf").read_text(errors="replace")
            paths += [Path(m.replace("\\\\", "\\")) for m in re.findall(r'"path"\s+"([^"]+)"', vdf)]
        except OSError:
            pass
        for p in paths:
            sa = p / "steamapps"
            if sa.is_dir() and sa.resolve() not in seen:
                seen.add(sa.resolve())
                out.append(sa.resolve())
    return out


def games():
    out = []
    for sa in libraries():
        for acf in sorted(sa.glob("appmanifest_*.acf")):
            try:
                text = acf.read_text(errors="replace")
            except OSError:
                continue
            gid = re.search(r'"appid"\s+"(\d+)"', text)
            name = re.search(r'"name"\s+"([^"]*)"', text)
            if not gid or not name or TOOL_NAME.match(name.group(1)):
                continue
            gid = gid.group(1)
            out.append({"id": gid, "name": name.group(1), "lib": str(sa),
                        "prefix": (sa / "compatdata" / gid / "pfx").is_dir(),
                        "shaderBytes": du(sa / "shadercache" / gid)})
    out.sort(key=lambda g: g["name"].lower())
    return out


def protons():
    dirs = [r / "compatibilitytools.d" for r in steam_roots()] + [Path("/usr/share/steam/compatibilitytools.d")]
    names = set()
    for d in dirs:
        if d.is_dir():
            names |= {p.name for p in d.iterdir() if p.is_dir() and not p.name.startswith(".")}
    for sa in libraries():
        names |= {p.name for p in (sa / "common").glob("Proton*") if p.is_dir()}
    return sorted(names, key=str.lower)


def running(gid):
    """a process of this game is alive (Steam puts its id in the environment); read only"""
    keys = {f"SteamAppId={gid}".encode(), f"STEAM_COMPAT_APP_ID={gid}".encode()}
    for p in Path("/proc").iterdir():
        if not p.name.isdigit():
            continue
        try:
            env = (p / "environ").read_bytes().split(b"\0")
        except OSError:
            continue
        if keys & set(env):
            return True
    return False


def wanted():
    try:
        return [ln.strip() for ln in LIST.read_text().splitlines() if ln.strip() and not ln.lstrip().startswith("#")]
    except OSError:
        return []


def scan():
    checks = []
    pacman = shutil.which("pacman") is not None
    try:
        conf = Path("/etc/pacman.conf").read_text(errors="replace")
    except OSError:
        conf = ""
    if re.search(r"^\[multilib\]\s*$", conf, re.M):
        checks.append(check("multilib", "ok", "Репозиторий multilib подключён", "The multilib repository is on"))
    else:
        checks.append(check("multilib", "bad", "Нет репозитория multilib: Steam и 32-битные драйверы не поставятся",
                            "No multilib repository: Steam and the 32-bit drivers can't install"))
    vendors = set()
    for v in Path("/sys/class/drm").glob("card[0-9]*/device/vendor"):
        try:
            vendors.add(v.read_text().strip())
        except OSError:
            pass
    for v in sorted(vendors & GPU.keys()):
        who, pkg = GPU[v]
        if not pacman or installed(pkg):
            checks.append(check("lib32-" + who, "ok", f"32-битный драйвер {who} стоит", f"The 32-bit {who} driver is installed"))
        else:
            checks.append(check("lib32-" + who, "bad", f"Нет 32-битного драйвера {who} ({pkg}): Steam и многие игры не запустятся",
                                f"No 32-bit {who} driver ({pkg}): Steam and many games won't start"))
    if shutil.which("vulkaninfo"):
        out = run(["vulkaninfo", "--summary"], timeout=15)
        devs = sorted(set(re.findall(r"deviceName\s*=\s*(.+)", out.stdout)))
        real = [d for d in devs if not re.search(r"llvmpipe|lavapipe", d, re.I)]
        if real:
            checks.append(check("vulkan", "ok", "Vulkan работает: " + ", ".join(real), "Vulkan works: " + ", ".join(real)))
        elif devs:
            checks.append(check("vulkan", "bad", "Vulkan видит только программный рендер: драйвер видеокарты не подхватился",
                                "Vulkan sees only the software renderer: the video driver is not picked up"))
        else:
            checks.append(check("vulkan", "bad", "Vulkan не отвечает (vulkaninfo с ошибкой)", "Vulkan does not answer (vulkaninfo fails)"))
    else:
        checks.append(check("vulkan", "info", "Vulkan не проверен: нет vulkaninfo (пакет vulkan-tools)", "Vulkan not checked: no vulkaninfo (vulkan-tools)"))
    if pacman:
        for pkg, ru, en in (("gamemode", "gamemode (ускорение на время игры)", "gamemode (a boost while a game runs)"),
                            ("mangohud", "MangoHud (счётчик кадров)", "MangoHud (the frame counter)")):
            if installed(pkg):
                checks.append(check(pkg, "ok", ru + " стоит", en + " is installed"))
            else:
                checks.append(check(pkg, "info", "Нет " + ru, "No " + en))
    roots = steam_roots()
    if roots or (pacman and installed("steam")):
        checks.append(check("steam", "ok", "Steam стоит", "Steam is installed"))
    else:
        checks.append(check("steam", "warn", "Steam не установлен", "Steam is not installed"))
    pl = protons()
    if roots:
        if pl:
            checks.append(check("protons", "info", "Proton: " + ", ".join(pl), "Proton: " + ", ".join(pl)))
        else:
            checks.append(check("protons", "warn", "Не найдено ни одного Proton: игры для Windows не запустятся",
                                "No Proton found: Windows games won't start"))
    btrfs = run(["findmnt", "-no", "FSTYPE", "/"]).stdout.strip() == "btrfs"
    if not btrfs:
        checks.append(check("snapshots", "info", "Снимков системы нет: системный диск не btrfs", "No system snapshots: the system disk is not btrfs"))
    elif not Path("/etc/snapper/configs/root").exists():
        checks.append(check("snapshots", "warn", "Снимки системы выключены: сломанное обновление не откатить",
                            "System snapshots are off: a broken update can't be undone"))
    else:
        pac = pacman and installed("snap-pac")
        boot = pacman and (installed("limine-snapper-sync") or installed("grub-btrfs"))
        if pac and boot:
            checks.append(check("snapshots", "ok", "Снимок перед каждым обновлением, снимки в меню загрузки",
                                "A snapshot before every update, snapshots in the boot menu"))
        elif pac:
            checks.append(check("snapshots", "ok", "Снимок перед каждым обновлением (в меню загрузки их нет)",
                                "A snapshot before every update (not in the boot menu)"))
        else:
            checks.append(check("snapshots", "warn", "snapper настроен, но без snap-pac снимки перед обновлением не делаются",
                                "snapper is set up, but without snap-pac no snapshot comes before an update"))
    missing = []
    if pacman:
        want = wanted()
        missing = run(["pacman", "-T", *want]).stdout.split() if want else []
    edition = (STATE / "gaming").exists() or (pacman and not missing and bool(wanted()))
    return {"checks": checks, "games": [{k: g[k] for k in ("id", "name", "prefix", "shaderBytes")} for g in games()],
            "protons": pl, "edition": bool(edition), "missing": missing}


def done(ok, ru, en):
    print(json.dumps({"ok": ok, "ru": ru, "en": en}, ensure_ascii=False), flush=True)
    return 0 if ok else 1


def find_game(gid):
    if not re.fullmatch(r"\d+", gid or ""):
        return None
    return next((g for g in games() if g["id"] == gid), None)


def reset_prefix(gid):
    g = find_game(gid)
    if not g:
        return done(False, "Такой игры в Steam нет", "No such game in Steam")
    if running(gid):
        return done(False, f"{g['name']} сейчас запущена: сначала закрой её", f"{g['name']} is running: close it first")
    src = Path(g["lib"]) / "compatdata" / gid
    if not src.exists():
        return done(True, f"У {g['name']} нет префикса: сбрасывать нечего", f"{g['name']} has no prefix: nothing to reset")
    # the same library: a rename, not a copy of gigabytes
    dst = Path(g["lib"]) / "angelos-prefix-backups" / f"{gid}-{time.strftime('%Y%m%d-%H%M%S')}"
    dst.parent.mkdir(parents=True, exist_ok=True)
    try:
        src.rename(dst)
    except OSError as e:
        return done(False, f"Не вышло: {e}", f"Failed: {e}")
    return done(True, f"Префикс {g['name']} сброшен, старый — в {dst}. Steam создаст чистый при запуске",
                f"{g['name']}'s prefix is reset, the old one is in {dst}. Steam makes a clean one on the next start")


def clear_shaders(what):
    if what == "all":
        gs = games()
        if any(running(g["id"]) for g in gs):
            return done(False, "Идёт игра: сначала закрой её", "A game is running: close it first")
        dirs = [sa / "shadercache" for sa in libraries()]
        dirs += [CACHE / "nvidia/GLCache", CACHE / "mesa_shader_cache", CACHE / "mesa_shader_cache_db", CACHE / "radv_builtin_shaders"]
    else:
        g = find_game(what)
        if not g:
            return done(False, "Такой игры в Steam нет", "No such game in Steam")
        if running(what):
            return done(False, f"{g['name']} сейчас запущена: сначала закрой её", f"{g['name']} is running: close it first")
        dirs = [Path(g["lib"]) / "shadercache" / what]
    freed = 0
    for d in dirs:
        if d.is_dir() and not d.is_symlink():
            freed += du(d)
            shutil.rmtree(d, ignore_errors=True)
    mb = f"{freed / 1048576:.1f}"
    return done(True, f"Кэш шейдеров очищен ({mb} МБ). Первый запуск будет дольше: шейдеры соберутся заново",
                f"The shader cache is cleared ({mb} MB). The first start takes longer: the shaders build again")


def ge_proton():
    roots = steam_roots()
    if not roots:
        return done(False, "Steam не найден: сначала поставь и запусти его", "Steam not found: install and start it first")
    dest = roots[0] / "compatibilitytools.d"
    try:
        req = urllib.request.Request(GE_API, headers={"Accept": "application/vnd.github+json", "User-Agent": "angelOS"})
        rel = json.load(urllib.request.urlopen(req, timeout=20))
    except (OSError, ValueError) as e:
        return done(False, f"GitHub не ответил: {e}", f"GitHub did not answer: {e}")
    tag = rel.get("tag_name") or ""
    assets = {a.get("name"): a.get("browser_download_url") for a in rel.get("assets") or []}
    tar_name = next((n for n in assets if n and n.endswith(".tar.gz")), None)
    sum_name = next((n for n in assets if n and n.endswith(".sha512sum")), None)
    if not re.fullmatch(r"GE-Proton[\w.-]+", tag) or not tar_name or not sum_name:
        return done(False, "В релизе GE-Proton нет архива или его sha512", "The GE-Proton release has no archive or no sha512")
    if (dest / tag).is_dir():
        return done(True, f"{tag} уже стоит", f"{tag} is installed already")
    dest.mkdir(parents=True, exist_ok=True)
    part = dest / f".{tar_name}.part"
    try:
        want = urllib.request.urlopen(assets[sum_name], timeout=20).read().decode().split()[0].lower()
        h = hashlib.sha512()
        with urllib.request.urlopen(assets[tar_name], timeout=60) as r, open(part, "wb") as f:
            while chunk := r.read(1 << 20):
                h.update(chunk)
                f.write(chunk)
        if h.hexdigest() != want:
            return done(False, "sha512 архива не совпал с релизом: не ставлю", "The archive's sha512 does not match the release: not installed")
        with tarfile.open(part) as t:
            if any(not (m.name == tag or m.name.startswith(tag + "/")) for m in t.getmembers()):
                return done(False, "В архиве лишние пути: не ставлю", "The archive has stray paths: not installed")
            t.extractall(dest, filter="data")
    except (OSError, ValueError, tarfile.TarError) as e:
        shutil.rmtree(dest / tag, ignore_errors=True)
        return done(False, f"Не скачалось: {e}", f"Download failed: {e}")
    finally:
        part.unlink(missing_ok=True)
    return done(True, f"{tag} поставлен. Перезапусти Steam — он появится в выборе Proton у игры",
                f"{tag} is installed. Restart Steam: it shows up in a game's Proton list")


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "scan":
        print(json.dumps(scan(), ensure_ascii=False))
        return 0
    if cmd == "reset-prefix" and len(argv) == 3:
        return reset_prefix(argv[2])
    if cmd == "clear-shaders" and len(argv) == 3:
        return clear_shaders(argv[2])
    if cmd == "ge-proton":
        return ge_proton()
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
