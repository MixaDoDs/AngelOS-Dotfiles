#!/usr/bin/env python3
"""The setup wizard's apps (data/apps-catalog.json): what is there, and installing the picked ones.

  apps-install.py status            JSON {id: {"installed": bool, "via": "pacman|aur|flatpak|"}}
  apps-install.py install ID…       in a terminal (the wizard opens one when it ends): the
                                    distribution's packages with sudo pacman -Syu (a plain -S on
                                    an old package list fails halfway with 404s), the AUR's with
                                    paru/yay, Flathub's per user; asks before each, then checks
                                    each app is really there and says which are not and why
                                    (exit 1 then), waits for Enter at the end

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
    failed = set()
    if pac:
        say("из репозиториев: " + " ".join(pac))
        if subprocess.run(["sudo", "pacman", "-Syu", "--needed"] + pac).returncode:
            failed.add("pacman")
    if aur:
        helper = aur_helper()
        say(f"из AUR ({helper}): " + " ".join(aur))
        if subprocess.run([helper, "-S", "--needed"] + aur).returncode:
            failed.add(helper)
    if flat:
        say("из Flathub: " + " ".join(flat))
        subprocess.run(["flatpak", "remote-add", "--user", "--if-not-exists", "flathub",
                        "https://dl.flathub.org/repo/flathub.flatpakrepo"])
        if subprocess.run(["flatpak", "install", "--user", "-y", "flathub"] + flat).returncode:
            failed.add("flatpak")
    # what is there now, not what the package managers said: a picked app that is missing
    # must not be reported as installed (its shortcut would lead nowhere)
    done, missing = [], []
    for i in ids:
        a = cat.get(i)
        if not a:
            continue
        (done if resolve(a)[0] else missing).append(a["ru"])
    if done:
        say("стоят: " + ", ".join(done))
    if missing:
        nowhere = [m for m in missing if m in skipped]
        broke = [m for m in missing if m not in skipped]
        if broke:
            say(f"\033[1;31mне поставились\033[0m: {', '.join(broke)} (ошибка {', '.join(sorted(failed)) or 'установки'} — смотри выше)")
        if nowhere:
            say(f"\033[1;31mне нашлись\033[0m ни в репозиториях, ни в AUR, ни во Flathub: {', '.join(nowhere)}"
                " (для AUR нужен paru или yay, для Flathub — flatpak)")
        say("запустить снова: Настройки → Аккаунт → мастер")
        subprocess.run(["notify-send", "-a", "angelOS", "-u", "critical", "-i", "dialog-warning",
                        "Не все программы поставились", ", ".join(missing)])
    else:
        say("готово ♡ — " + ", ".join(done))
        subprocess.run(["notify-send", "-a", "angelOS", "-i", "system-software-install", "Программы поставлены ♡", ", ".join(done)])
    rc = 1 if missing else 0
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
