#!/usr/bin/env python3
import os
import sys
from pathlib import Path

CORE = Path(os.environ.get("ANGELOS_VAULT_CORE", str(Path(__file__).resolve().parents[2] / "scripts")))
sys.path.insert(0, str(CORE))
from vault_support import *  # noqa: E402,F401,F403

class Op:
    id = "op"
    ask = "own"

    def args(self):
        s = os.environ.get("ANGELOS_VAULT_SESSION", "")
        return ["--session", s] if s else []

    def status(self):
        code, text, err = run(["op", "account", "list", "--format", "json"])
        try:
            accounts = json.loads(text or "[]") if code == 0 else []
        except ValueError:
            accounts = []
        code, text, _ = run(["op", "whoami", "--format", "json"] + self.args())
        if code == 0:
            try:
                return "unlocked", json.loads(text).get("email") or "", ""
            except ValueError:
                return "unlocked", "", ""
        if not accounts:
            # with the desktop app's integration there may be no account on the CLI's own list
            return "setup", "", err
        return "locked", accounts[0].get("email") or "", ""

    def items(self):
        code, text, err = run(["op", "item", "list", "--categories", "Login", "--format", "json"] + self.args(), timeout=60)
        if code != 0:
            raise RuntimeError(err or "op item list: %d" % code)
        rows = []
        for it in json.loads(text or "[]"):
            urls = it.get("urls") or []
            url = next((u.get("href") for u in urls if u.get("primary")), urls[0].get("href") if urls else "")
            rows.append({"id": it.get("id", ""), "name": it.get("title") or "", "user": (it.get("additional_information") or "").replace("—", "").strip(),
                         "url": url or "", "totp": None})
        return rows

    def unlock(self, password):
        # the desktop app asks by itself (fingerprint, system password); without it the token
        # of `op signin --raw` is the session, the master password read from stdin
        code, text, err = run(["op", "signin", "--raw"], stdin=(password + "\n").encode() if password else None, timeout=180)
        if code != 0:
            return {"ok": False, "ask": "password", "error": err if password else ""}
        return {"ok": True, "session": text.strip()}

    def lock(self):
        return run(["op", "signout"] + self.args())[0] == 0

    def sync(self):
        return True, ""

    def secret(self, item, field):
        argv = ["op", "item", "get", item, "--otp"] if field == "totp" else ["op", "item", "get", item, "--fields", "label=" + field, "--reveal"]
        code, text, err = run(argv + self.args())
        return (text.strip("\r\n"), "") if code == 0 else ("", err or "op: %d" % code)

    def login(self):
        print(t("Проще всего — через приложение 1Password: Настройки → Разработчику → «Интеграция с 1Password CLI».\n"
                "Enter — уже включено; или впиши адрес входа (my.1password.com), чтобы войти без приложения:",
                "The easy way is the 1Password app: Settings → Developer → “Integrate with 1Password CLI”.\n"
                "Enter if that is on already; or type your sign-in address (my.1password.com) to sign in without the app:"))
        url = input("> ").strip()
        if url:
            return subprocess.call(["op", "account", "add", "--address", url])
        return subprocess.call(["op", "vault", "list"])


BACKEND = Op()
BACKEND.plugin_id = os.environ.get("ANGELOS_VAULT_BACKEND_ID", "op")
BACKEND.name = "1Password"
BACKEND.cli = "op"
BACKEND.remembers = False


def interactive(what):
    if what == "login" and not shutil.which(BACKEND.cli):
        print(t("Сначала поставим ", "First, installing ") + BACKEND.name + "…")
        if install() != 0 or not shutil.which(BACKEND.cli):
            code = 1
        else:
            code = BACKEND.login()
    else:
        code = install() if what == "install" else BACKEND.login()
    if what == "login" and code == 0 and shutil.which(BACKEND.cli) and BACKEND.status()[0] == "setup":
        code = 1
    print("\n" + (t("Готово ♡", "Done ♡") if code == 0 else t("Не получилось (код %d).", "That didn't work (code %d).") % code))
    if sys.stdin.isatty() and os.environ.get("ANGELOS_VAULT_NOWAIT") != "1":
        try:
            input(t("Enter — закрыть", "Enter closes this"))
        except (EOFError, KeyboardInterrupt):
            pass
    return code


def install():
    kind = os.environ.get("ANGELOS_VAULT_PACKAGE_MANAGER", "")
    package = os.environ.get("ANGELOS_VAULT_PACKAGE", "")
    doc = os.environ.get("ANGELOS_VAULT_DOCS", "")
    if not kind or not package:
        print(t("В manifest не описана установка этого менеджера.",
                "This manager has no installation metadata in its manifest."))
        return 1
    if not shutil.which("pacman"):
        print(t("Здесь нет pacman. Как поставить: ", "No pacman here. How to install it: ") + doc)
        return 1
    if kind == "pacman":
        return subprocess.call(["sudo", "pacman", "-S", "--needed", package])
    helper = shutil.which("paru") or shutil.which("yay")
    if not helper:
        print(t("Это пакет из AUR, а paru/yay нет. Как поставить: ", "It is an AUR package and there is no paru/yay: ") + doc)
        return 1
    return subprocess.call([helper, "-S", "--needed", package])


BACKEND.interactive = interactive

if __name__ == "__main__":
    sys.exit(serve(BACKEND, sys.argv[1:]))
