#!/usr/bin/env python3
import os
import sys
from pathlib import Path

CORE = Path(os.environ.get("ANGELOS_VAULT_CORE", str(Path(__file__).resolve().parents[2] / "scripts")))
sys.path.insert(0, str(CORE))
from vault_support import *  # noqa: E402,F401,F403

SERVER_RE = re.compile(r"(https?://)?[A-Za-z0-9]([A-Za-z0-9.\-]*[A-Za-z0-9])?(:\d{1,5})?(/[^\s@]*)?\Z")
REGIONS = {"eu": "https://vault.bitwarden.eu", "us": ""}


def server_url(text):
    """What was typed for «a server of your own» → its URL; "" = the usual bitwarden.com; None =
    not an address at all (an e-mail typed here once became bw's server, and nothing signed in)."""
    text = (text or "").strip().rstrip("/")
    if text.lower() in REGIONS or text == "":
        return REGIONS.get(text.lower(), "")
    if "@" in text or not SERVER_RE.match(text) or ("." not in text and "localhost" not in text):
        return None
    return text if "://" in text else "https://" + text


def ask_server(current):
    """current: the server set now ("" = bitwarden.com). → the one to use ("" = bitwarden.com)."""
    broken = current != "" and server_url(current) is None
    if broken:
        print(t("Вместо сервера была записана не та строка (%s) — возвращаю обычный bitwarden.com.",
                "Something that is no server was set as the server (%s): back to the usual bitwarden.com.") % current)
        current = ""
    for _ in range(3):
        if current:
            print(t("Сейчас сервер: %s. Enter — оставить его; «нет» — обычный bitwarden.com; или другой адрес (https://…):",
                    "The server now: %s. Enter keeps it; “no” is the usual bitwarden.com; or another address (https://…):") % current)
        else:
            print(t("Обычный Bitwarden? Тогда просто нажми Enter — почту и пароль спросит следующий шаг.\n"
                    "(Только если у тебя свой сервер Vaultwarden — впиши его адрес, https://…; европейский Bitwarden — eu.)",
                    "The usual Bitwarden? Then just press Enter: the e-mail and the password are the next step's.\n"
                    "(Only with a Vaultwarden server of your own: type its address, https://…; Bitwarden's European one: eu.)"))
        typed = input("> ").strip()
        if typed == "":
            return current
        if typed.lower() in ("нет", "no", "n", "н"):
            return ""
        url = server_url(typed)
        if url is not None:
            return url
        print(t("Это не адрес сервера%s. Почту спросит сам менеджер на следующем шаге.\n",
                "That is no server's address%s. The manager itself asks for the e-mail in the next step.\n")
              % (t(" — похоже на почту", ": it looks like an e-mail") if "@" in typed else ""))
    return current

class Rbw:
    id = "rbw"
    ask = "own"

    def email(self):
        code, text, _ = run(["rbw", "config", "show"])
        try:
            return (json.loads(text).get("email") or "") if code == 0 else ""
        except ValueError:
            return ""

    def status(self):
        email = self.email()
        if not email:
            return "setup", "", ""
        return ("unlocked" if run(["rbw", "unlocked"])[0] == 0 else "locked"), email, ""

    def items(self):
        # never asked while locked: rbw would open its pinentry out of nowhere
        if run(["rbw", "unlocked"])[0] != 0:
            raise RuntimeError(t("закрыто", "locked"))
        code, text, err = run(["rbw", "list", "--fields", "id,name,user,folder,type"], timeout=60)
        if code != 0:
            raise RuntimeError(err or "rbw list: %d" % code)
        rows = []
        for line in text.splitlines():
            cell = line.split("\t")
            if len(cell) < 3 or (len(cell) > 4 and cell[4].strip().lower() not in ("login", "")):
                continue
            rows.append({"id": cell[0], "name": cell[1], "user": cell[2], "url": "", "totp": None})
        return rows

    def unlock(self, password):
        code, _, err = run(["rbw", "unlock"], timeout=180)
        if code != 0 and "error: 400" in err:
            # bitwarden.com turns an unregistered device away; `rbw register` wants the account's API key
            err = t("rbw не зарегистрирован в Bitwarden: ему нужен ключ API (веб-хранилище → Настройки → Безопасность → Ключи, "
                    "затем `rbw register`). Проще — войти через обычный Bitwarden строкой выше: ему ключ не нужен.",
                    "rbw is not registered with Bitwarden: it needs the API key (web vault → Settings → Security → Keys, "
                    "then `rbw register`). Easier: sign in with the plain Bitwarden above, which needs no key.")
        return {"ok": True, "session": ""} if code == 0 else {"ok": False, "ask": "own", "error": err or "rbw unlock: %d" % code}

    def lock(self):
        return run(["rbw", "lock"])[0] == 0

    def sync(self):
        code, _, err = run(["rbw", "sync"], timeout=90)
        return code == 0, err

    def secret(self, item, field):
        if run(["rbw", "unlocked"])[0] != 0:
            return "", t("закрыто", "locked")
        argv = ["rbw", "code", item] if field == "totp" else ["rbw", "get", "--field", field, item]
        code, text, err = run(argv)
        return (text.strip("\r\n"), "") if code == 0 else ("", err or "rbw: %d" % code)

    def login(self):
        email = self.email()
        if not email:
            print(t("Почта аккаунта Bitwarden:", "The e-mail of your Bitwarden account:"))
            email = input("> ").strip()
            if "@" not in email:
                print(t("Это не почта.", "That is no e-mail."))
                return 1
            subprocess.call(["rbw", "config", "set", "email", email])
            url = ask_server("")
            if url:
                subprocess.call(["rbw", "config", "set", "base_url", url])
        code = subprocess.call(["rbw", "login"])
        if code != 0:
            # bitwarden.com wants a new device registered with the account's API key first
            print(t("\nBitwarden просит зарегистрировать устройство: ключ API — в веб-хранилище, "
                    "Настройки → Безопасность → Ключи.", "\nBitwarden wants this device registered: the API key is "
                    "in the web vault, Settings → Security → Keys."))
            if subprocess.call(["rbw", "register"]) == 0:
                code = subprocess.call(["rbw", "login"])
        return code


BACKEND = Rbw()
BACKEND.plugin_id = os.environ.get("ANGELOS_VAULT_BACKEND_ID", "rbw")
BACKEND.name = "Bitwarden (rbw)"
BACKEND.cli = "rbw"
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
