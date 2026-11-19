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

class Bw:
    id = "bw"
    ask = "password"

    def env(self):
        s = os.environ.get("ANGELOS_VAULT_SESSION", "")
        return {"BW_SESSION": s, "BW_NOINTERACTION": "true"} if s else {"BW_NOINTERACTION": "true"}

    def status(self):
        code, text, err = run(["bw", "status"], self.env())
        try:
            d = json.loads(text.strip().splitlines()[-1])
        except (ValueError, IndexError):
            return "setup", "", err
        state = {"unlocked": "unlocked", "locked": "locked"}.get(d.get("status"), "setup")
        return state, d.get("userEmail") or "", ""

    def items(self):
        code, text, err = run(["bw", "list", "items"], self.env(), timeout=60)
        if code != 0:
            raise RuntimeError(err or "bw list items: %d" % code)
        rows = []
        for it in json.loads(text or "[]"):
            login = it.get("login") if it.get("type") == 1 else None
            if login is None:
                continue
            uris = login.get("uris") or []
            rows.append({"id": it.get("id", ""), "name": it.get("name") or "", "user": login.get("username") or "",
                         "url": (uris[0].get("uri") or "") if uris else "", "totp": bool(login.get("totp"))})
        return rows

    def unlock(self, password):
        if not password:
            return {"ok": False, "ask": "password", "error": ""}
        code, text, err = run(["bw", "unlock", "--passwordenv", "ANGELOS_VAULT_PW", "--raw"],
                              {"ANGELOS_VAULT_PW": password, "BW_NOINTERACTION": "true"})
        key = text.strip().splitlines()[-1].strip() if text.strip() else ""
        if code != 0 or not key:
            return {"ok": False, "ask": "password", "error": err or t("не подошёл", "that didn't work")}
        return {"ok": True, "session": key}

    def lock(self):
        return run(["bw", "lock"], self.env())[0] == 0

    def sync(self):
        code, _, err = run(["bw", "sync"], self.env(), timeout=90)
        return code == 0, err

    def secret(self, item, field):
        code, text, err = run(["bw", "get", field, item], self.env())
        return (text.strip("\r\n"), "") if code == 0 else ("", err or "bw get: %d" % code)

    def login(self):
        code, text, _ = run(["bw", "status"], {"BW_NOINTERACTION": "true"})
        try:
            current = json.loads(text.strip().splitlines()[-1]).get("serverUrl") or ""
        except (ValueError, IndexError):
            current = ""
        if current.rstrip("/") in ("https://vault.bitwarden.com", "https://bitwarden.com"):
            current = ""
        url = ask_server(current)
        if url != current or (current and server_url(current) is None):
            # "null" is bw's word for its own default
            subprocess.call(["bw", "config", "server", url or "null"], stdout=subprocess.DEVNULL)
        return subprocess.call(["bw", "login"])


BACKEND = Bw()
BACKEND.plugin_id = os.environ.get("ANGELOS_VAULT_BACKEND_ID", "bw")
BACKEND.name = "Bitwarden"
BACKEND.cli = "bw"
BACKEND.remembers = True


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
