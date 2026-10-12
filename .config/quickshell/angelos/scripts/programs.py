#!/usr/bin/env python3
"""Installed programs: what is there, removing one, and cleaning the system up
(Settings → Apps → Programs, `angelos programs`).

  programs.py list [--repo DIR]     JSON {"apps": [{item, names, icon, source, pkg, size, keep,
                                    needed, catalog}]} — one row per thing that can be removed:
                                    a package (all its launchers together), a Flatpak app, a
                                    launcher of the user's own (~/.local/share/applications).
                                    keep: why it must stay ("" = removable): part of the system
                                    or of angelOS (DIR/packages: the dotfiles' base lists);
                                    needed: installed packages that need it
  programs.py plan [--repo DIR] ITEM…
                                    JSON {"remove": [{name, size}], "size": bytes, "refused": why}
                                    — what would really go: pacman takes along what only these
                                    needed (-Rs); refused when something else needs them or a
                                    part of the system would go
  programs.py remove --events [--repo DIR] ITEM…
                                    removes them: the admin password once through pkexec
                                    (scripts/apps-root.py, pacman only), progress as lines
                                    EV {"ev": plan|auth|step|item|done, …} like apps-install.py
  programs.py cleanup-status        JSON {"orphans": [{name, size}], "orphansSize": bytes,
                                    "cache": bytes, "cacheFiles": n, "flatpak": bool}
                                    — packages nothing needs any more (installed as a dependency),
                                    pacman's download cache, Flatpak's unused runtimes
  programs.py cleanup --events [orphans] [cache] [flatpak]
  programs.py bloat-status          JSON {"groups": [{id, title, hint, ticked, items: [{item, pkg, name,
                                    note, size, locked}]}]} — «Лишнее» (data/bloat.json): what the
                                    installer put here that angelOS itself never calls, installed ones
                                    only; locked: why it stays ("" = it can go)
  programs.py bloat --events ITEM…  removes them in one pacman transaction (one password), progress per
                                    package; what something else needs is left and named. Removed
                                    packages go into ~/.local/state/angelos/removed-packages.txt:
                                    install.sh and the apps' sync never bring them back
ITEM: pacman:PKG | flatpak:APPID (the user's) | flatpak-system:APPID | local:FILE.desktop
"""
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
HOME = Path.home()
DATA_HOME = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share")
DATA_DIRS = [DATA_HOME] + [Path(d) for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if d]
LANG = (os.environ.get("ANGELOS_LANG") or os.environ.get("LANG") or "en")[:2].lower()
RU = LANG == "ru"
CACHE = Path("/var/cache/pacman/pkg")
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state") / "angelos"
REMOVED = STATE_DIR / "removed-packages.txt"
BLOAT = HERE.parent / "data/bloat.json"

# what a desktop can't lose: the system, the session, angelOS's own legs
KEEP = {
    "base", "filesystem", "glibc", "bash", "coreutils", "util-linux", "systemd", "systemd-libs", "systemd-sysvcompat",
    "pacman", "sudo", "polkit", "dbus", "dbus-broker", "shadow", "pam", "networkmanager", "iwd", "openssh",
    "archlinux-keyring", "cachyos-keyring", "cachyos-mirrorlist", "cachyos-v3-mirrorlist", "cachyos-v4-mirrorlist",
    "mkinitcpio", "dracut", "limine", "grub", "systemd-boot", "efibootmgr", "linux-firmware", "amd-ucode", "intel-ucode",
    "mesa", "pipewire", "pipewire-pulse", "pipewire-alsa", "wireplumber", "xdg-desktop-portal", "xdg-desktop-portal-gtk",
    "xdg-desktop-portal-gnome", "xdg-utils", "xdg-user-dirs", "niri", "quickshell", "sddm", "xwayland-satellite",
    "qt6-base", "qt6-declarative", "qt6-wayland", "python", "fish", "kitty", "git", "grim", "slurp", "wl-clipboard",
}
KEEP_RX = re.compile(r"^(linux(-|$)|nvidia|lib32-nvidia|.*-firmware$|cachyos-(hooks|settings|rate-mirrors))")


def t(ru, en):
    return ru if RU else en


def run(cmd, **kw):
    """a query: its output, "" when the tool is missing or fails"""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, env=dict(os.environ, LC_ALL="C"), **kw)
    except OSError:
        return subprocess.CompletedProcess(cmd, 127, "", "")


def installer():
    """scripts/apps-install.py: the admin helper (one password), the catalog"""
    spec = importlib.util.spec_from_file_location("apps_install", HERE / "apps-install.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def parse(path):
    try:
        lines = Path(path).read_text(errors="replace").splitlines()
    except OSError:
        return None
    out, here = {}, False
    for line in lines:
        line = line.strip()
        if line.startswith("["):
            here = line == "[Desktop Entry]"
            continue
        if here and "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def size_of(text):
    """pacman's "12.34 MiB" (Flatpak's "1.2 GB") in bytes"""
    m = re.match(r"\s*([\d.]+)\s*([KMGT]?i?B|bytes)", text, re.I)
    if not m:
        return 0
    unit = {"b": 1, "bytes": 1, "kib": 1024, "mib": 1024 ** 2, "gib": 1024 ** 3, "tib": 1024 ** 4,
            "kb": 1000, "mb": 1000 ** 2, "gb": 1000 ** 3, "tb": 1000 ** 4}.get(m.group(2).lower(), 1)
    return int(float(m.group(1)) * unit)


def package_info(names):
    """{name: {"size": bytes, "needed": [names], "reason": explicit|dependency}} for installed packages"""
    out = {}
    if not names:
        return out
    cur = None
    for line in run(["pacman", "-Qi", *sorted(set(names))]).stdout.splitlines():
        key, _, val = line.partition(":")
        key, val = key.strip(), val.strip()
        if key == "Name":
            cur = out.setdefault(val, {"size": 0, "needed": [], "reason": "explicit"})
        elif cur is None:
            continue
        elif key == "Installed Size":
            cur["size"] = size_of(val)
        elif key == "Required By":
            cur["needed"] = [] if val == "None" else val.split()
        elif key == "Install Reason":
            cur["reason"] = "dependency" if "dependency" in val else "explicit"
    return out


def owners(files):
    """{path: package} for files a package owns (one pacman call)"""
    out = {}
    if not files:
        return out
    for line in run(["pacman", "-Qo", *files]).stdout.splitlines():
        m = re.match(r"(.+) is owned by (\S+) \S+$", line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def base_lists(repo):
    names = set()
    for f in ("pacman.txt", "angelos.txt"):
        try:
            lines = (Path(repo) / "packages" / f).read_text().splitlines() if repo else []
        except OSError:
            lines = []
        names |= {l.split("#", 1)[0].strip() for l in lines} - {""}
    return names - bloat_packages()


def bloat_packages():
    """every package data/bloat.json names: extras, never «angelOS needs it»"""
    try:
        groups = json.loads(BLOAT.read_text())["groups"]
    except (OSError, ValueError, KeyError):
        return set()
    return {p for g in groups for p in g.get("packages", {})}


def kept(pkg, base=()):
    if pkg in KEEP or KEEP_RX.match(pkg):
        return t("часть системы", "a part of the system")
    if pkg in base:
        return t("нужна angelOS", "angelOS needs it")
    return ""


def launchers():
    """visible launchers: [(desktop id, path, entry)], the first folder of the search path wins"""
    seen, out = set(), []
    for d in DATA_DIRS:
        apps = d / "applications"
        if not apps.is_dir():
            continue
        for f in sorted(apps.rglob("*.desktop")):
            fid = str(f.relative_to(apps)).replace("/", "-")
            if fid in seen:
                continue
            seen.add(fid)
            e = parse(f)
            if not e or (e.get("Type") or "Application") != "Application":
                continue
            if e.get("NoDisplay", "").lower() == "true" or e.get("Hidden", "").lower() == "true":
                continue
            out.append((fid, f, e))
    return out


def catalog_by_package():
    """{package or flatpak id: catalog id} of the author's apps (data/apps-catalog.json)"""
    out = {}
    try:
        apps = json.loads((HERE.parent / "data/apps-catalog.json").read_text())["apps"]
    except (OSError, ValueError, KeyError):
        return out
    for a in apps:
        for key in ("pacman", "aur", "flatpak"):
            v = a.get(key)
            for n in ([v] if isinstance(v, str) else v or []):
                out.setdefault(n, a["id"])
    return out


def listing(repo=""):
    found = launchers()
    mine = DATA_HOME / "applications"
    system = [str(f) for _, f, _ in found if mine not in f.parents and "/flatpak/" not in str(f.resolve())]
    own = owners(system)
    base, cat = base_lists(repo), catalog_by_package()
    rows = {}
    for fid, f, e in found:
        real = str(f.resolve())
        name = e.get(f"Name[{LANG}]") or e.get("Name") or fid
        if "/flatpak/" in real:
            app = e.get("X-Flatpak") or fid[:-len(".desktop")]
            item = ("flatpak:" if real.startswith(str(HOME)) else "flatpak-system:") + app
            row = rows.setdefault(item, {"item": item, "names": [], "icon": e.get("Icon", ""), "source": "flatpak", "pkg": app,
                                         "size": 0, "keep": "", "needed": [], "catalog": cat.get(app, "")})
        elif str(f) in own:
            pkg = own[str(f)]
            item = "pacman:" + pkg
            row = rows.setdefault(item, {"item": item, "names": [], "icon": e.get("Icon", ""), "source": "pacman", "pkg": pkg,
                                         "size": 0, "keep": kept(pkg, base), "needed": [], "catalog": cat.get(pkg, "")})
        elif mine in f.parents:
            item = "local:" + str(f)
            row = rows.setdefault(item, {"item": item, "names": [], "icon": e.get("Icon", ""), "source": "local", "pkg": "",
                                         "size": 0, "keep": "", "needed": [], "catalog": ""})
        else:
            continue     # a launcher nobody owns, outside the user's folder: not ours to remove
        if name not in row["names"]:
            row["names"].append(name)
    info = package_info([r["pkg"] for r in rows.values() if r["source"] == "pacman"])
    for r in rows.values():
        if r["source"] == "pacman":
            i = info.get(r["pkg"], {})
            r["size"], r["needed"] = i.get("size", 0), i.get("needed", [])
    if any(r["source"] == "flatpak" for r in rows.values()):
        for line in run(["flatpak", "list", "--app", "--columns=application,size"]).stdout.splitlines():
            app, _, size = line.partition("\t")
            for prefix in ("flatpak:", "flatpak-system:"):
                if prefix + app.strip() in rows:
                    rows[prefix + app.strip()]["size"] = size_of(size.replace("\xa0", " ").replace(",", "."))
    out = sorted(rows.values(), key=lambda r: r["names"][0].lower())
    return {"apps": out}


def split(items):
    """ITEMs by kind; anything else is refused"""
    out = {"pacman": [], "flatpak": [], "flatpak-system": [], "local": []}
    for it in items:
        kind, _, val = it.partition(":")
        if kind not in out or not val or (kind != "local" and not re.fullmatch(r"[A-Za-z0-9@._+-]+", val)):
            sys.exit(f"not something to remove: {it}")
        if kind == "local":
            p = Path(val)
            # only the user's own launchers, by their real place
            if p.suffix != ".desktop" or DATA_HOME / "applications" not in p.resolve().parents:
                sys.exit(f"not a launcher of yours: {val}")
        out[kind].append(val)
    return out


def plan(items, flags=("-Rs",), base=()):
    want = split(items)
    remove, refused = [], ""
    mine = [p for p in want["pacman"] if kept(p, base)]
    if mine:
        refused = t("это не удаляется — ", "this stays — ") + ", ".join(f"{p}: {kept(p, base)}" for p in mine)
    elif want["pacman"]:
        r = run(["pacman", *flags, "--print", "--print-format", "%n %s", *want["pacman"]])
        if r.returncode:
            # ":: removing gtk3 breaks dependency 'gtk3' required by firefox" says more than the error line
            why = [l[3:] for l in (r.stdout + "\n" + r.stderr).splitlines() if l.startswith(":: ")]
            refused = "; ".join(why[:4]) or (r.stderr or r.stdout).strip().replace("error: ", "") or t("pacman отказал", "pacman refused")
        else:
            for line in r.stdout.splitlines():
                name, _, size = line.partition(" ")
                if name:
                    remove.append({"name": name, "size": int(size) if size.strip().isdigit() else 0})
            bad = [x["name"] for x in remove if kept(x["name"], base)]
            if bad:
                refused = t("вместе с этим ушла бы часть системы: ", "a part of the system would go with it: ") + ", ".join(bad)
    for kind in ("flatpak", "flatpak-system", "local"):
        remove += [{"name": v if kind != "local" else Path(v).name, "size": 0} for v in want[kind]]
    return {"remove": remove, "size": sum(x["size"] for x in remove), "refused": refused}


def ev(kind, **data):
    print("EV " + json.dumps({"ev": kind} | data, ensure_ascii=False), flush=True)


def say(text):
    print("» " + text, flush=True)


def trash(path):
    if shutil.which("gio") and subprocess.run(["gio", "trash", "--", str(path)]).returncode == 0:
        return
    Path(path).unlink(missing_ok=True)


def installed(pkg):
    return run(["pacman", "-Q", pkg]).returncode == 0


def flatpak_there(app, scope):
    return run(["flatpak", "info", scope, app]).returncode == 0


def with_root(need, body):
    """body() with the admin helper running when root is needed; exit code 2 when the password was not given"""
    ai = installer()
    helper = None
    if need:
        ev("auth")
        say(t("нужен пароль администратора — один раз", "the admin password, once"))
        helper, why = ai.start_root()
        if why:
            say(why)
            ev("done", ok=[], failed=[], auth=why)
            return 2
    try:
        return body(ai)
    finally:
        ai.stop_root(helper)


def remove(items, base=()):
    p = plan(items, base=base)
    want = split(items)
    ev("plan", items=[{"id": it} for it in items], remove=p["remove"], size=p["size"])
    if p["refused"]:
        say(p["refused"])
        ev("done", ok=[], failed=list(items), refused=p["refused"])
        return 1

    def body(ai):
        ok, failed = [], []
        n = 0
        for kind in ("pacman", "flatpak", "flatpak-system", "local"):
            for val in want[kind]:
                item = f"{kind}:{val}"
                ev("item", id=item, state="start", n=n, of=len(items))
                say(t(f"удаляю {val}", f"removing {val}"))
                if kind == "pacman":
                    subprocess.run(ai.root("pacman", "-Rs", "--noconfirm", val))
                    gone = not installed(val)
                elif kind == "local":
                    trash(val)
                    gone = not Path(val).exists()
                else:
                    scope = "--user" if kind == "flatpak" else "--system"
                    subprocess.run(["flatpak", "uninstall", scope, "-y", "--noninteractive", val])
                    gone = not flatpak_there(val, scope)
                n += 1
                (ok if gone else failed).append(item)
                ev("item", id=item, state="done" if gone else "fail", n=n, of=len(items))
        ev("done", ok=ok, failed=failed)
        return 1 if failed else 0
    return with_root(bool(want["pacman"]), body)


def orphans():
    names = run(["pacman", "-Qdtq"]).stdout.split()
    info = package_info(names)
    return [{"name": n, "size": info.get(n, {}).get("size", 0)} for n in names if not kept(n)]


def cache_size():
    total = files = 0
    try:
        for f in os.scandir(CACHE):
            if f.is_file(follow_symlinks=False):
                total += f.stat(follow_symlinks=False).st_size
                files += 1
    except OSError:
        pass
    return total, files


def cleanup_status():
    orph = orphans()
    cache, files = cache_size()
    return {"orphans": orph, "orphansSize": sum(o["size"] for o in orph), "cache": cache, "cacheFiles": files,
            "flatpak": bool(shutil.which("flatpak")) and bool(run(["flatpak", "list", "--runtime", "--columns=application"]).stdout.strip())}


def cleanup(what):
    what = [w for w in what if w in ("orphans", "cache", "flatpak")]
    orph = [o["name"] for o in orphans()] if "orphans" in what else []
    # with what only they needed (-s) — unless a part of the system would go along: then they alone
    deep = plan(["pacman:" + n for n in orph], flags=("-Rns",)) if orph else {"remove": [], "refused": ""}
    flags = ("-Rn",) if deep["refused"] else ("-Rns",)
    ev("plan", items=[{"id": w} for w in what], remove=deep["remove"] if not deep["refused"] else [{"name": n, "size": 0} for n in orph])

    def body(ai):
        ok, failed = [], []
        for n, w in enumerate(what):
            ev("item", id=w, state="start", n=n, of=len(what))
            if w == "orphans":
                good = True
                if orph:
                    say(t("удаляю пакеты, которые больше никому не нужны: ", "removing packages nothing needs any more: ") + " ".join(orph))
                    good = subprocess.run(ai.root("pacman", *flags, "--noconfirm", *orph)).returncode == 0
            elif w == "cache":
                say(t("чищу кэш загрузок pacman (пакеты установленных версий остаются)",
                      "cleaning pacman's download cache (the packages of the installed versions stay)"))
                good = subprocess.run(ai.root("pacman", "-Sc", "--noconfirm")).returncode == 0
            else:
                say(t("убираю неиспользуемые части Flatpak", "removing Flatpak's unused runtimes"))
                good = subprocess.run(["flatpak", "uninstall", "--user", "--unused", "-y", "--noninteractive"]).returncode == 0
            (ok if good else failed).append(w)
            ev("item", id=w, state="done" if good else "fail", n=n + 1, of=len(what))
        ev("done", ok=ok, failed=failed)
        return 1 if failed else 0
    return with_root(bool(orph) or "cache" in what, body)



# ── «Лишнее»: what came along and angelOS never calls (data/bloat.json) ──────────

def settings():
    base = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
    try:
        return json.loads((base / "angelos/settings.json").read_text())
    except (OSError, ValueError):
        return {}


def in_use():
    """{program: why} the user's settings name: the terminal, the task manager, the file manager"""
    s = settings()
    out = {}
    for sec, key, why in (("system", "terminal", t("это твой терминал", "it is your terminal")),
                          ("launcher", "terminal", t("это твой терминал", "it is your terminal")),
                          ("system", "monitorProgram", t("это твой диспетчер задач", "it is your task manager")),
                          ("system", "fileManager", t("это твой файловый менеджер", "it is your file manager"))):
        v = ((s.get(sec) or {}).get(key) or "").split()
        if v:
            out[os.path.basename(v[0])] = why
    return out


def removed_list():
    try:
        return [l.strip() for l in REMOVED.read_text().splitlines() if l.strip() and not l.startswith("#")]
    except OSError:
        return []


def remember_removed(pkgs, catalog_ids=()):
    """removed as extras: install.sh and the apps' sync leave them out from now on"""
    if pkgs:
        have = removed_list()
        new = have + [p for p in pkgs if p not in have]
        REMOVED.parent.mkdir(parents=True, exist_ok=True)
        REMOVED.write_text("# packages removed in Settings → Programs → Extras: angelOS updates never bring them back\n"
                           + "\n".join(new) + "\n")
    if catalog_ids:
        ai = installer()
        st = ai.load_state()
        if "apps" in st:
            st["apps"] = [i for i in st["apps"] if i not in set(catalog_ids)]
            ai.save_state(st)


# what an author's app does for angelOS itself: said next to it among the extras
ANGELOS_USES = {
    "com.github.wwmm.easyeffects": ("на ней держится эквалайзер на панели", "the bar's equaliser runs on it"),
    "easyeffects": ("на ней держится эквалайзер на панели", "the bar's equaliser runs on it"),
    "com.obsproject.Studio": ("режим стрима angelOS следит за ней", "angelOS's stream mode follows it"),
    "obs-studio": ("режим стрима angelOS следит за ней", "angelOS's stream mode follows it"),
}


def default_browser_pkg():
    """the package of the default web browser (it stays: links would open nowhere)"""
    d = run(["xdg-mime", "query", "default", "x-scheme-handler/https"]).stdout.strip()
    if not d:
        return ""
    for base in DATA_DIRS:
        f = base / "applications" / d
        if f.exists():
            return owners([str(f)]).get(str(f), "")
    return ""


def bloat_status():
    try:
        groups = json.loads(BLOAT.read_text())["groups"]
    except (OSError, ValueError, KeyError):
        return {"groups": []}
    names = sorted({p for g in groups for p in g.get("packages", {})})
    info = package_info(names)            # installed ones only
    use = in_use()
    # a package something outside the extras needs stays (one of the extras needing it is fine)
    every = set(names)
    out = []
    catalog_rows = []
    if any(g.get("catalog") for g in groups):
        catalog_rows = [r for r in listing().get("apps", []) if r.get("catalog") and r["source"] in ("pacman", "flatpak", "flatpak-system")
                        and r["pkg"] not in names]
        browser = default_browser_pkg()
        if browser:
            use[browser] = t("это браузер по умолчанию", "it is the default browser")
        cat_pkgs = {r["pkg"] for r in catalog_rows if r["source"] == "pacman"}
        every |= cat_pkgs
    for g in groups:
        items = []
        if g.get("catalog"):
            for r in catalog_rows:
                if r["source"] == "pacman" and r["pkg"] in every - set(names):
                    others = [n for n in r.get("needed", []) if n not in every]
                else:
                    others = []
                locked = r.get("keep") or ""
                if not locked and use.get(r["pkg"]):
                    locked = use[r["pkg"]]
                if not locked and others:
                    locked = t("нужна для: ", "needed by: ") + ", ".join(others[:3])
                uses = ANGELOS_USES.get(r["pkg"])
                items.append({"item": r["item"], "pkg": r["pkg"], "name": r["names"][0],
                              "note": t(*uses) if uses else ", ".join(r["names"][1:3]),
                              "size": r["size"], "locked": locked, "catalog": r["catalog"]})
        else:
            for pkg, (note_ru, note_en) in g.get("packages", {}).items():
                if pkg not in info:
                    continue
                others = [n for n in info[pkg]["needed"] if n not in every]
                locked = use.get(pkg) or (t("нужна для: ", "needed by: ") + ", ".join(others[:3]) if others else "")
                if not locked and (pkg in KEEP or KEEP_RX.match(pkg)):
                    locked = t("часть системы", "a part of the system")
                items.append({"item": "pacman:" + pkg, "pkg": pkg, "name": pkg, "note": t(note_ru, note_en),
                              "size": info[pkg]["size"], "locked": locked, "catalog": ""})
        if items:
            out.append({"id": g["id"], "title": t(g["ru"], g["en"]), "hint": t(g.get("hintRu", ""), g.get("hintEn", "")),
                        "ticked": bool(g.get("ticked")), "items": items})
    return {"groups": out}


def bloat(items):
    """one pacman transaction for the packages (what something else needs is left out and named),
    then the Flatpak apps one by one; progress per package"""
    want = split(items)
    status = bloat_status()
    allowed = {i["item"]: i for g in status["groups"] for i in g["items"]}
    skipped = []
    for it in list(items):
        if it not in allowed or allowed[it]["locked"]:
            skipped.append({"id": it, "why": allowed.get(it, {}).get("locked") or t("не из списка лишнего", "not one of the extras")})
    skip_ids = {s["id"] for s in skipped}
    pkgs = [p for p in want["pacman"] if "pacman:" + p not in skip_ids]
    flats = [(k, v) for k in ("flatpak", "flatpak-system") for v in want[k] if f"{k}:{v}" not in skip_ids]
    # pacman refuses the whole transaction for one package something else needs: leave those out
    plan_rows = []
    for _ in range(len(pkgs) + 1):
        if not pkgs:
            break
        r = run(["pacman", "-Rs", "--print", "--print-format", "%n %s", *pkgs])
        if r.returncode == 0:
            plan_rows = [{"name": l.split(" ", 1)[0], "size": int(l.split(" ", 1)[1]) if l.split(" ", 1)[1:] and l.split(" ", 1)[1].isdigit() else 0}
                         for l in r.stdout.splitlines() if l.strip()]
            bad = [x["name"] for x in plan_rows if kept(x["name"])]
            if not bad:
                break
            drop = set(bad)
        else:
            text = r.stdout + "\n" + r.stderr
            drop = set(re.findall(r"removing (\S+) breaks dependency", text)) | set(re.findall(r"target not found: (\S+)", text))
            if not drop & set(pkgs):
                skipped += [{"id": "pacman:" + p, "why": t("pacman отказал", "pacman refused")} for p in pkgs]
                pkgs = []
                break
        for p in drop & set(pkgs):
            skipped.append({"id": "pacman:" + p, "why": t("её не отпускает другая программа", "another program still needs it")})
        pkgs = [p for p in pkgs if p not in drop]
        plan_rows = []
    total = len(plan_rows) + len(flats)
    ev("plan", items=[{"id": it} for it in items], remove=plan_rows + [{"name": v, "size": 0} for _, v in flats],
       size=sum(x["size"] for x in plan_rows), skipped=skipped, total=total)
    for s in skipped:
        say(s["id"].split(":", 1)[1] + " — " + s["why"])
    if not total:
        ev("done", ok=[], failed=[], skipped=skipped)
        return 0

    def body(ai):
        ok, failed = [], []
        n = 0
        if pkgs:
            ev("step", text=t("удаляю пакеты…", "removing the packages…"))
            p = subprocess.Popen(ai.root("pacman", "-Rs", "--noconfirm", *pkgs), stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True, env=dict(os.environ, LC_ALL="C"))
            for line in p.stdout:
                line = line.rstrip()
                # without a terminal pacman says "removing btop..." (with one: "(3/12) removing btop")
                m = re.match(r"(?:\(\s*\d+/\d+\)\s+)?removing (\S+?)(?:\.\.\.)?(?:\s|$)", line)
                if m:
                    ev("item", id="pacman:" + m.group(1), state="start", n=n, of=total)
                    say(t(f"удаляю {m.group(1)}", f"removing {m.group(1)}"))
                    n = min(n + 1, len(plan_rows))
                elif line:
                    print(line, flush=True)
            p.wait()
            n = len(plan_rows)
            for x in pkgs:
                (failed if installed(x) else ok).append("pacman:" + x)
            ev("item", id="pacman", state="done", n=n, of=total)
        for kind, val in flats:
            item = f"{kind}:{val}"
            ev("item", id=item, state="start", n=n, of=total)
            say(t(f"удаляю {val}", f"removing {val}"))
            scope = "--user" if kind == "flatpak" else "--system"
            subprocess.run(["flatpak", "uninstall", scope, "-y", "--noninteractive", val])
            gone = not flatpak_there(val, scope)
            n += 1
            (ok if gone else failed).append(item)
            ev("item", id=item, state="done" if gone else "fail", n=n, of=total)
        gone_pkgs = [i.split(":", 1)[1] for i in ok if i.startswith("pacman:")]
        cats = [allowed[i]["catalog"] for i in ok if allowed.get(i, {}).get("catalog")]
        remember_removed(gone_pkgs, cats)
        ev("done", ok=ok, failed=failed, skipped=skipped)
        return 1 if failed else 0
    return with_root(bool(pkgs), body)

def repo_arg(args):
    return args[args.index("--repo") + 1] if "--repo" in args and args.index("--repo") + 1 < len(args) else ""


if __name__ == "__main__":
    a = sys.argv[1:]
    cmd = a[0] if a else ""
    rest = [x for x in a[1:] if x != "--events"]
    if cmd == "list":
        print(json.dumps(listing(repo_arg(rest)), ensure_ascii=False))
    elif cmd in ("plan", "remove") and rest:
        base = base_lists(repo_arg(rest))
        if "--repo" in rest:
            i = rest.index("--repo")
            rest = rest[:i] + rest[i + 2:]
        if cmd == "plan":
            print(json.dumps(plan(rest, base=base), ensure_ascii=False))
        else:
            sys.exit(remove(rest, base))
    elif cmd == "cleanup-status":
        print(json.dumps(cleanup_status(), ensure_ascii=False))
    elif cmd == "cleanup" and rest:
        sys.exit(cleanup(rest))
    elif cmd == "bloat-status":
        print(json.dumps(bloat_status(), ensure_ascii=False))
    elif cmd == "bloat" and rest:
        sys.exit(bloat(rest))
    else:
        print(__doc__)
        sys.exit(2)
