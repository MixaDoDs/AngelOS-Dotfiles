#!/usr/bin/env python3
"""angelOS's little programs for the setup wizard's «Scripts» step (and Settings → Games):
what is there, what runs, switching the services.

  features.py status                 JSON {gameMode, mouse, voice, privacy, ocr, shot, record}:
                                     {"installed", "enabled"} each; mouse also "devices" (the
                                     USB mice) and "uinput" (a virtual mouse may be made); voice
                                     also "model" (the Whisper model is there)
  features.py set game-mode on|off   niri-game-mode.service (games: no animations, performance)
  features.py set mouse on|off       mouse-coalesce.service (the rate is settings.json
                                     gaming.mouseRate, read each time a game starts)
  features.py set voice on|off       voxtype.service + its indicator (installing it:
                                     scripts/voxtype-install.sh)
"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
BIN = HOME / ".local/bin"
UNITS = {"game-mode": ["niri-game-mode.service"], "mouse": ["mouse-coalesce.service"],
         "voice": ["voxtype.service", "voxtype-indicator.service"]}


def have(name):
    return (BIN / name).is_file() or bool(shutil.which(name))


def enabled(unit):
    r = subprocess.run(["systemctl", "--user", "is-enabled", unit], capture_output=True, text=True)
    return r.stdout.strip() in ("enabled", "enabled-runtime", "static", "alias")


def mice():
    out = []
    for p in sorted(Path("/dev/input/by-id").glob("*-event-mouse")):
        # usb-Vendor_Model_Serial-event-mouse → "Vendor Model"
        name = p.name.removeprefix("usb-").removesuffix("-event-mouse").rsplit("_", 1)[0].replace("_", " ")
        if name not in out:
            out.append(name)
    return out


def status():
    models = HOME / ".local/share" / "voxtype" / "models"
    return {
        "gameMode": {"installed": have("niri-game-mode"), "enabled": enabled("niri-game-mode.service")},
        "mouse": {"installed": have("mouse-coalesce"), "enabled": enabled("mouse-coalesce.service"),
                  "devices": mice(), "uinput": os.access("/dev/uinput", os.W_OK)},
        "voice": {"installed": have("voxtype"), "enabled": enabled("voxtype.service"),
                  "model": any(models.glob("*large-v3-turbo*")) if models.is_dir() else False},
        "privacy": {"installed": have("niri-cast-privacy"), "enabled": True},
        "ocr": {"installed": have("niri-ocr") and bool(shutil.which("tesseract")), "enabled": True},
        # Circle to Search (scripts/circle.py): reading needs tesseract, translating needs trans
        "circle": {"installed": bool(shutil.which("tesseract") and shutil.which("grim")), "enabled": True,
                   "translate": bool(shutil.which("trans"))},
        "shot": {"installed": have("niri-screenshot-region"), "enabled": True},
        "record": {"installed": have("niri-record-region") and bool(shutil.which("wf-recorder")), "enabled": True},
    }


def set_unit(what, on):
    units = UNITS[what]
    cmd = ["systemctl", "--user", "enable" if on else "disable", "--now", *units]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.returncode == 0, (r.stderr or "").strip().splitlines()[-1:] or [""]


def main():
    if sys.argv[1:] == ["status"] or not sys.argv[1:]:
        print(json.dumps(status(), ensure_ascii=False))
    elif len(sys.argv) == 4 and sys.argv[1] == "set" and sys.argv[2] in UNITS and sys.argv[3] in ("on", "off"):
        ok, why = set_unit(sys.argv[2], sys.argv[3] == "on")
        print(json.dumps({"ok": ok, "why": why[0]}))
        sys.exit(0 if ok else 1)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
