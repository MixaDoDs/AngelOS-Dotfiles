#!/usr/bin/env python3
"""`angelos updates` — Settings → Updates from a terminal.

  angelos updates [status] [--json]   where things stand (the repository, what's new, the last attempt)
  angelos updates check               fetch and say what's new
  angelos updates update              update, the log as it goes, then the outcome (exit 1 on a failure)

With angelOS running, the shell does the work (as its Updates page does, so the page, the
restart question and the record agree) and this follows it over IPC until the run ends.
Without it — or a shell too old to answer — scripts/dotfiles-update.sh runs right here.
"""
import json
import os
import shutil
import subprocess
import sys
import time

SHELL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(SHELL_DIR, "scripts", "dotfiles-update.sh")
RU = os.environ.get("LC_ALL", os.environ.get("LC_MESSAGES", os.environ.get("LANG", ""))).startswith("ru")


def t(ru, en):
    return ru if RU else en


def qs():
    return shutil.which("qs") or os.path.expanduser("~/.local/bin/qs")


# how long the shell may not answer during an update before it counts as gone
SILENT_LIMIT = 45


def ipc(arg, timeout=5):
    """the shell's answer to `updates <arg>`, or None when no shell answers it"""
    try:
        r = subprocess.run([qs(), "-c", "angelos", "ipc", "call", "angelos", "updates", arg],
                           capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None
    out = r.stdout.strip()
    if r.returncode != 0 or not out or out.startswith(("Function not found", "No running instances", "No instance")):
        return None
    return out


def status():
    out = ipc("status")
    try:
        return json.loads(out) if out else None
    except ValueError:
        return None


def summary(s):
    lines = []
    if s.get("repo"):
        lines.append(t("Репозиторий: ", "Repository: ") + s["repo"])
    if s.get("error"):
        lines.append("✕ " + s["error"])
    elif s.get("behind"):
        lines.append(t("Доступно изменений: ", "Changes available: ") + str(s["behind"]))
    elif s.get("lastStatus") in ("failed", "started"):
        lines.append(t("Последнее обновление не установилось.", "The last update did not install."))
    else:
        lines.append(t("У тебя последняя версия ♡", "You are up to date ♡"))
    if s.get("dirty"):
        lines.append(t(f"В папке репозитория свои правки ({s['dirty']}): обновление выключено, пока их не уберёшь (git stash -u).",
                       f"The repository folder has edits of its own ({s['dirty']}): updating is off until they're gone (git stash -u)."))
    if s.get("ahead"):
        lines.append(t(f"В репозитории своих коммитов: {s['ahead']} — перемотка невозможна (git pull --rebase или ./install.sh).",
                       f"The repository has {s['ahead']} commits of its own — no fast-forward (git pull --rebase, or ./install.sh)."))
    if s.get("trusted") is False:
        lines.append(t("origin — не тот репозиторий, из которого ставилась система: обновление выключено.",
                       "origin is not the repository this system came from: updating is off."))
    if s.get("failure"):
        lines.append("✕ " + s["failure"])
        if s.get("next"):
            lines.append("→ " + s["next"])
        if s.get("backup"):
            lines.append(t("Снимок: ", "Snapshot: ") + s["backup"])
    if s.get("needsRestart"):
        lines.append(t("Новая версия на диске, работает прошлая: angelos restart", "The new version is on disk, the old one runs: angelos restart"))
    return "\n".join(lines)


def follow(kind, timeout):
    """print the shell's log from now on until its run ends; the final status"""
    start = ipc("log 0")
    try:
        nxt = json.loads(start)["next"] if start else 0
        has_log = True
    except (ValueError, KeyError, TypeError):
        nxt, has_log = 0, False
    answer = ipc(kind)
    if answer is None:
        return None
    if answer.startswith("no repository"):
        print(t("Репозиторий dotfiles не найден — Настройки → Обновления → «Скачать dotfiles».",
                "No dotfiles repository found — Settings → Updates → Download dotfiles."), file=sys.stderr)
        return {"_exit": 2}
    if answer.startswith("busy"):
        print(t("Оболочка уже занята: ", "The shell is busy already: ") + answer.split(" ", 1)[-1] + t(" — жду конца.", " — waiting for it to end."))
    busy = {"checking", "updating", "cloning", "restoring"}
    deadline = time.time() + timeout
    seen_busy = False
    # pacman replaces Qt and Quickshell under a running update: `qs ipc` itself can fail to start
    # or answer for a while (the VM test, 25.10) — only this long without an answer is "stopped"
    silent_since = None
    while time.time() < deadline:
        time.sleep(0.4)
        if has_log and kind == "update":
            got = ipc(f"log {nxt}")
            try:
                d = json.loads(got)
                for line in d["lines"]:
                    print(line, flush=True)
                nxt = d["next"]
            except (ValueError, KeyError, TypeError):
                pass
        s = status()
        if s is None:
            silent_since = silent_since or time.time()
            if time.time() - silent_since < SILENT_LIMIT:
                continue
            print(t("Оболочка перестала отвечать.", "The shell stopped answering."), file=sys.stderr)
            return {"_exit": 1}
        silent_since = None
        if s["state"] in busy:
            seen_busy = True
        elif seen_busy or time.time() > deadline - timeout + 2:
            return s
    print(t("Не дождался конца — смотри Настройки → Обновления.", "Gave up waiting — see Settings → Updates."), file=sys.stderr)
    return {"_exit": 1}


def direct(args):
    """no shell to ask: the script itself, here"""
    found = subprocess.run(["bash", SCRIPT, "--find"], capture_output=True, text=True).stdout.strip()
    if not found:
        print(t("Репозиторий dotfiles не найден (его ищут в ~/.config/angelos/dotfiles-source и обычных местах).",
                "No dotfiles repository found (looked up in ~/.config/angelos/dotfiles-source and the usual places)."), file=sys.stderr)
        return 2
    if args[0] == "check":
        r = subprocess.run(["bash", SCRIPT, "--check", found], capture_output=True, text=True)
        v = {}
        inc = []
        for line in r.stdout.splitlines():
            k, _, rest = line.partition(" ")
            if k == "IN":
                inc.append(rest)
            else:
                v[k] = rest
        if "ERR" in v:
            print("✕ " + t("нет связи с репозиторием: ", "the repository can't be reached: ") + v["ERR"], file=sys.stderr)
            return 1
        print(t("Репозиторий: ", "Repository: ") + found)
        behind = int(v.get("BEHIND", "0") or 0)
        print(t("Доступно изменений: ", "Changes available: ") + str(behind) if behind else t("У тебя последняя версия ♡", "You are up to date ♡"))
        for c in inc:
            print("  ✧ " + c.split(" ", 1)[-1])
        if int(v.get("AHEAD", "0") or 0):
            print(t("В репозитории свои коммиты: ", "Commits of its own: ") + v["AHEAD"])
        if int(v.get("DIRTY", "0") or 0):
            print(t("Свои правки в папке репозитория: ", "Edits in the repository folder: ") + v["DIRTY"])
        return 0
    r = subprocess.run(["bash", SCRIPT, found])
    if r.returncode == 0:
        print(t("Обновлено. Работающая оболочка (если есть) ещё прошлая: angelos restart",
                "Updated. A running shell (if any) is still the old one: angelos restart"))
    return r.returncode


def main(argv):
    as_json = "--json" in argv
    args = [a for a in argv if a != "--json"] or ["status"]
    cmd = args[0]
    if cmd == "status":
        s = status()
        if s is None:
            print(t("angelOS не отвечает — `angelos updates check` проверит и без него.",
                    "angelOS doesn't answer — `angelos updates check` works without it."), file=sys.stderr)
            return 1
        print(json.dumps(s, ensure_ascii=False, indent=1) if as_json else summary(s))
        return 0
    if cmd in ("check", "update"):
        if status() is None:
            return direct(args)
        s = follow(cmd, 120 if cmd == "check" else 1800)
        if s is None:
            return direct(args)
        if "_exit" in s:
            return s["_exit"]
        if as_json:
            print(json.dumps(s, ensure_ascii=False, indent=1))
        else:
            print(summary(s))
        if cmd == "update":
            if s.get("lastRun") == "ok":
                print(t("✓ Обновление установлено. Оболочка спросит о перезапуске (или: angelos restart).",
                        "✓ The update is installed. The shell asks about a restart (or: angelos restart)."))
                return 0
            return 1
        return 1 if s.get("error") else 0
    if cmd in ("prompt", "later", "restart"):
        out = ipc(cmd)
        print(out or t("angelOS не отвечает", "angelOS doesn't answer"))
        return 0 if out else 1
    print(__doc__.strip().split("\n\n")[0])
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        print(t("\nПрервано: если обновление уже шло, оно продолжается в оболочке.",
                "\nInterrupted: an update that was running goes on in the shell."), file=sys.stderr)
        sys.exit(130)
