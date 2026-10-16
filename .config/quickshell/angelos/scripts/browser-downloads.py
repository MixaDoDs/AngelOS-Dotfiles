#!/usr/bin/env python3
"""angelOS: the browsers' half of the Halo's download progress.

A file being downloaded doesn't know its full size; only the browser does. So a small extension
(data/browser-downloads: the WebExtension `downloads` API, the same in Chromium and Firefox)
tells it, through the native host scripts/browser-downloads-host.py, into
$XDG_RUNTIME_DIR/angelos-browser-downloads.json. Without it the Halo still sees every download in
~/Downloads (any browser or program), only without the percent.

  browser-downloads.py ensure   put it into every browser found (idempotent, quiet)
  browser-downloads.py remove   take it out of all of them
  browser-downloads.py status   JSON: per browser — installed, wired, running since before

Chromium family (Helium, Chromium, Brave): the unpacked extension named in the launcher's flags
file (--load-extension, one line, other paths kept — browser-theme.py's theme shares it) and the
host's manifest in <profile root>/NativeMessagingHosts. Branded Chrome/Edge ignore
--load-extension: there only the host goes in. Firefox family: the host's manifest only — a
release Firefox installs signed add-ons alone (the extension's id is downloads@angelos).
A browser reads its flags when it starts: one already open needs a restart once.
"""
import json
import os
import shutil
import sys
from pathlib import Path

HOME = Path(os.environ.get("HOME") or Path.home())
CONF = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share")
SHELL = Path(__file__).resolve().parent.parent
SRC = SHELL / "data/browser-downloads"
EXT = DATA / "angelos/browser-downloads"           # the copy the browsers load (stable path)
HOST = SHELL / "scripts/browser-downloads-host.py"
NAME = "org.angelos.downloads"
CHROME_ID = "mblodkbgkjnmhkbecpmfgjannflbgncc"      # from the manifest's "key"
GECKO_ID = "downloads@angelos"
FLAG = "--load-extension="

CHROMIUMS = [
    # id, name, binaries, profile root under ~/.config, flags file (None = it reads none)
    ("helium", "Helium", ["helium-browser", "/opt/helium-browser-bin/helium"], "net.imput.helium", "helium-browser-flags.conf"),
    ("chromium", "Chromium", ["chromium", "/usr/lib/chromium/chromium"], "chromium", "chromium-flags.conf"),
    ("brave", "Brave", ["brave", "brave-browser", "/opt/brave-bin/brave"], "BraveSoftware/Brave-Browser", "brave-flags.conf"),
    ("vivaldi", "Vivaldi", ["vivaldi-stable", "vivaldi"], "vivaldi", None),
    ("chrome", "Google Chrome", ["google-chrome-stable", "google-chrome"], "google-chrome", None),
    ("edge", "Microsoft Edge", ["microsoft-edge-stable"], "microsoft-edge", None),
]
FIREFOXES = [
    ("firefox", "Firefox", ["firefox", "firefox-developer-edition", "firefox-nightly"], [".mozilla", ".config/mozilla"]),
    ("librewolf", "LibreWolf", ["librewolf"], [".librewolf"]),
    ("zen", "Zen", ["zen-browser", "zen"], [".zen"]),
    ("floorp", "Floorp", ["floorp"], [".floorp"]),
]


def which(bins):
    for b in bins:
        if os.path.isabs(b) and os.access(b, os.X_OK):
            return b
        p = shutil.which(b)
        if p:
            return p
    return None


def write(path, text):
    """write only when it differs; True if it changed"""
    try:
        if path.read_text() == text:
            return False
    except OSError:
        pass
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".angelos-tmp")
    tmp.write_text(text)
    tmp.replace(path)
    return True


def remove(path):
    try:
        path.unlink()
        return True
    except OSError:
        return False


def chromium_host():
    return json.dumps({"name": NAME, "description": "angelOS: download progress for the Halo", "path": str(HOST),
                       "type": "stdio", "allowed_origins": ["chrome-extension://%s/" % CHROME_ID]}, indent=2) + "\n"


def firefox_host():
    return json.dumps({"name": NAME, "description": "angelOS: download progress for the Halo", "path": str(HOST),
                       "type": "stdio", "allowed_extensions": [GECKO_ID]}, indent=2) + "\n"


def loaded(text):
    out = []
    for line in text.splitlines():
        if line.strip().startswith(FLAG):
            out += [x for x in line.strip()[len(FLAG):].split(",") if x]
    return out


def flags_set(path, on):
    """our path into the one --load-extension line (Chromium reads the last such flag only) or out"""
    try:
        old = path.read_text()
    except OSError:
        old = ""
    me = str(EXT)
    lines, done = [], False
    for line in old.splitlines():
        if line.strip().startswith(FLAG):
            paths = [x for x in line.strip()[len(FLAG):].split(",") if x and x != me]
            if on and not done:
                paths.append(me)
                done = True
            if paths:
                lines.append(FLAG + ",".join(paths))
            continue
        lines.append(line)
    if on and not done:
        lines += ["# angelOS: download progress in the Halo (browser-downloads.py remove takes it out)", FLAG + me]
    if not on:
        lines = [l for l in lines if "browser-downloads.py remove" not in l]
    new = "\n".join(lines) + "\n" if lines else ""
    if new == old:
        return False
    if old:
        keep = path.with_name(path.name + ".angelos-before-downloads")
        if not keep.exists():
            keep.write_text(old)
    if new:
        write(path, new)
    else:
        remove(path)
    return True


def copy_extension():
    changed = False
    for f in SRC.iterdir():
        if f.is_file():
            changed |= write(EXT / f.name, f.read_text())
    return changed


def chromiums():
    for bid, name, bins, root, flags in CHROMIUMS:
        exe = which(bins)
        if exe:
            yield bid, name, exe, CONF / root, (CONF / flags if flags else None)


def firefoxes():
    for bid, name, bins, roots in FIREFOXES:
        exe = which(bins)
        if exe:
            yield bid, name, exe, [HOME / r for r in roots]


def ensure():
    changed = copy_extension()
    for bid, name, exe, root, flags in chromiums():
        changed |= write(root / "NativeMessagingHosts" / (NAME + ".json"), chromium_host())
        if flags:
            changed |= flags_set(flags, True)
    for bid, name, exe, roots in firefoxes():
        for r in roots:
            if r.is_dir():
                changed |= write(r / "native-messaging-hosts" / (NAME + ".json"), firefox_host())
    return changed


def remove_all():
    for bid, name, bins, root, flags in CHROMIUMS:
        remove(CONF / root / "NativeMessagingHosts" / (NAME + ".json"))
        if flags and (CONF / flags).exists():
            flags_set(CONF / flags, False)
    for bid, name, bins, roots in FIREFOXES:
        for r in roots:
            remove(HOME / r / "native-messaging-hosts" / (NAME + ".json"))
    shutil.rmtree(EXT, ignore_errors=True)


def started(bins):
    """start times of the processes running one of these binaries (a launcher script such as
    /usr/bin/helium-browser execs the real one: all of them are looked for)"""
    real = set()
    for b in bins:
        p = b if os.path.isabs(b) else shutil.which(b)
        if p:
            real.add(os.path.realpath(p))
    out = []
    for p in Path("/proc").iterdir():
        if not p.name.isdigit():
            continue
        try:
            if os.path.realpath(p / "exe") not in real:
                continue
            out.append(os.stat(p).st_mtime)
        except OSError:
            pass
    return out


def status():
    res = []
    bins_of = {c[0]: c[2] for c in CHROMIUMS}
    for bid, name, exe, root, flags in chromiums():
        wired = bool(flags) and str(EXT) in loaded(flags.read_text() if flags.exists() else "")
        since = flags.stat().st_mtime if wired else 0
        # /proc/<pid>'s own time is when it started; a browser older than the flag hasn't read it
        runs = started(bins_of[bid])
        res.append({"id": bid, "name": name, "kind": "chromium", "wired": wired,
                    "restart": wired and any(t < since for t in runs), "percent": wired})
    for bid, name, exe, roots in firefoxes():
        res.append({"id": bid, "name": name, "kind": "firefox", "wired": False, "restart": False, "percent": False})
    return res


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "status"
    if cmd == "ensure":
        ensure()
        print(json.dumps(status(), ensure_ascii=False))
    elif cmd == "remove":
        remove_all()
    elif cmd == "status":
        print(json.dumps(status(), ensure_ascii=False))
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
