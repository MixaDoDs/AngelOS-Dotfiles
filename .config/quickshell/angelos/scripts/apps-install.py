#!/usr/bin/env python3
"""The author's apps (data/apps-catalog.json): what is there, installing the picked ones, and
bringing in what the author adds later.

  apps-install.py status            JSON {id: {"installed": bool, "via": "pacman|aur|flatpak|github|"}}
  apps-install.py groups            JSON {"groups": [{id, ru, en, default, apps: [{id, ru, en, hintRu,
                                    hintEn, installed}]}]} for a picker (install.sh)
  apps-install.py tsv               the same for bash, fast (no "installed"): G<TAB>id<TAB>default(1|0)<TAB>en
                                    <TAB>ru<TAB>app,ids… and A<TAB>id<TAB>en<TAB>ru<TAB>hintEn<TAB>hintRu lines
  apps-install.py install [--no-wait] [--browser ID] ID…
                                    in a terminal (the wizard opens one when it ends; install.sh runs
                                    it itself): the distribution's packages with sudo pacman -Syu (a
                                    plain -S on an old package list fails halfway with 404s), the
                                    AUR's with paru (from CachyOS's repositories when missing),
                                    Flathub's per user; then checks each app is really there and
                                    says which are not and why (exit 1 then); waits for Enter at
                                    the end unless --no-wait. Remembers the pick (see below).
                                    --browser: the wizard's «Which browser?» — made the default (Mod+B,
                                    links) once it is there; auto: the first ticked one (install.sh)
  apps-install.py pick [--browser ID] ID…
                                    remember the pick without installing anything (the browser that
                                    is there already becomes the default right away)
  apps-install.py browsers          JSON {"current": id, "list": [{id, ru, en, hintRu, hintEn, icon, installed,
                                    via}]} for the wizard's «Which browser?»: the catalog's browsers, then
                                    the ones installed some other way (id desktop:<file.desktop>);
                                    current: the default browser now, as one of those ids ("" = none)
  apps-install.py browser ID        make ID the default browser: a catalog id, or desktop:<file.desktop>
                                    for one installed some other way
  apps-install.py pending [--repo DIR]
                                    JSON {"apps": [id…], "suggest": [id…], "packages": [name…], "fish": bool}: what the author added
                                    since this system last looked — apps in the groups the user took,
                                    and the base packages of DIR/packages (the dotfiles repository) —
                                    and that is not installed; fish: the login shell is still bash
                                    (an install from before fish came with angelOS), not asked yet;
                                    suggest: on a system that never picked, the author's other apps
                                    (shown once, unticked).
                                    Changes nothing
  apps-install.py sync [--repo DIR] [--no-wait]
                                    in a terminal: shows the pending ones (all ticked), installs the
                                    ticked ones; everything shown counts as seen afterwards, so what
                                    the user left out (or removed later) is not offered again
  apps-install.py ack [--repo DIR]  the same without installing: "not needed"

Each app: its pacman package(s) — on Arch Linux the author's repositories (CachyOS's and
multilib, scripts/cachyos-repos.sh) go in first when pacman doesn't have it yet —, its AUR
package(s) when pacman has none, its Flathub id when neither. "prefer": "flatpak" puts Flathub
first (the author has Discord, OBS, Blender and EasyEffects from there). "github": a package the
app's authors publish in their own GitHub release (Freshgram): the latest release's .pacman file,
checked against its SHA256SUMS, installed with pacman -U.

The pick lives in ~/.local/state/angelos/apps.json: {"apps": [ids picked], "known": [catalog ids
seen], "knownBase": [base packages seen]}. A group counts as taken when one of its apps was
picked; an app the author adds to it later is offered by `pending` / `sync` (Settings → Updates
and the shell's start). Nothing is ever removed. Without the file (systems from before it) the
pick is the catalog's apps that are installed.
"""
import json
import os
import pwd
import hashlib
import importlib.util
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "data/apps-catalog.json"
REPOS = Path(__file__).resolve().parent / "cachyos-repos.sh"
DEFAULT_APPS = Path(__file__).resolve().parent / "default-apps.py"
STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "angelos/apps.json"
# the base package lists of the dotfiles repository an update brings in (install.sh's full profile)
BASE_LISTS = ("pacman.txt", "angelos.txt", "tools.txt", "fish.txt")
RU = (os.environ.get("ANGELOS_LANG") or os.environ.get("LANG", "ru")).startswith("ru")


def t(ru, en):
    return ru if RU else en


def run(cmd, **kw):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, **kw)


def catalog():
    return json.loads(CATALOG.read_text())


def apps():
    return {a["id"]: a for a in catalog()["apps"]}


def on_cachyos():
    try:
        return "\nID=cachyos\n" in "\n" + Path("/etc/os-release").read_text()
    except OSError:
        return False


def pkgs(a, key):
    v = a.get(key) or []
    v = [v] if isinstance(v, str) else list(v)
    # some of CachyOS's packages are built against its zlib-ng: on Arch they'd replace zlib (the
    # whole list failed on "Remove zlib? [y/N]"), so Arch's own packages stand in for them
    if key == "pacman" and a.get("onArch") and not on_cachyos():
        v = [x for n in v for x in (a["onArch"].get(n) or [n])]
    return v


def pacman_installed(names):
    """every one of names is installed (none given: False)"""
    return bool(names) and run(["pacman", "-T", *names]).returncode == 0


def pacman_has(name):
    return bool(name) and bool(shutil.which("pacman")) and run(["pacman", "-Si", name]).returncode == 0


def flatpak_installed(app_id):
    return bool(app_id) and bool(shutil.which("flatpak")) and run(["flatpak", "info", app_id]).returncode == 0


def aur_helper():
    return next((h for h in ("paru", "yay") if shutil.which(h)), "")


def can_aur(repos_coming=False):
    """paru or yay is there, or paru can come from CachyOS's repositories"""
    return bool(aur_helper()) or pacman_has("paru") or repos_coming


def installed(a):
    pac, aur = pkgs(a, "pacman"), pkgs(a, "aur")
    gh = [(a.get("github") or {}).get("package")] if a.get("github") else []
    main = (pacman_installed(pac[:1]) or pacman_installed(aur[:1]) or pacman_installed(gh)
            or flatpak_installed(a.get("flatpak")))
    return main and all(pacman_installed([p]) for p in pkgs(a, "extra"))


def resolve(a, repos_coming=False):
    """(installed, via); repos_coming: the author's repositories get added before installing"""
    if installed(a):
        return True, ""
    pac, aur, flat = pkgs(a, "pacman"), pkgs(a, "aur"), a.get("flatpak")
    has_flat = bool(flat) and bool(shutil.which("flatpak") or pacman_has("flatpak"))
    if a.get("prefer") == "flatpak" and has_flat:
        return False, "flatpak"
    if pac and (pacman_has(pac[0]) or repos_coming):
        return False, "pacman"
    if aur and can_aur(repos_coming):
        return False, "aur"
    if has_flat:
        return False, "flatpak"
    if a.get("github") and shutil.which("pacman"):
        return False, "github"
    return False, ""


def status():
    out = {}
    coming = arch_without_repos()
    for i, a in apps().items():
        inst, via = resolve(a, coming)
        out[i] = {"installed": inst, "via": via}
    print(json.dumps(out))


def groups():
    cat = catalog()
    by = {a["id"]: a for a in cat["apps"]}
    out = []
    for g in cat["groups"]:
        row = {k: g[k] for k in ("id", "ru", "en", "default")}
        row["apps"] = [{k: by[i].get(k, "") for k in ("id", "ru", "en", "hintRu", "hintEn")} | {"installed": installed(by[i])}
                       for i in g["apps"] if i in by]
        out.append(row)
    print(json.dumps({"groups": out}, ensure_ascii=False))


def tsv():
    cat = catalog()
    for g in cat["groups"]:
        print("\t".join(["G", g["id"], "1" if g.get("default") else "0", g["en"], g["ru"], ",".join(g["apps"])]))
    for a in cat["apps"]:
        print("\t".join(["A", a["id"], a["en"], a["ru"], a.get("hintEn", ""), a.get("hintRu", "")]))


def notify(*args):
    """a desktop notification; none without notify-send or a desktop"""
    if shutil.which("notify-send") and os.environ.get("WAYLAND_DISPLAY"):
        subprocess.run(["notify-send", "-a", "angelOS", *args], stderr=subprocess.DEVNULL)


def say(text):
    print(f"\033[1;35m»\033[0m {text}", flush=True)


def arch_without_repos():
    """Arch Linux (x86_64) without the author's repositories (scripts/cachyos-repos.sh)"""
    try:
        osr = Path("/etc/os-release").read_text()
    except OSError:
        return False
    return ("\nID=arch\n" in "\n" + osr) and os.uname().machine == "x86_64" \
        and subprocess.run(["bash", str(REPOS), "--check"]).returncode != 0


# ── the pick ──────────────────────────────────────────────────────────────────

def load_state():
    try:
        st = json.loads(STATE.read_text())
        if isinstance(st, dict):
            return st
    except (OSError, ValueError):
        pass
    return {}


def save_state(st):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps(st, ensure_ascii=False, indent=1) + "\n")
    tmp.replace(STATE)


def remember(ids):
    """the user picked ids (more may come later): every app of the catalog is seen now"""
    st = load_state()
    cat = apps()
    st["apps"] = sorted(set(st.get("apps", [])) | {i for i in ids if i in cat})
    st["known"] = sorted(set(st.get("known", [])) | set(cat))
    save_state(st)


def base_packages(repo):
    """the dotfiles repository's base package lists (noctalia only where it is installed)"""
    out = []
    if not repo:
        return out
    for name in BASE_LISTS:
        try:
            lines = (Path(repo) / "packages" / name).read_text().splitlines()
        except OSError:
            continue
        for line in lines:
            line = line.split("#", 1)[0].strip()
            if line and line not in out:
                out.append(line)
    if "noctalia" in out and not pacman_installed(["noctalia"]):
        out.remove("noctalia")
    return out


def login_shell():
    try:
        return pwd.getpwuid(os.getuid()).pw_shell
    except KeyError:
        return ""


def fish_wanted(st):
    """bash (or sh) is the login shell and the author's fish was not offered yet"""
    return os.path.basename(login_shell()) in ("bash", "sh") and not st.get("fishAsked")


def fish_packages(repo):
    try:
        lines = (Path(repo) / "packages/fish.txt").read_text().splitlines() if repo else []
    except OSError:
        lines = []
    names = [l.split("#", 1)[0].strip() for l in lines]
    return [n for n in names if n] or ["fish"]


def make_fish_login(repo):
    """the author's fish: its packages, then the login shell (sudo is fresh: no second password)"""
    want = fish_packages(repo)
    missing = [p for p in (run(["pacman", "-T", *want]).stdout.split() if shutil.which("pacman") else []) if pacman_has(p)]
    if missing:
        say("fish: " + " ".join(missing))
        if subprocess.run(["sudo", "pacman", "-Syu", "--needed", *missing]).returncode:
            return 1
    fish = shutil.which("fish") or "/usr/bin/fish"
    if not Path(fish).exists():
        return 1
    shells = Path("/etc/shells").read_text() if Path("/etc/shells").exists() else ""
    if fish not in shells.split():
        subprocess.run(["sudo", "sh", "-c", f"echo {fish} >> /etc/shells"])
    user = pwd.getpwuid(os.getuid()).pw_name
    rc = subprocess.run(["sudo", "chsh", "-s", fish, user]).returncode
    if rc == 0:
        say(t("fish — оболочка входа со следующего входа ♡ (открой новый терминал, чтобы увидеть сейчас)",
              "fish is your login shell from the next login ♡ (a new terminal shows it now)"))
    return rc


def pending(repo):
    st = load_state()
    cat = catalog()
    by = {a["id"]: a for a in cat["apps"]}
    if "known" in st:
        picked, known = set(st.get("apps", [])), set(st["known"])
    else:  # a system from before the pick was kept: what it has of the catalog is its pick
        picked, known = {i for i, a in by.items() if installed(a)}, set()
    taken = {g["id"] for g in cat["groups"] if picked & set(g["apps"])}
    new_apps = [i for g in cat["groups"] if g["id"] in taken for i in g["apps"]
                if i in by and i not in known and i not in picked and not installed(by[i])]
    # a system that never picked: the rest of the author's apps shown once too, unticked
    suggest = [] if "known" in st else [i for g in cat["groups"] if g.get("default") and g["id"] not in taken
                                         for i in g["apps"] if i in by and not installed(by[i])]
    seen = set(st.get("knownBase", []))
    base = [p for p in base_packages(repo) if p not in seen]
    missing = run(["pacman", "-T", *base]).stdout.split() if base and shutil.which("pacman") else []
    new_pkgs = [p for p in missing if pacman_has(p)]
    return {"apps": new_apps, "suggest": suggest, "packages": new_pkgs, "fish": fish_wanted(st)}


def ack(repo, shown_apps=(), fish_shown=True):
    st = load_state()
    if fish_shown:
        st["fishAsked"] = True
    if "known" not in st:
        st["apps"] = sorted({i for i, a in apps().items() if installed(a)} | set(st.get("apps", [])))
    st["known"] = sorted(set(st.get("known", [])) | set(apps()) | set(shown_apps))
    st["knownBase"] = sorted(set(st.get("knownBase", [])) | set(base_packages(repo)))
    save_state(st)


def choose(labels, ticked=None):
    """ticked (all when None) preselected; the user changes it (gum when there is one, else a
    numbered prompt)"""
    ticked = set(range(len(labels))) if ticked is None else set(ticked)
    labels = [l.replace(",", " ·") for l in labels]   # gum: the preselected ones go comma-separated
    if shutil.which("gum"):
        sel = ",".join(labels[i] for i in sorted(ticked))
        r = subprocess.run(["gum", "choose", "--no-limit", "--selected=" + sel, "--height", str(min(len(labels) + 2, 24)),
                            "--header", t("Что поставить? (пробел — снять, Enter — дальше)",
                                          "What to install? (space unticks, Enter goes on)"), *labels],
                           stdout=subprocess.PIPE, text=True)
        if r.returncode:
            return []
        chosen = set(r.stdout.splitlines())
        return [i for i, label in enumerate(labels) if label in chosen]
    for n, label in enumerate(labels, 1):
        print(f"  {n:2}. [{'x' if n - 1 in ticked else ' '}] {label}")
    try:
        answer = input(t("Enter — как отмечено; номера через пробел — переключить их; 0 — ничего: ",
                         "Enter — as ticked; numbers — flip those; 0 — none: ")).split()
    except EOFError:
        answer = []
    if answer == ["0"]:
        return []
    flip = {int(x) - 1 for x in answer if x.isdigit()}
    return [i for i in range(len(labels)) if (i in ticked) != (i in flip)]


def sync(repo, wait=True):
    p = pending(repo)
    cat = apps()
    labels, items = [], []
    unticked = set()
    for i in p["apps"] + p["suggest"]:
        a = cat[i]
        if i in p["suggest"]:
            unticked.add(len(items))
        labels.append(f"{t(a['ru'], a['en'])} — {t(a.get('hintRu', ''), a.get('hintEn', ''))}")
        items.append(("app", i))
    if p["fish"]:
        labels.append(t("fish — оболочка как у автора (prompt pure, fastfetch, eza) вместо bash",
                        "fish — the shell as the author has it (the pure prompt, fastfetch, eza) instead of bash"))
        items.append(("fish", ""))
    for name in p["packages"]:
        labels.append(f"{name} — {t('системный пакет angelOS', 'an angelOS system package')}")
        items.append(("pkg", name))
    if not items:
        say(t("ничего нового — всё как у автора ♡", "nothing new: everything is as the author has it ♡"))
        ack(repo)
        return finish(0, wait)
    say(t("как у автора angelOS — отмечено то, что подходит к твоему выбору:",
          "as angelOS's author has it — ticked is what fits your pick:"))
    picked = [items[n] for n in choose(labels, [n for n in range(len(items)) if n not in unticked])]
    ids = [v for k, v in picked if k == "app"]
    names = [v for k, v in picked if k == "pkg"]
    rc = 0
    if any(k == "fish" for k, _ in picked):
        rc = make_fish_login(repo) or rc
    if names:
        say(t("системные пакеты: ", "system packages: ") + " ".join(names))
        rc = subprocess.run(["sudo", "pacman", "-Syu", "--needed", *names]).returncode
    if ids:
        rc = install(ids, wait=False) or rc
    ack(repo, p["apps"] + p["suggest"])
    return finish(rc, wait)


def finish(rc, wait):
    if wait:
        try:
            input(t("\nEnter — закрыть окно ", "\nEnter — close the window "))
        except EOFError:
            pass
    return rc


def ensure_paru():
    """the AUR needs a helper: paru from CachyOS's repositories when there is none"""
    if aur_helper():
        return aur_helper()
    if pacman_has("paru"):
        say(t("ставлю paru (AUR) из репозиториев CachyOS", "installing paru (the AUR) from CachyOS's repositories"))
        subprocess.run(["sudo", "pacman", "-S", "--needed", "--noconfirm", "paru"])
    return aur_helper()


def aur_missing(names):
    """the names the AUR doesn't have (its RPC; offline: none, the helper finds out itself)"""
    import urllib.parse
    import urllib.request
    try:
        q = "&".join("arg[]=" + urllib.parse.quote(n) for n in names)
        with urllib.request.urlopen("https://aur.archlinux.org/rpc/v5/info?" + q, timeout=15) as r:
            have = {x["Name"] for x in json.load(r).get("results", [])}
        return [n for n in names if n not in have]
    except (OSError, ValueError):
        return []


def vulkan_drivers():
    """Steam needs a vulkan-driver and a lib32-vulkan-driver. pacman asks which, and Enter takes
    the first of 32: mesa-git with CachyOS's v3 repositories on top (a dev build that conflicts
    with mesa — the "N" to removing mesa cancelled every app of the list), nvidia-utils on an AMD
    card without them. So the ones for this machine's GPUs go in by name: nothing to ask."""
    if run(["pacman", "-T", "vulkan-driver", "lib32-vulkan-driver"]).returncode == 0:
        return []
    out = []
    for dev in sorted(Path("/sys/class/drm").glob("card[0-9]*/device")):
        try:
            vendor = (dev / "vendor").read_text().strip()
        except OSError:
            continue
        if vendor == "0x1002":
            pair = ("vulkan-radeon", "lib32-vulkan-radeon")
        elif vendor == "0x8086":
            pair = ("vulkan-intel", "lib32-vulkan-intel")
        elif vendor == "0x10de":
            # the proprietary driver brings its own; nouveau gets mesa's
            pair = ("nvidia-utils", "lib32-nvidia-utils") if Path("/sys/module/nvidia").exists() \
                else ("vulkan-nouveau", "lib32-vulkan-nouveau")
        else:   # a virtual machine's or something unknown: mesa's software one always works
            pair = ("vulkan-swrast", "lib32-vulkan-swrast")
        out += [x for x in pair if x not in out]
    return out or ["vulkan-swrast", "lib32-vulkan-swrast"]


def github_install(a):
    """the latest release's package, its checksum checked, through pacman -U (pacman pulls the
    dependencies from the repositories)"""
    g = a["github"]
    base = f"https://github.com/{g['repo']}/releases/latest/download/"
    say(t(f"с GitHub ({g['repo']}): ", f"from GitHub ({g['repo']}): ") + g["asset"])
    with tempfile.TemporaryDirectory(prefix="angelos-app-") as tmp:
        dest = Path(tmp) / g["asset"]
        try:
            with urllib.request.urlopen(base + g["sums"], timeout=30) as r:
                sums = r.read().decode()
            if shutil.which("curl"):  # ~130 MB: with curl's progress bar
                if subprocess.run(["curl", "-fL", "--retry", "2", "--progress-bar", "-o", str(dest),
                                   base + g["asset"]]).returncode != 0:
                    raise OSError(g["asset"])
            else:
                with urllib.request.urlopen(base + g["asset"], timeout=60) as r, open(dest, "wb") as f:
                    shutil.copyfileobj(r, f, 1 << 20)
        except OSError as e:
            say(t(f"не скачалось: {e}", f"download failed: {e}"))
            return False
        want = next((ln.split()[0] for ln in sums.splitlines()
                     if len(ln.split()) == 2 and ln.split()[1].lstrip("*") == g["asset"]), "")
        got = hashlib.sha256(dest.read_bytes()).hexdigest()
        if not want or want.lower() != got:
            say(t("контрольная сумма не сошлась — не ставлю", "the checksum doesn't match: not installing"))
            return False
        return subprocess.run(["sudo", "pacman", "-U", "--needed", "--noconfirm", str(dest)]).returncode == 0


def desktop_of(a):
    """the .desktop id an installed app opens with (its package's file, or its Flathub id)"""
    names = pkgs(a, "pacman") + pkgs(a, "aur") + ([a["github"]["package"]] if a.get("github") else [])
    for name in names:
        if not pacman_installed([name]):
            continue
        files = [Path(f) for f in run(["pacman", "-Qlq", name]).stdout.split()
                 if f.startswith("/usr/share/applications/") and f.endswith(".desktop")]
        # a browser can bring more than one (Vivaldi's own and a private one): the web browser's
        files.sort(key=lambda f: "WebBrowser" not in f.read_text(errors="ignore"))
        if files:
            return files[0].name
    if a.get("flatpak") and flatpak_installed(a["flatpak"]):
        return a["flatpak"] + ".desktop"
    return ""


def default_apps():
    spec = importlib.util.spec_from_file_location("default_apps", DEFAULT_APPS)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def browsers():
    cat = catalog()
    by = {a["id"]: a for a in cat["apps"]}
    coming = arch_without_repos()
    out, ids_of = [], {}
    for i in cat.get("browsers", []):
        a = by.get(i)
        if not a:
            continue
        inst, via = resolve(a, coming)
        if inst:
            ids_of[desktop_of(a)] = i
        out.append({k: a.get(k, "") for k in ("id", "ru", "en", "hintRu", "hintEn", "icon")}
                   | {"installed": inst, "via": via})
    da = default_apps()
    entries = da.entries("ru" if RU else "en")
    for did, e in sorted(entries.items(), key=lambda x: x[1]["name"].lower()):
        # a real browser (WebBrowser): apps that only take http links (ChatGPT, Steam) are not
        if e["hidden"] or "WebBrowser" not in e["cats"] or did in ids_of:
            continue
        ids_of[did] = "desktop:" + did
        out.append({"id": "desktop:" + did, "ru": e["name"], "en": e["name"], "hintRu": "уже стоит",
                    "hintEn": "installed", "icon": "search", "installed": True, "via": ""})
    cur = da.configured("x-scheme-handler/https") or da.query("x-scheme-handler/https")
    print(json.dumps({"current": ids_of.get(cur, ""), "list": out}, ensure_ascii=False))


def set_browser(bid):
    """the wizard's browser becomes the default one (Mod+B, links, xdg-settings) once it is there"""
    if not bid:
        return True
    st = load_state()
    st["browser"] = bid
    save_state(st)
    a = apps().get(bid)
    did = bid[len("desktop:"):] if bid.startswith("desktop:") else desktop_of(a) if a else ""
    if not did:
        say(t("браузер не поставился — по умолчанию остаётся прежний",
              "the browser didn't install: the default stays as it was"))
        return False
    ok = subprocess.run([sys.executable, str(DEFAULT_APPS), "set", "browser", did],
                        stdout=subprocess.DEVNULL).returncode == 0
    if ok:
        say(t(f"браузер по умолчанию: {did}", f"default browser: {did}"))
    return ok


def batch(first, retry, names):
    """One transaction, and when it fails, one by one: a single name the source doesn't have
    (an AUR package that was renamed or removed) or one conflict used to cancel the whole list —
    freshgram missing from the AUR took Proton-GE, spicetify, lrc_tty and Throne down with it."""
    if subprocess.run(first + names).returncode == 0:
        return True
    if len(names) == 1:
        return False
    say(t("одним разом не вышло — ставлю по одной", "not in one go: one at a time"))
    return all([subprocess.run(retry + [n]).returncode == 0 for n in names])


def install(ids, wait=True, browser=""):
    cat = apps()
    remember(ids)
    # an app pacman can't give yet (Helium, qView, LocalSend: CachyOS's; Steam: multilib): the
    # author's repositories first, as the installer adds them — then pacman has it
    if arch_without_repos() and any(i in cat and not installed(cat[i]) and pkgs(cat[i], "pacman")
                                    and not pacman_has(pkgs(cat[i], "pacman")[0]) for i in ids):
        say(t("подключаю репозитории автора (CachyOS и multilib), чтобы всё ставилось через pacman",
              "adding the author's repositories (CachyOS's and multilib), so everything installs with pacman"))
        subprocess.run(["sudo", "bash", str(REPOS)])
    pac, aur, flat, gh, skipped, have = [], [], [], [], [], []
    for i in ids:
        a = cat.get(i)
        if not a:
            continue
        inst, via = resolve(a)
        if inst:
            have.append(t(a["ru"], a["en"]))
            continue
        if via == "pacman":
            pac += pkgs(a, "pacman")
        elif via == "aur":
            aur += pkgs(a, "aur")
        elif via == "flatpak":
            flat.append(a["flatpak"])
        elif via == "github":
            gh.append(a)
        else:
            skipped.append(t(a["ru"], a["en"]))
            continue
        # what comes along (spicetify with Spotify): pacman's when it has it, else the AUR's
        for p in pkgs(a, "extra"):
            if not pacman_installed([p]):
                (pac if pacman_has(p) else aur).append(p)
    if have:
        say(t("уже стоят: ", "installed already: ") + ", ".join(have))
    if pac or aur or flat or gh:
        say(t("angelOS ставит программы, которые ты выбрал ♡", "angelOS is installing the apps you picked ♡"))
    failed = set()
    if "steam" in pac:
        pac = [d for d in vulkan_drivers() if not pacman_installed([d])] + pac
    if pac:
        say(t("из репозиториев: ", "from the repositories: ") + " ".join(pac))
        if not batch(["sudo", "pacman", "-Syu", "--needed"], ["sudo", "pacman", "-S", "--needed", "--noconfirm"], pac):
            failed.add("pacman")
    if aur:
        helper = ensure_paru()
        if helper:
            # names the AUR doesn't have (any more) are "not found", not a failure of the rest
            gone = aur_missing(aur)
            for i in ids:
                a = cat.get(i)
                if a and set(pkgs(a, "aur")) & set(gone) and resolve(a)[1] == "aur":
                    skipped.append(t(a["ru"], a["en"]))
            aur = [n for n in aur if n not in gone]
            if aur:
                say(t(f"из AUR ({helper}): ", f"from the AUR ({helper}): ") + " ".join(aur))
                if not batch([helper, "-S", "--needed", "--noconfirm"], [helper, "-S", "--needed", "--noconfirm"], aur):
                    failed.add(helper)
        else:
            failed.add("paru")
    if flat:
        if not shutil.which("flatpak"):
            subprocess.run(["sudo", "pacman", "-S", "--needed", "--noconfirm", "flatpak"])
        say(t("из Flathub: ", "from Flathub: ") + " ".join(flat))
        subprocess.run(["flatpak", "remote-add", "--user", "--if-not-exists", "flathub",
                        "https://dl.flathub.org/repo/flathub.flatpakrepo"])
        fp = ["flatpak", "install", "--user", "-y", "--noninteractive", "flathub"]
        if not batch(fp, fp, flat):
            failed.add("flatpak")
    for a in gh:
        if not github_install(a):
            failed.add("GitHub")
    if "spotify" in ids:
        spicetify()
    # install.sh's picker has no «Which browser?»: the first ticked one, in the catalog's order
    if browser == "auto":
        browser = next((b for b in catalog().get("browsers", []) if b in ids), "")
    set_browser(browser)
    # what is there now, not what the package managers said: a picked app that is missing
    # must not be reported as installed (its shortcut would lead nowhere)
    done, missing = [], []
    for i in ids:
        a = cat.get(i)
        if not a:
            continue
        name = t(a["ru"], a["en"])
        if name not in have:
            (done if installed(a) else missing).append(name)
    if done:
        say(t("поставлены: ", "installed: ") + ", ".join(done))
    if missing:
        nowhere = [m for m in missing if m in skipped]
        broke = [m for m in missing if m not in skipped]
        if broke:
            say(t(f"\033[1;31mне поставились\033[0m: {', '.join(broke)} (ошибка {', '.join(sorted(failed)) or 'установки'} — смотри выше)",
                  f"\033[1;31mnot installed\033[0m: {', '.join(broke)} ({', '.join(sorted(failed)) or 'install'} failed, see above)"))
        if nowhere:
            say(t(f"\033[1;31mне нашлись\033[0m ни в репозиториях, ни в AUR, ни во Flathub: {', '.join(nowhere)}",
                  f"\033[1;31mnot found\033[0m in the repositories, the AUR or Flathub: {', '.join(nowhere)}"))
        say(t("запустить снова: Настройки → Аккаунт → мастер", "again: Settings → Account → the wizard"))
        notify("-u", "critical", "-i", "dialog-warning", t("Не все программы поставились", "Not every app installed"), ", ".join(missing))
    elif done:
        say(t("готово ♡ — ", "done ♡ — ") + ", ".join(done))
        notify("-i", "system-software-install", t("Программы поставлены ♡", "Apps installed ♡"), ", ".join(done))
    return finish(1 if missing else 0, wait)


def spicetify():
    """Spotify in the author's theme: spicetify's config came with the dotfiles; applying it needs
    Spotify itself, which spotify-launcher downloads on its first start — until then the shell's
    scripts/spicetify-apply.sh (run at login) waits for it"""
    script = Path(__file__).resolve().parent / "spicetify-apply.sh"
    if script.exists():
        subprocess.run(["bash", str(script)])


def repo_arg(args):
    if "--repo" in args:
        i = args.index("--repo")
        if i + 1 < len(args):
            return args[i + 1]
    return os.environ.get("ANGELOS_DOTFILES", "")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    rest = sys.argv[2:]
    wait = "--no-wait" not in rest
    rest = [a for a in rest if a != "--no-wait"]
    browser = ""
    if "--browser" in rest:
        i = rest.index("--browser")
        browser = rest[i + 1] if i + 1 < len(rest) else ""
        rest = rest[:i] + rest[i + 2:]
    if cmd == "status":
        status()
    elif cmd == "groups":
        groups()
    elif cmd == "tsv":
        tsv()
    elif cmd == "install":
        sys.exit(install(rest, wait, browser))
    elif cmd == "pick":
        remember(rest)
        if browser:
            set_browser(browser)
    elif cmd == "browsers":
        browsers()
    elif cmd == "browser" and len(rest) == 1:
        sys.exit(0 if set_browser(rest[0]) else 1)
    elif cmd == "pending":
        print(json.dumps(pending(repo_arg(rest))))
    elif cmd == "sync":
        sys.exit(sync(repo_arg(rest), wait))
    elif cmd == "ack":
        ack(repo_arg(rest))
    else:
        print(__doc__)
        sys.exit(2)
