#!/usr/bin/env python3
"""The game tuner: for each Steam game, which Proton and which launch options work best, and
why (services/GameTune, the note that pops up for a new game, Settings → Maintenance → Games).

usage: game-tune.py list                 JSON: Steam, its Proton builds, every installed game
                                         with what it runs now and what we suggest
       game-tune.py refresh              fetch what needs the network (anti-cheat list, which
                                         games are native), cached a week
       game-tune.py apply APPID [--proton NAME] [--options LINE]
                                         write them to Steam (NAME "" = Steam's own choice,
                                         LINE "" = none); while Steam runs it would overwrite
                                         them on exit, so they wait (exit 3) until it is closed
       game-tune.py pending              apply what waits, if Steam is closed now
       game-tune.py undo APPID           put back what the last apply replaced
       game-tune.py bench start APPID P1,P2[,…]   compare Protons on this machine (MangoHud logs)
       game-tune.py bench next           read the last run's log, switch to the next Proton
       game-tune.py bench finish [KEEP]  end: keep that Proton (or put back what it had)
       game-tune.py seen APPID           its note was shown (list marks new games "fresh")
       game-tune.py context APPID        a Markdown page about the game for the helper agent

Where the suggestion comes from, first that has one: data/game-profiles.json (checked by hand),
then ProtonDB's reports (data/protondb-digest.json.gz, scripts/protondb-digest.py: the Proton
that works for most, the launch options many used on the same kind of video card, harmless
ones only — scripts/gametune_safe.py), then the default: Proton-CachyOS, whose protonfixes
mend hundreds of games by themselves. Anti-cheat from AreWeAntiCheatYet. Tests: STEAM_ROOT
points at a fake Steam (never the real one).
"""
import gzip
import json
import os
import re
import shlex
import shutil
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gametune_safe import safe  # noqa: E402

SHELL = Path(__file__).resolve().parent.parent
HOME = Path.home()
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache") / "angelos/game-tune"
STATE = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state") / "angelos/game-tune"
DIGEST = SHELL / "data/protondb-digest.json.gz"
PROFILES = SHELL / "data/game-profiles.json"
AWACY = "https://raw.githubusercontent.com/AreWeAntiCheatYet/AreWeAntiCheatYet/HEAD/games.json"
WEEK = 7 * 86400
DEFAULT_TOOLS = ("proton-cachyos-slr", "proton-cachyos")
# the switch: one compatibility tool Steam keeps for a game while Protons are compared; each run it
# starts the one named in STATE/switch/<appid> (no Steam restart between runs)
SWITCH = "angelos-proton"
RUNTIME = "4183110"          # Steam Linux Runtime 4, what every current Proton runs in
# not games: Steam's own runtimes and Proton builds show up as apps
NOT_GAME = re.compile(r"^(Proton|Steam Linux Runtime|Steamworks Common|Steam Audio|SteamVR)\b", re.I)
# what we add or leave out ourselves (the overlay is a taste, gamemode is ours to add)
OWN_WRAPPERS = {"mangohud", "gamemoderun", "game-performance"}
# ways round a broken start that cost frames: offered as "if it doesn't start", never by default
FALLBACK = re.compile(r"\b(PROTON_USE_WINED3D|PROTON_NO_ESYNC|PROTON_NO_FSYNC|PROTON_NO_D3D1[012]|PROTON_USE_D9VK)=|(^|\s)-(dx11|d3d11|dx12|vulkan|opengl)\b")


# ---------------------------------------------------------------- Valve's text format
def vdf_loads(text):
    """KeyValues text: "key" "value" | "key" { … }, // comments, \\ escapes"""
    root, stack, key = {}, [], None
    cur = root
    for m in VDF_TOKEN.finditer(text):
        kind = m.lastgroup
        if kind == "comment":
            continue
        if kind == "open":
            new = {}
            cur[key if key is not None else ""] = new
            stack.append(cur)
            cur, key = new, None
        elif kind == "close":
            cur = stack.pop() if stack else root
            key = None
        else:
            word = m.group("quoted") if kind == "quoted" else m.group("bare")
            if kind == "quoted":
                word = word.replace('\\"', '"').replace("\\\\", "\\")
            if key is None:
                key = word
            else:
                cur[key] = word
                key = None
    return root


VDF_TOKEN = re.compile(r'(?P<comment>//[^\n]*)|"(?P<quoted>(?:[^"\\]|\\.)*)"|(?P<open>\{)|(?P<close>\})|(?P<bare>[^\s{}"]+)')


def vdf_dumps(d, depth=0):
    out = []
    pad = "\t" * depth
    for k, v in d.items():
        k = str(k).replace("\\", "\\\\").replace('"', '\\"')
        if isinstance(v, dict):
            out.append('%s"%s"\n%s{\n%s%s}\n' % (pad, k, pad, vdf_dumps(v, depth + 1), pad))
        else:
            v = str(v).replace("\\", "\\\\").replace('"', '\\"')
            out.append('%s"%s"\t\t"%s"\n' % (pad, k, v))
    return "".join(out)


def vdf_load(path):
    try:
        return vdf_loads(Path(path).read_text(encoding="utf-8", errors="replace"))
    except OSError:
        return {}


def dig(d, *keys, make=False):
    for k in keys:
        nxt = None
        for kk in d:
            if kk.lower() == k.lower():
                nxt = d[kk]
                break
        if not isinstance(nxt, dict):
            if not make:
                return {}
            nxt = d[k] = {}
        d = nxt
    return d


# ---------------------------------------------------------------- Steam on this machine
def steam_root():
    env = os.environ.get("STEAM_ROOT")
    if env:
        return Path(env)
    for p in (HOME / ".local/share/Steam", HOME / ".steam/steam",
              HOME / ".var/app/com.valvesoftware.Steam/.local/share/Steam"):
        if (p / "steamapps").is_dir():
            return p.resolve()
    return None


def steam_running():
    if os.environ.get("STEAM_ROOT"):
        return os.environ.get("STEAM_RUNNING") == "1"
    for p in Path("/proc").iterdir():
        if p.name.isdigit():
            try:
                if (p / "comm").read_text().strip() == "steam":
                    return True
            except OSError:
                pass
    return False


def libraries(root):
    libs = [root]
    for v in dig(vdf_load(root / "steamapps/libraryfolders.vdf"), "libraryfolders").values():
        if isinstance(v, dict) and v.get("path") and Path(v["path"]) not in libs:
            libs.append(Path(v["path"]))
    return libs


def games(root):
    out = {}
    for lib in libraries(root):
        for m in sorted((lib / "steamapps").glob("appmanifest_*.acf")):
            a = dig(vdf_load(m), "AppState")
            name, appid = a.get("name", ""), a.get("appid", "")
            if not appid or NOT_GAME.match(name):
                continue
            flags = int(a.get("StateFlags", "0") or 0)
            out[appid] = {"appid": appid, "name": name, "size": int(a.get("SizeOnDisk", "0") or 0),
                          "installed": bool(flags & 4) and not flags & 1024, "dir": str(lib / "steamapps/common" / a.get("installdir", ""))}
    return out


def tools(root):
    """the Proton builds Steam can pick: internal name -> what to show, where it lives and whether
    the switch (bench) can run it: a plain "/proton %verb%" in the same runtime as the switch"""
    found = {}
    dirs = [root / "compatibilitytools.d", Path("/usr/share/steam/compatibilitytools.d"),
            Path("/usr/local/share/steam/compatibilitytools.d")]
    for d in dirs:
        for f in sorted(d.glob("*/compatibilitytool.vdf")):
            for name, t in dig(vdf_load(f), "compatibilitytools", "compat_tools").items():
                if name == SWITCH:
                    continue
                disp = t.get("display_name", "") if isinstance(t, dict) else ""
                if not disp or "substitute" in disp or "%" in disp:
                    disp = f.parent.name
                found[name] = tool_entry(name, disp, f.parent, kind_of(name))
    for lib in libraries(root):
        for p in sorted((lib / "steamapps/common").glob("Proton*")):
            m = re.match(r"Proton (\d+)\.\d+$", p.name)
            name = ("proton_experimental" if "Experimental" in p.name else "proton_hotfix" if "Hotfix" in p.name
                    else "proton_%s" % m.group(1) if m else "")
            if name:
                found[name] = tool_entry(name, p.name, p, "experimental" if "Experimental" in p.name else "official")
    return found


def tool_entry(name, display, path, kind):
    m = dig(vdf_load(path / "toolmanifest.vdf"), "manifest")
    switchable = m.get("commandline", "").split() == ["/proton", "%verb%"] and m.get("require_tool_appid") == RUNTIME
    return {"name": name, "display": display, "kind": kind, "dir": str(path), "switchable": switchable}


def kind_of(name):
    n = name.lower()
    words = re.split(r"[-_ .]", n)
    for k in ("cachyos", "wineland", "sarek", "tkg", "gdk", "luxtorpeda", "boxtron", "roberta"):
        if k in n:
            return k
    if "em" in words or n.startswith("proton-em"):
        return "em"
    if "ge" in words or n.startswith("ge-proton") or "proton-ge" in n:
        return "ge"
    return "experimental" if "experimental" in n else "official" if n.startswith("proton_") else "other"


def user_config(root):
    """the localconfig.vdf of the account that logged in last"""
    users = dig(vdf_load(root / "config/loginusers.vdf"), "users")
    best = None
    for sid, u in users.items():
        if isinstance(u, dict) and (u.get("MostRecent") == "1" or best is None):
            best = sid
            if u.get("MostRecent") == "1":
                break
    if best and best.isdigit():
        f = root / "userdata" / str(int(best) - 76561197960265728) / "config/localconfig.vdf"
        if f.exists():
            return f
    cands = sorted(root.glob("userdata/*/config/localconfig.vdf"), key=lambda p: p.stat().st_mtime)
    return cands[-1] if cands else None


def current(root):
    mapping = dig(vdf_load(root / "config/config.vdf"), "InstallConfigStore", "Software", "Valve", "Steam", "CompatToolMapping")
    lc = user_config(root)
    apps = dig(vdf_load(lc), "UserLocalConfigStore", "Software", "Valve", "Steam", "apps") if lc else {}
    proton = {k: v.get("name", "") for k, v in mapping.items() if isinstance(v, dict)}
    options = {k: v.get("LaunchOptions", "") for k, v in apps.items() if isinstance(v, dict)}
    return proton, options


# ---------------------------------------------------------------- what we know about games
def load_json(path, default):
    try:
        if str(path).endswith(".gz"):
            with gzip.open(path, "rt", encoding="utf-8") as f:
                return json.load(f)
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return default


def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": "angelOS game-tune"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def anticheat():
    """steam appid -> {status, anticheats} (AreWeAntiCheatYet)"""
    data = load_json(CACHE / "awacy.json", [])
    out = {}
    for g in data if isinstance(data, list) else []:
        sid = str((g.get("storeIds") or {}).get("steam") or "")
        if sid:
            out[sid] = {"status": g.get("status", ""), "anticheats": g.get("anticheats") or [], "native": bool(g.get("native"))}
    return out


def refresh(root):
    CACHE.mkdir(parents=True, exist_ok=True)
    done = {}
    f = CACHE / "awacy.json"
    if not f.exists() or time.time() - f.stat().st_mtime > WEEK:
        try:
            raw = fetch(AWACY)
            json.loads(raw)
            f.write_bytes(raw)
            done["anticheat"] = True
        except Exception as e:  # noqa: BLE001 — the network: the old copy stays
            done["anticheat"] = "error: %s" % e
    # native Linux builds: the store says, once per game
    nat = load_json(CACHE / "native.json", {})
    for appid in games(root) if root else {}:
        if appid in nat:
            continue
        try:
            d = json.loads(fetch("https://store.steampowered.com/api/appdetails?appids=%s&filters=platforms" % appid))
            nat[appid] = bool(((d.get(appid) or {}).get("data") or {}).get("platforms", {}).get("linux"))
        except Exception:  # noqa: BLE001 — asked again next time
            continue
        time.sleep(0.4)
    (CACHE / "native.json").write_text(json.dumps(nat))
    done["native"] = len(nat)
    return done


def which(name):
    return any(Path(p, name).exists() for p in os.environ.get("PATH", "/usr/bin").split(":"))


def vendor():
    for v in Path("/sys/class/drm").glob("card[0-9]*/device/vendor"):
        try:
            x = v.read_text().strip()
        except OSError:
            continue
        if x == "0x10de":
            return "nvidia"
        if x == "0x1002":
            return "amd"
    return "intel" if list(Path("/sys/class/drm").glob("card[0-9]*")) else "other"


def tier(d):
    """ProtonDB-like: how many of those who tried say it works"""
    if not d or not d.get("n"):
        return ""
    ok = d["ok"] / d["n"]
    oob = d.get("oob", 0)
    if d["n"] < 3:
        return "pending"
    if ok >= 0.9 and oob >= 0.75:
        return "platinum"
    if ok >= 0.85:
        return "gold"
    if ok >= 0.65:
        return "silver"
    if ok >= 0.4:
        return "bronze"
    return "borked"


def strip_own(line):
    """the community's line without the wrappers we decide ourselves"""
    words = [w for w in line.split() if w not in OWN_WRAPPERS]
    return "" if words == ["%command%"] else " ".join(words)


def suggest(appid, game, avail, d, prof, ac, native, gpu, have_gamemode):
    # ---- Proton
    proton, pwhy = "", ""
    if native:
        pwhy = "native"
    elif prof.get("proton"):
        proton, pwhy = prof["proton"], "profile"
    else:
        pv = (d or {}).get("pv") or {}
        total = sum(pv.values())
        st = (ac or {}).get("status", "")
        valve = pv.get("official", 0) + pv.get("experimental", 0)
        if ac and st in ("Supported", "Running") and total and valve / total > 0.8 and (d or {}).get("ac"):
            proton, pwhy = "proton_experimental", "anticheat"
        else:
            proton = next((t for t in DEFAULT_TOOLS if t in avail), "")
            pwhy = "default"
            if not proton:
                proton = next((n for n, t in avail.items() if t["kind"] == "ge"), "")
                pwhy = "ge" if proton else "steam"
    # ---- launch options
    parts, owhy, fallbacks = [], "", []
    base = prof.get("options")
    if base and safe(base):
        owhy = "profile"
    else:
        base = ""
        lo = ((d or {}).get("lo") or {}).get(gpu) or []
        need = max(3, int(((d or {}).get("ok") or 0) * 0.02))
        for line, count in lo:
            s = strip_own(line)
            if not s or count < need:
                continue
            if FALLBACK.search(s):
                fallbacks.append([s, count])
            elif not base:
                base, owhy = s, "protondb:%d" % count
    if have_gamemode and not native:
        parts.append("gamemoderun")
    line = base
    if parts:
        if not line:
            line = " ".join(parts) + " %command%"
        elif "%command%" in line:
            pre, post = line.split("%command%", 1)
            line = (pre + " ".join(parts) + " %command%" + post).strip()
        else:
            line = " ".join(parts) + " %command% " + line
    line = re.sub(r"\s+", " ", line).strip()
    return {"proton": proton, "protonWhy": pwhy, "options": line, "optionsWhy": owhy,
            "fallbacks": fallbacks, "tips": prof.get("tips") or []}


# ---------------------------------------------------------------- mods
# loaders that hook in through a DLL of their own: Wine must take the game's copy first
# ("dll=n,b"), or the mod is silently off. (name, files/dirs that tell it, the DLL, a launch flag)
MOD_LOADERS = [
    ("BepInEx", ("BepInEx", "doorstop_config.ini"), "winhttp", ""),
    ("MelonLoader", ("MelonLoader",), "version", ""),
    ("Lovely (Steamodded)", ("version.dll",), "version", ""),
    ("Cyber Engine Tweaks", ("bin/x64/plugins/cyber_engine_tweaks",), "version", ""),
    ("RED4ext", ("red4ext",), "winmm", ""),
    ("REDmod", ("tools/redmod",), "", "-modded"),
    ("UE4SS", ("ue4ss", "Binaries/Win64/ue4ss", "Binaries/Win64/UE4SS-settings.ini"), "dwmapi", ""),
    ("Script Hook V", ("ScriptHookV.dll",), "dinput8", ""),
    ("ASI Loader", ("scripts/*.asi", "plugins/*.asi"), "dinput8", ""),
    ("OptiScaler", ("OptiScaler.ini", "bin/x64/OptiScaler.ini"), "dxgi", ""),
    ("ReShade", ("ReShade.ini", "reshade-shaders", "bin/x64/ReShade.ini"), "dxgi", ""),
]
PROXIES = ("winhttp", "version", "winmm", "dxgi", "d3d9", "d3d11", "dinput8", "dwmapi", "dsound", "xinput1_3")


def overrides(line):
    """the DLLs WINEDLLOVERRIDES names in a launch line"""
    m = re.search(r'WINEDLLOVERRIDES=("[^"]*"|\S+)', line or "")
    if not m:
        return set()
    out = set()
    for part in m.group(1).strip('"').split(";"):
        out.update(x.strip().lower().removesuffix(".dll") for x in part.split("=")[0].split(",") if x.strip())
    return out


def mods(game, line):
    """the mod loaders in the game's folder: name, the DLL Wine must take from it, on or not"""
    d = Path(game.get("dir", ""))
    if not d.is_dir():
        return []
    have = overrides(line)
    out = []
    for name, marks, dll, flag in MOD_LOADERS:
        hits = [m for m in marks if any(d.glob(m))] if any("*" in m for m in marks) else [m for m in marks if (d / m).exists()]
        if not hits:
            continue
        if name == "Lovely (Steamodded)" and not ((d / "Mods").is_dir() or (d / "mods").is_dir()):
            continue
        if name == "REDmod" and not (d / "mods").is_dir():
            continue
        on = (not dll or dll in have) and (not flag or flag in (line or "").split())
        out.append({"name": name, "found": hits[0], "dll": dll, "flag": flag, "on": on})
    # a folder of mods the game loads itself (Teardown, Balatro's Mods for Lovely…)
    if not out and any((d / m).is_dir() for m in ("mods", "Mods")):
        out.append({"name": "mods", "found": "mods", "dll": "", "flag": "", "on": True})
    # r2modman / Thunderstore start BepInEx from their own profile through the launch line
    if "--doorstop-enable" in (line or "") and not any(m["name"] == "BepInEx" for m in out):
        out.append({"name": "BepInEx (r2modman)", "found": "launch options", "dll": "winhttp", "flag": "", "on": True})
    return out


def with_need(line, dll, flag):
    """the launch line with one more DLL Wine takes from the game, and/or a flag after %command%"""
    words = line.split() if line else []
    if "%command%" not in words:
        words = ["%command%"] + words
    if dll and dll not in overrides(" ".join(words)):
        for i, w in enumerate(words):
            if w.startswith("WINEDLLOVERRIDES="):
                v = w.split("=", 1)[1].strip('"')
                words[i] = 'WINEDLLOVERRIDES="%s;%s=n,b"' % (v, dll)
                break
        else:
            words.insert(0, 'WINEDLLOVERRIDES="%s=n,b"' % dll)
    if flag and flag not in words:
        words.append(flag)
    return " ".join(words)


def merge(now, rec):
    """what the game runs now (the user's or a mod's own variables, wrappers, flags) with our
    suggestion added: nothing of theirs is dropped, a variable both name takes ours, DLL overrides add up"""
    if not now:
        return rec
    if not rec:
        return now
    try:
        a, b = shlex.split(now), shlex.split(rec)
    except ValueError:
        return now

    def parts(words):
        if "%command%" not in words:
            return [], words
        i = words.index("%command%")
        return words[:i], words[i + 1:]
    pa, aa = parts(a)
    pb, ab = parts(b)
    env = {}
    order = []
    for w in pa + pb:
        if "=" in w and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w):
            k, v = w.split("=", 1)
            if k == "WINEDLLOVERRIDES" and k in env:
                have = overrides("WINEDLLOVERRIDES=" + env[k])
                add = [x for x in v.split(";") if x and not (overrides("WINEDLLOVERRIDES=" + x) <= have)]
                v = ";".join([env[k]] + add)
            if k not in env:
                order.append(k)
            env[k] = v
    wraps = []
    for w in pa + pb:
        if not ("=" in w and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w)) and w not in wraps:
            wraps.append(w)
    args = list(aa) + [w for w in ab if w not in aa]
    pre = [k + "=" + (env[k] if re.match(r"^[A-Za-z0-9_.,:=+%@/-]+$", env[k]) else '"%s"' % env[k].replace('"', "")) for k in order]
    return " ".join(pre + wraps + ["%command%"] + args)


def listing():
    root = steam_root()
    if not root:
        return {"steam": False, "games": []}
    avail = tools(root)
    proton_now, opts_now = current(root)
    digest = load_json(DIGEST, {})
    apps = digest.get("apps") or {}
    profiles = load_json(PROFILES, {}).get("games", {})
    ac = anticheat()
    native = load_json(CACHE / "native.json", {})
    gpu = vendor()
    have_gamemode = which("gamemoderun")
    undo = load_json(STATE / "undo.json", {})
    pending = load_json(STATE / "pending.json", {})
    found = games(root)
    # a game installed since the last look gets its note; the first look knows them all already
    known = load_json(STATE / "known.json", None)
    if known is None:
        STATE.mkdir(parents=True, exist_ok=True)
        known = [a for a, g in found.items() if g["installed"]]
        (STATE / "known.json").write_text(json.dumps(known))
    out = []
    for appid, g in sorted(found.items(), key=lambda kv: kv[1]["name"].lower()):
        d = apps.get(appid)
        is_native = native.get(appid, (ac.get(appid) or {}).get("native", False))
        rec = suggest(appid, g, avail, d, profiles.get(appid, {}), ac.get(appid), is_native, gpu, have_gamemode)
        # ours goes on top of what runs now: a mod's overrides and the user's own flags stay
        now_opts = opts_now.get(appid, "")
        found_mods = mods(g, now_opts)
        rec["options"] = merge(now_opts, rec["options"])
        for m in found_mods:
            if m["on"]:
                rec["options"] = with_need(rec["options"], m["dll"], m["flag"])
            else:
                m["enable"] = with_need(rec["options"], m["dll"], m["flag"])
        rec["mods"] = found_mods
        out.append(dict(g, now={"proton": proton_now.get(appid, ""), "options": opts_now.get(appid, "")},
                        rec=rec, rating={"tier": tier(d), "n": (d or {}).get("n", 0), "ok": (d or {}).get("ok", 0),
                                         "oob": (d or {}).get("oob")},
                        anticheat=ac.get(appid), native=is_native, undo=appid in undo, pending=appid in pending,
                        fresh=g["installed"] and appid not in known))
    return {"steam": True, "root": str(root), "running": steam_running(), "default": proton_now.get("0", ""),
            "tools": sorted(avail.values(), key=lambda t: t["display"].lower()), "gpu": gpu,
            "digest": {"built": digest.get("built", ""), "source": digest.get("source", "")}, "games": out,
            "bench": load_json(STATE / "bench.json", None), "benchHistory": load_json(STATE / "bench-history.json", {}),
            "benchDir": str(STATE / "bench"), "mangohud": which("mangohud"), "protonplus": which("protonplus")}


# ---------------------------------------------------------------- writing to Steam
def write_vdf(path, data):
    path = Path(path)
    bak = path.with_name(path.name + ".angelos-bak")
    if not bak.exists() and path.exists():
        bak.write_bytes(path.read_bytes())
    tmp = path.with_name(path.name + ".angelos-tmp")
    tmp.write_text(vdf_dumps(data), encoding="utf-8")
    tmp.replace(path)


def set_values(root, appid, proton=None, options=None):
    """write; returns what was there before"""
    before = {}
    if proton is not None:
        cfg = vdf_load(root / "config/config.vdf")
        m = dig(cfg, "InstallConfigStore", "Software", "Valve", "Steam", "CompatToolMapping", make=True)
        before["proton"] = (m.get(appid) or {}).get("name", "") if isinstance(m.get(appid), dict) else ""
        if proton:
            # "0" is the default for every game (Steam's own priority for it), the rest per game
            m[appid] = {"name": proton, "config": "", "priority": "75" if appid == "0" else "250"}
        else:
            m.pop(appid, None)
        write_vdf(root / "config/config.vdf", cfg)
    if options is not None:
        lc = user_config(root)
        if not lc:
            raise RuntimeError("no Steam account here yet (start Steam once)")
        cfg = vdf_load(lc)
        apps = dig(cfg, "UserLocalConfigStore", "Software", "Valve", "Steam", "apps", make=True)
        app = apps.setdefault(appid, {})
        before["options"] = app.get("LaunchOptions", "")
        if options:
            app["LaunchOptions"] = options
        else:
            app.pop("LaunchOptions", None)
        write_vdf(lc, cfg)
    return before


def apply(appid, proton, options, trusted=False):  # noqa: ARG001 — kept for the bench
    root = steam_root()
    if not root:
        return {"ok": False, "error": "no Steam"}, 1
    # the line is what the user saw and approved (ProtonDB's lines were filtered on the way in):
    # only one line, as Steam keeps it
    if options and ("\n" in options or len(options) > 2000):
        return {"ok": False, "error": "launch options: one line, please"}, 1
    STATE.mkdir(parents=True, exist_ok=True)
    if steam_running():
        pending = load_json(STATE / "pending.json", {})
        pending[appid] = {"proton": proton, "options": options}
        (STATE / "pending.json").write_text(json.dumps(pending))
        return {"ok": True, "pending": True}, 3
    before = set_values(root, appid, proton, options)
    undo = load_json(STATE / "undo.json", {})
    undo.setdefault(appid, before)
    (STATE / "undo.json").write_text(json.dumps(undo))
    return {"ok": True, "applied": True}, 0


def apply_pending():
    pending = load_json(STATE / "pending.json", {})
    if not pending or steam_running():
        return {"ok": True, "left": len(pending)}
    root = steam_root()
    undo = load_json(STATE / "undo.json", {})
    for appid, p in list(pending.items()):
        before = set_values(root, appid, p.get("proton"), p.get("options"))
        undo.setdefault(appid, before)
        pending.pop(appid)
    (STATE / "undo.json").write_text(json.dumps(undo))
    (STATE / "pending.json").write_text(json.dumps(pending))
    return {"ok": True, "left": 0}


def undo_app(appid):
    root = steam_root()
    undo = load_json(STATE / "undo.json", {})
    if appid not in undo:
        return {"ok": False, "error": "nothing to undo"}, 1
    if steam_running():
        return {"ok": False, "error": "steam running"}, 3
    b = undo.pop(appid)
    set_values(root, appid, b.get("proton"), b.get("options"))
    (STATE / "undo.json").write_text(json.dumps(undo))
    return {"ok": True}, 0


CONF_EXT = {".ini", ".cfg", ".json", ".xml", ".toml", ".yaml", ".yml", ".conf"}
# game data that only looks like settings
CONF_SKIP = re.compile(r"/(Content|Paks|StreamingAssets|archive|assets|data|locale|localization|lang|Movies|"
                       r"shadercache|logs?|Temp|Microsoft|Crashes|CrashDumps|__pycache__)/", re.I)
SECRETISH = re.compile(r"token|auth|login|account|passw|credential|secret|session|cookie|license|steam_api", re.I)


def config_files(root, g):
    """the game's and its mods' settings files: mod loaders' first, then the game's folder and its
    own Wine prefix (Documents, AppData, Saved Games: the prefix is this game's alone)"""
    seen, out = set(), []

    def take(p):
        try:
            ok = (p.suffix.lower() in CONF_EXT and p.is_file() and p.stat().st_size < 256 * 1024
                  and not SECRETISH.search(p.name) and p not in seen)
        except OSError:
            return False
        if ok:
            seen.add(p)
            out.append(p)
        return ok

    def walk(base, depth, limit):
        n = 0
        for dirpath, dirs, names in os.walk(base):
            rel = Path(dirpath).relative_to(base)
            if len(rel.parts) >= depth or CONF_SKIP.search("/" + str(rel) + "/"):
                dirs[:] = []
            for name in sorted(names):
                if n >= limit:
                    return
                n += take(Path(dirpath) / name)
    d = Path(g["dir"])
    for sub in ("BepInEx/config", "bin/x64/plugins/cyber_engine_tweaks", "red4ext", "ue4ss", "Binaries/Win64/ue4ss",
                "MelonLoader", "UserData"):
        if (d / sub).is_dir():
            walk(d / sub, 4, 40)
    for f in ("ReShade.ini", "OptiScaler.ini", "doorstop_config.ini", "bin/x64/ReShade.ini", "bin/x64/OptiScaler.ini"):
        take(d / f)
    # r2modman / Thunderstore keep BepInEx in their own profiles (a folder named like the game)
    key = re.sub(r"[^a-z0-9]", "", g["name"].lower())
    for mm in (HOME / ".config/r2modmanPlus-local", HOME / ".config/Thunderstore Mod Manager/DataFolder"):
        for game_dir in (mm.iterdir() if mm.is_dir() else []):
            if re.sub(r"[^a-z0-9]", "", game_dir.name.lower()) == key:
                for prof in sorted((game_dir / "profiles").glob("*/BepInEx/config")):
                    walk(prof, 2, 25)
    if d.is_dir():
        walk(d, 2, 30)
    user = root / "steamapps/compatdata" / g["appid"] / "pfx/drive_c/users/steamuser"
    for sub in ("Documents", "AppData/Local", "AppData/LocalLow", "AppData/Roaming", "Saved Games"):
        if (user / sub).is_dir():
            walk(user / sub, 6, 40)
    return out


def backup_configs(files, appid):
    """every settings file copied before the helper touches anything: STATE/backups/<appid>-<time>"""
    if not files:
        return None
    # the last five copies of a game are kept
    for old in sorted((STATE / "backups").glob(appid + "-*"))[:-4]:
        shutil.rmtree(old, ignore_errors=True)
    dst = STATE / "backups" / ("%s-%s" % (appid, time.strftime("%Y%m%d-%H%M%S")))
    for f in files:
        t = dst / str(f).lstrip("/")
        t.parent.mkdir(parents=True, exist_ok=True)
        try:
            t.write_bytes(f.read_bytes())
        except OSError:
            continue
    return dst


def context(appid):
    data = listing()
    g = next((x for x in data["games"] if x["appid"] == appid), None)
    if not g:
        return "", 1
    d = (load_json(DIGEST, {}).get("apps") or {}).get(appid, {})
    lines = ["# %s (Steam %s)" % (g["name"], appid), "",
             "Видеокарта: %s. Proton по умолчанию в Steam: %s." % (data["gpu"], data["default"] or "Steam решает сам"),
             "Сейчас у игры: Proton «%s», параметры запуска «%s»." % (g["now"]["proton"] or "по умолчанию", g["now"]["options"] or "нет"),
             "Установленные Proton: " + ", ".join("%s (%s)" % (t["display"], t["name"]) for t in data["tools"]),
             "", "## ProtonDB (последние 2 года)", json.dumps(d, ensure_ascii=False),
             "", "## Античит (AreWeAntiCheatYet)", json.dumps(g.get("anticheat"), ensure_ascii=False),
             "", "## Моды в папке игры (%s)" % g["dir"],
             json.dumps(g["rec"].get("mods") or [], ensure_ascii=False),
             "Моды, что цепляются через свою DLL, работают, только если Wine берёт её из игры "
             "(WINEDLLOVERRIDES=\"dll=n,b\"). Не убирай такие оверрайды и флаги вроде -modded из параметров "
             "запуска: сломаешь моды. Новое добавляй к тому, что есть. Если я хочу включить мод — помоги: "
             "нужный оверрайд, загрузчик (BepInEx, CET, RED4ext, UE4SS, ReShade, OptiScaler…), его конфиг в папке игры. "
             "Файлы модов не удаляй: отключай переименованием или переносом в бэкап.",
             "", "## Что предлагает angelOS", json.dumps(g["rec"], ensure_ascii=False),
             "", "Применять настройки только через `%s apply %s --proton NAME --options LINE` "
                 "(пишет в Steam сам, помнит старое; `undo %s` возвращает)." % (Path(__file__).resolve(), appid, appid)]
    # the game's and its mods' settings, copied aside first, the small ones in full: the helper
    # needn't ask what is in them, and nothing it changes is lost
    files = config_files(steam_root(), g)
    bak = backup_configs(files, appid)
    lines += ["", "## Файлы настроек игры и модов (%d)" % len(files),
              ("Копия всех, снятая перед тобой: %s (вернуть — скопировать обратно по тому же пути)." % bak) if bak
              else "Файлов настроек не нашлось.",
              "Правь в них только нужные ключи: файл целиком не переписывай и не удаляй, перед правкой скажи, что меняешь."]
    lines += ["- %s" % f for f in files]
    budget = 120 * 1024
    for f in sorted(files, key=lambda x: x.stat().st_size):
        try:
            text = f.read_text(errors="replace")
        except OSError:
            continue
        if len(text) > 16 * 1024 or len(text) > budget:
            continue
        budget -= len(text)
        lines += ["", "### " + str(f), "```", text.rstrip(), "```"]
    log = HOME / ("steam-%s.log" % appid)
    if log.is_file():
        lines += ["", "## Лог Proton (%s, конец)" % log, "```"] + log.read_text(errors="replace").splitlines()[-300:] + ["```"]
    else:
        lines += ["", "Лога Proton нет. Нужен — добавь в параметры запуска PROTON_LOG=1 и запусти игру: ~/steam-%s.log." % appid]
    return "\n".join(lines) + "\n", 0


# ---------------------------------------------------------------- comparing Protons (bench)
# Steam keeps one tool for the game, the switch; between runs only STATE/switch/<appid> changes.
# MangoHud writes the frames (no overlay) once Shift+F2 is pressed, for BENCH_SECONDS; after the
# game closes `bench next` reads the log and moves to the next Proton. The runtime container sees
# $HOME and /usr/share/steam (checked with SteamLinuxRuntime_4/run), so the switch finds them all.
BENCH_SECONDS = 60
SWITCH_SCRIPT = """#!/bin/sh
# angelOS game tuner (scripts/game-tune.py bench): runs the Proton chosen for this game's run
id="${SteamAppId:-${STEAM_COMPAT_APP_ID:-0}}"
f="${XDG_STATE_HOME:-$HOME/.local/state}/angelos/game-tune/switch/$id"
dir="$(cat "$f" 2>/dev/null)"
[ -n "$dir" ] && [ -x "$dir/proton" ] || dir="$(cat "${f%/*}/default" 2>/dev/null)"
[ -n "$dir" ] && [ -x "$dir/proton" ] || { echo "angelos-proton: no Proton chosen for $id" >&2; exit 1; }
exec "$dir/proton" "$@"
"""


def install_switch(root):
    """the switch as a compatibility tool of Steam's; True when it was not there (Steam sees a new
    tool only after a restart)"""
    d = root / "compatibilitytools.d" / SWITCH
    new = not (d / "compatibilitytool.vdf").exists()
    d.mkdir(parents=True, exist_ok=True)
    (d / "compatibilitytool.vdf").write_text(vdf_dumps({"compatibilitytools": {"compat_tools": {SWITCH: {
        "install_path": ".", "display_name": "angelOS: Proton comparison", "from_oslist": "windows", "to_oslist": "linux"}}}}))
    (d / "toolmanifest.vdf").write_text(vdf_dumps({"manifest": {
        "version": "2", "commandline": "/angelos-proton %verb%", "require_tool_appid": RUNTIME,
        "use_sessions": "1", "compatmanager_layer_name": "proton"}}))
    (d / "angelos-proton").write_text(SWITCH_SCRIPT)
    (d / "angelos-proton").chmod(0o755)
    return new


def frames(path):
    """frame times (ms) of a MangoHud log: its CSV has a system header, then fps,frametime,…"""
    import csv
    with open(path, newline="", errors="replace") as f:
        rows = list(csv.reader(f))
    for i, r in enumerate(rows):
        cols = [c.strip().lower() for c in r]
        if "frametime" in cols and "fps" in cols:
            k = cols.index("frametime")
            out = []
            for row in rows[i + 1:]:
                try:
                    v = float(row[k])
                except (ValueError, IndexError):
                    continue
                if 0 < v < 5000:
                    out.append(v)
            return out
    return []


def stats(ft, skip_ms=3000):
    """average FPS, the 1 % and 0.1 % lows (the worst frames' own average), steadiness"""
    t, i = 0.0, 0
    while i < len(ft) and t < skip_ms:
        t += ft[i]
        i += 1
    ft = ft[i:]
    if len(ft) < 100:
        return None
    total = sum(ft)
    worst = sorted(ft, reverse=True)

    def low(share):
        n = max(1, int(len(worst) * share))
        return round(1000 * n / sum(worst[:n]), 1)
    mean = total / len(ft)
    sd = (sum((x - mean) ** 2 for x in ft) / len(ft)) ** 0.5
    return {"fps": round(1000 * len(ft) / total, 1), "low1": low(0.01), "low01": low(0.001),
            "jitter": round(sd, 2), "seconds": round(total / 1000), "frames": len(ft)}


def bench_dir(appid):
    return STATE / "bench" / appid


def bench_options(appid, base):
    folder = bench_dir(appid)
    cfg = "no_display,log_duration=%d,log_interval=0,output_folder=%s" % (BENCH_SECONDS, folder)
    words = [w for w in (base or "").split() if w != "mangohud"]
    if "%command%" not in words:
        words = ["%command%"] + words
    at = words.index("%command%")
    return " ".join(['MANGOHUD_CONFIG="%s"' % cfg] + words[:at] + ["mangohud"] + words[at:])


def bench_start(appid, names):
    root = steam_root()
    avail = tools(root)
    pick = [n for n in names if n in avail and avail[n]["switchable"]]
    if len(pick) < 2:
        return {"ok": False, "error": "pick two Protons or more that run in Steam Linux Runtime 4"}, 1
    proton_now, opts_now = current(root)
    new_tool = install_switch(root)
    bench_dir(appid).mkdir(parents=True, exist_ok=True)
    (STATE / "switch").mkdir(parents=True, exist_ok=True)
    (STATE / "switch" / appid).write_text(avail[pick[0]]["dir"])
    state = {"appid": appid, "tools": pick, "dirs": {n: avail[n]["dir"] for n in pick}, "i": 0,
             "since": time.time(), "results": {},
             "before": {"proton": proton_now.get(appid, ""), "options": opts_now.get(appid, "")}}
    (STATE / "bench.json").write_text(json.dumps(state))
    r, code = apply(appid, SWITCH, bench_options(appid, opts_now.get(appid, "")), trusted=True)
    r.update({"restartSteam": new_tool and steam_running(), "tool": pick[0]})
    return r, code


def bench_next():
    st = load_json(STATE / "bench.json", None)
    if not st or st.get("done"):
        return {"ok": False, "error": "no comparison running"}, 1
    logs = [p for p in bench_dir(st["appid"]).glob("*.csv") if p.stat().st_mtime > st["since"]]
    if not logs:
        return {"ok": True, "waiting": True}, 0
    s = stats(frames(max(logs, key=lambda p: p.stat().st_mtime)))
    name = st["tools"][st["i"]]
    st["results"][name] = s or {"error": "too short"}
    st["i"] += 1
    st["since"] = time.time()
    if st["i"] < len(st["tools"]):
        (STATE / "switch" / st["appid"]).write_text(st["dirs"][st["tools"][st["i"]]])
    else:
        st["done"] = True
    (STATE / "bench.json").write_text(json.dumps(st))
    return {"ok": True, "recorded": name, "done": bool(st.get("done"))}, 0


def bench_finish(keep):
    """the comparison ends: the game gets the Proton kept (or what it had) and its old options"""
    st = load_json(STATE / "bench.json", None)
    if not st:
        return {"ok": True}, 0
    appid = st["appid"]
    proton = keep if keep in st["tools"] else st["before"]["proton"]
    r, code = apply(appid, proton, st["before"]["options"], trusted=True)
    hist = load_json(STATE / "bench-history.json", {})
    hist.setdefault(appid, []).append({"at": int(time.time()), "results": st["results"], "kept": proton})
    (STATE / "bench-history.json").write_text(json.dumps(hist))
    (STATE / "bench.json").unlink(missing_ok=True)
    (STATE / "switch" / appid).unlink(missing_ok=True)
    return r, code


def main():
    a = sys.argv[1:]
    cmd = a[0] if a else "list"
    if cmd == "list":
        print(json.dumps(listing(), ensure_ascii=False))
        return 0
    if cmd == "refresh":
        print(json.dumps(refresh(steam_root())))
        return 0
    if cmd == "pending":
        print(json.dumps(apply_pending()))
        return 0
    if cmd == "bench" and len(a) > 1:
        sub = a[1]
        if sub == "start" and len(a) > 3 and a[2].isdigit():
            r, code = bench_start(a[2], a[3].split(","))
        elif sub == "next":
            r, code = bench_next()
        elif sub == "finish":
            r, code = bench_finish(a[2] if len(a) > 2 else "")
        else:
            print(__doc__, file=sys.stderr)
            return 2
        print(json.dumps(r))
        return code
    if cmd == "seen" and len(a) > 1:
        known = load_json(STATE / "known.json", [])
        if a[1] not in known:
            STATE.mkdir(parents=True, exist_ok=True)
            (STATE / "known.json").write_text(json.dumps(known + [a[1]]))
        return 0
    if cmd in ("apply", "undo", "context") and len(a) > 1:
        appid = a[1]
        if not appid.isdigit():
            print(json.dumps({"ok": False, "error": "appid"}))
            return 1
        if cmd == "undo":
            r, code = undo_app(appid)
        elif cmd == "context":
            text, code = context(appid)
            print(text, end="")
            return code
        else:
            proton = a[a.index("--proton") + 1] if "--proton" in a else None
            options = a[a.index("--options") + 1] if "--options" in a else None
            r, code = apply(appid, proton, options)
        print(json.dumps(r))
        return code
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
