#!/usr/bin/env python3
"""`angelos setup skip`: out of the first-run wizard, also when the shell cannot answer.

The wizard holds the desktop until it is done (modules/settings/SetupWizard). If it breaks,
a new user must not stay locked in: from a terminal or a text console (Ctrl+Alt+F3)
`angelos setup skip` leaves ~/.config/angelos/setup-skipped first — a shell started after
that never holds the desktop — and then asks the running shell to let go at once.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys

RU = os.environ.get("LC_ALL", os.environ.get("LC_MESSAGES", os.environ.get("LANG", ""))).startswith("ru")


def t(ru, en):
    return ru if RU else en


def main(args):
    if args != ["skip"]:
        print(t("Как: angelos setup [skip]", "Usage: angelos setup [skip]"), file=sys.stderr)
        return 2

    # the same folder as Config.dir (~/.config/angelos, XDG_CONFIG_HOME is not followed there)
    marker = Path.home() / ".config/angelos/setup-skipped"
    try:
        marker.parent.mkdir(parents=True, exist_ok=True)
        with marker.open("a") as stream:
            os.fsync(stream.fileno())
    except OSError as error:
        print(t(f"Не удалось сохранить метку {marker}: {error}",
                f"Could not save the skip marker {marker}: {error}"), file=sys.stderr)
        return 1

    print(t("Мастер пропущен: при следующем запуске он рабочий стол не закроет.",
            "Setup skipped: the next start won't hold the desktop."), flush=True)
    qs = shutil.which("qs") or str(Path.home() / ".local/bin/qs")
    try:
        # a text console has no WAYLAND_DISPLAY: the shell is found on any display
        result = subprocess.run(
            [qs, "-c", "angelos", "ipc", "--any-display", "call", "angelos", "setupSkip"],
            capture_output=True, text=True, timeout=2,
        )
        # a void IPC call answers with nothing; an older shell (or none) may still exit 0
        # with an error line (as updates-cli.py knows)
        errors = ("Function not found", "No running instances", "No instance")
        answered = result.returncode == 0 and not any(
            line.strip().startswith(errors)
            for line in (result.stdout + "\n" + result.stderr).splitlines()
        )
    except (OSError, subprocess.TimeoutExpired):
        answered = False
    if answered:
        print(t("Рабочий стол свободен.", "The desktop is free."))
    else:
        print(t("Оболочка не ответила. Если экран всё ещё закрыт мастером: angelos restart",
                "The shell did not answer. If the wizard still covers the screen: angelos restart"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
