#!/usr/bin/env python3
"""The setup wizard's apps (data/apps-catalog.json): what is there, and installing the picked ones.

  apps-install.py status            JSON {id: {"installed": bool, "via": "pacman|aur|flatpak|"}}
  apps-install.py install ID…       in a terminal (the wizard opens one when it ends): the
                                    distribution's packages with sudo pacman, the AUR's with
                                    paru/yay, Flathub's per user; asks before each, says what it
                                    skipped and why, waits for Enter at the end

Each app: its pacman package if a repository has it (CachyOS has helium-browser-bin, Arch's
AUR does), else the AUR when paru or yay is there, else its Flathub id when flatpak is.
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "data/apps-catalog.json"


def run(cmd, **kw):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, **kw)


def apps():
    return {a["id"]: a for a in json.loads(CATALOG.read_text())["apps"]}


def pacman_installed(pkg):
    return bool(pkg) and run(["pacman", "-Q", pkg]).returncode == 0


def pacman_has(pkg):
    return bool(pkg) and shutil.which("pacman") and run(["pacman", "-Si", pkg]).returncode == 0


def flatpak_installed(app_id):
    return bool(app_id) and shutil.which("flatpak") and run(["flatpak", "info", app_id]).returncode == 0


def aur_helper():
    return next((h for h in ("paru", "yay") if shutil.which(h)), "")


def resolve(a):
    """(installed, via)"""
    if pacman_installed(a.get("pacman")) or pacman_installed(a.get("aur")) or flatpak_installed(a.get("flatpak")):
        return True, ""
    if pacman_has(a.get("pacman")):
        return False, "pacman"
    if a.get("aur") and aur_helper():
        return False, "aur"
    if a.get("flatpak") and shutil.which("flatpak"):
        return False, "flatpak"
    return False, ""


def status():
    out = {}
    for i, a in apps().items():
        inst, via = resolve(a)
        out[i] = {"installed": inst, "via": via}
    print(json.dumps(out))


def say(text):
    print(f"\033[1;35m»\033[0m {text}", flush=True)


def install(ids):
    cat = apps()
    pac, aur, flat, skipped = [], [], [], []
    for i in ids:
        a = cat.get(i)
        if not a:
            continue
        inst, via = resolve(a)
        if inst:
            say(f"{a['ru']} уже стоит")
        elif via == "pacman":
            pac.append(a["pacman"])
        elif via == "aur":
            aur.append(a["aur"])
        elif via == "flatpak":
            flat.append(a["flatpak"])
        else:
            skipped.append(a["ru"])
    say("angelOS ставит программы, которые ты выбрал в мастере ♡")
    rc = 0
    if pac:
        say("из репозиториев: " + " ".join(pac))
        rc |= subprocess.run(["sudo", "pacman", "-S", "--needed"] + pac).returncode
    if aur:
        helper = aur_helper()
        say(f"из AUR ({helper}): " + " ".join(aur))
        rc |= subprocess.run([helper, "-S", "--needed"] + aur).returncode
    if flat:
        say("из Flathub: " + " ".join(flat))
        subprocess.run(["flatpak", "remote-add", "--user", "--if-not-exists", "flathub",
                        "https://dl.flathub.org/repo/flathub.flatpakrepo"])
        rc |= subprocess.run(["flatpak", "install", "--user", "-y", "flathub"] + flat).returncode
    if skipped:
        say("не нашлось ни в репозиториях, ни в AUR, ни во Flathub: " + ", ".join(skipped))
    names = [cat[i]["ru"] for i in ids if i in cat]
    if rc == 0:
        say("готово ♡ — " + ", ".join(names))
        subprocess.run(["notify-send", "-a", "angelOS", "-i", "system-software-install", "Программы поставлены ♡", ", ".join(names)])
    else:
        say("что-то не поставилось — смотри выше; запустить снова: Настройки → Аккаунт → мастер")
    try:
        input("\nEnter — закрыть окно ")
    except EOFError:
        pass
    return rc


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "status":
        status()
    elif cmd == "install":
        sys.exit(install(sys.argv[2:]))
    else:
        print(__doc__)
        sys.exit(2)
