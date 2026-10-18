#!/usr/bin/env python3
"""Colour saturation per monitor on NVIDIA: Digital Vibrance through nvibrant
(github.com/Tremeschin/nVibrant, GPL-3.0; ioctls on /dev/nvidia-modeset, no root) —
services/ScreenTune, Settings → Monitor → Brightness and colour.

usage: vibrance.py status              JSON: {"nvidia", "driver", "ready", "error"}
       vibrance.py set NAME=LEVEL …    LEVEL −1…1 (0 = as at boot, −1 grey, 1 = 200 %),
                                       NAME a niri output (DP-1, HDMI-A-1)

nvibrant ships one binary per driver version, so the first `set` fetches the release
wheel (pinned, SHA-256 checked) into ~/.local/share/angelos/nvibrant and keeps the
binary for this driver; a driver newer than the pin falls back to the latest release,
and one no release knows yet gets it built here (git + g++, the driver's own headers).
nvibrant numbers the GPU's physical ports (HDMI, DP, DP, HDMI…) and takes one value
for each in that order; the n-th connected port of a kind is the n-th connected DRM
connector of that kind (HDMI-A-1, DP-1…), which is how names map onto ports.
"""
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

PIN = ("v1.3.0", "nvibrant-1.3.0-py3-none-manylinux_2_17_x86_64.whl",
       "d60a080b52e4a16e16d16a7d4b6405a32a3fe1b8ee0df65dc3685213ef0393e8")
REPO = "Tremeschin/nVibrant"
MAIN_SHA = "2117557edb14a11e9e9506193b896aacc446a12ab2cfd00dd3d9ec221e131d28"   # nvibrant/main.cpp at PIN, for build()
HOME = Path.home()
DIR = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share")) / "angelos/nvibrant"


def driver():
    try:
        m = re.search(r"Kernel Module(?: for \S+)?\s+([\d.]+)", Path("/proc/driver/nvidia/version").read_text())
        return m.group(1) if m else ""
    except OSError:
        return ""


def binary_path(ver):
    return DIR / ver / "nvibrant"


def fetch(url, sha=None):
    req = urllib.request.Request(url, headers={"User-Agent": "angelOS"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    if sha and hashlib.sha256(data).hexdigest() != sha:
        raise RuntimeError("checksum mismatch for " + url)
    return data


def extract(wheel, ver):
    with zipfile.ZipFile(io.BytesIO(wheel)) as z:
        want = [n for n in z.namelist() if n.endswith("/nvibrant-" + ver)]
        if not want:
            return False
        dst = binary_path(ver)
        dst.parent.mkdir(parents=True, exist_ok=True)
        tmp = dst.with_suffix(".tmp")
        tmp.write_bytes(z.read(want[0]))
        tmp.chmod(0o755)
        tmp.replace(dst)
        return True


def ensure(ver):
    b = binary_path(ver)
    if b.exists():
        return b
    tag, name, sha = PIN
    if extract(fetch("https://github.com/%s/releases/download/%s/%s" % (REPO, tag, name), sha), ver):
        return b
    # a driver newer than the pinned release: the latest one may know it
    rel = json.loads(fetch("https://api.github.com/repos/%s/releases/latest" % REPO))
    for a in rel.get("assets", []):
        if a.get("name", "").endswith(".whl") and "x86_64" in a.get("name", ""):
            if extract(fetch(a["browser_download_url"]), ver):
                return b
    return build(ver)


def build(ver):
    """No release for this driver yet: nvibrant is one main.cpp against the driver's own
    headers (open-gpu-kernel-modules, tagged by driver version), so build it here"""
    cxx = shutil.which("c++") or shutil.which("g++")
    if not cxx or not shutil.which("git"):
        raise RuntimeError("nvibrant has no build for driver " + ver + " yet, and building it needs git and g++ (base-devel)")
    src = fetch("https://raw.githubusercontent.com/%s/%s/nvibrant/main.cpp" % (REPO, PIN[0]), MAIN_SHA)
    with tempfile.TemporaryDirectory(prefix="nvibrant-") as tmp:
        og = os.path.join(tmp, "og")
        dirs = ["src/nvidia-modeset/interface", "src/nvidia-modeset/include", "src/common/inc",
                "src/common/sdk/nvidia/inc", "src/common/unix/common/inc"]
        git = ["git", "-c", "advice.detachedHead=false"]
        subprocess.run(git + ["clone", "-q", "--depth", "1", "--branch", ver, "--filter=blob:none", "--sparse",
                              "https://github.com/NVIDIA/open-gpu-kernel-modules", og],
                       check=True, capture_output=True, timeout=300)
        subprocess.run(git + ["-C", og, "sparse-checkout", "set"] + dirs, check=True, capture_output=True, timeout=300)
        Path(tmp, "main.cpp").write_bytes(src)
        dst = binary_path(ver)
        dst.parent.mkdir(parents=True, exist_ok=True)
        out = dst.with_suffix(".tmp")
        r = subprocess.run([cxx, "-O2", "-o", str(out), os.path.join(tmp, "main.cpp")] + ["-I" + os.path.join(og, d) for d in dirs],
                           capture_output=True, text=True, timeout=300)
        if r.returncode:
            raise RuntimeError("building nvibrant for driver " + ver + " failed: " + (r.stderr.strip().splitlines() or ["?"])[-1])
        out.replace(dst)
    return dst


def connected():
    """kind -> [connector names], connected ones, by number (HDMI-A-1 before HDMI-A-2)"""
    out = {}
    for c in sorted(Path("/sys/class/drm").glob("card*-*")):
        try:
            if (c / "status").read_text().strip() != "connected":
                continue
        except OSError:
            continue
        name = c.name.split("-", 1)[1]                     # DP-1, HDMI-A-1, eDP-1
        kind = "HDMI" if name.startswith("HDMI") else "DP" if name.startswith(("DP", "eDP")) else name.split("-")[0]
        out.setdefault(kind, []).append(name)
    for v in out.values():
        v.sort(key=lambda n: [int(x) if x.isdigit() else x for x in re.split(r"(\d+)", n)])
    return out


PORT_RE = re.compile(r"\((\d+),\s*(\w+)\s*\).*•\s*(Success|None|Fail\w*)", re.I)


def run(binary, values):
    r = subprocess.run([str(binary)] + [str(v) for v in values], capture_output=True, text=True, timeout=10)
    found = []
    for line in r.stdout.splitlines():
        m = PORT_RE.search(line)
        if m:
            found.append((int(m.group(1)), m.group(2).upper(), m.group(3).lower() == "success"))
    return r.returncode, found


def status():
    ver = driver()
    print(json.dumps({"nvidia": bool(ver) and Path("/dev/nvidia-modeset").exists(), "driver": ver,
                      "ready": bool(ver) and binary_path(ver).exists()}))


def set_levels(pairs):
    ver = driver()
    if not ver or not Path("/dev/nvidia-modeset").exists():
        print(json.dumps({"ok": False, "error": "not an NVIDIA GPU"}))
        return 1
    want = {}
    for p in pairs:
        name, _, lv = p.partition("=")
        try:
            want[name] = max(-1.0, min(1.0, float(lv)))
        except ValueError:
            pass
    b = ensure(ver)
    # which port is which: learnt from a run (every port to 0 for a moment), then kept
    # for this set of connected monitors so a slider doesn't flicker the others
    conn = connected()
    cache = DIR / "ports.json"
    key = json.dumps(conn, sort_keys=True)
    try:
        saved = json.loads(cache.read_text())
    except (OSError, ValueError):
        saved = {}
    if saved.get("key") == key and saved.get("driver") == ver:
        index_of, n = saved["index"], saved["n"]
    else:
        code, found = run(b, [])
        by_kind = {}
        for idx, kind, has in found:
            if has:
                by_kind.setdefault(kind, []).append(idx)
        index_of = {}
        for kind, idxs in by_kind.items():
            for idx, name in zip(idxs, conn.get(kind, [])):
                index_of[name] = idx
        n = max([i for i, _, _ in found] + [-1]) + 1
        cache.write_text(json.dumps({"key": key, "driver": ver, "index": index_of, "n": n}))
    values = [0] * n
    for name, lv in want.items():
        if name in index_of:
            values[index_of[name]] = round(lv * 1023) if lv > 0 else round(lv * 1024)
    code, _ = run(b, values)
    print(json.dumps({"ok": code == 0, "ports": index_of, "values": values,
                      "unknown": sorted(set(want) - set(index_of))}))
    return 0 if code == 0 else 1


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    try:
        if cmd == "status":
            return status()
        if cmd == "set":
            return set_levels(sys.argv[2:])
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}))
        return 1
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main() or 0)
