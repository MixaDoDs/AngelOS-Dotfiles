#!/usr/bin/env python3
"""Password managers for the shell (services/Vault, Settings → Apps → Passwords, the launcher's
`pw …`): Bitwarden through its own CLI (bw) or rbw, 1Password through op. One interface over the
three; a secret never reaches the shell — it goes from the manager's CLI straight to the
clipboard, marked sensitive (no clipboard history keeps it) and wiped a little later.

  vault.py status                 JSON {"backends": [{id, name, cli, installed, state, account,
                                  ask}]}; state: missing | setup | locked | unlocked;
                                  ask: password (the shell asks the master password) | own
                                  (the manager asks by itself: rbw's pinentry, 1Password's app)
  vault.py list ID…               JSON {"items": [{backend, id, name, user, url, totp}],
                                  "errors": {id: text}} — logins of the unlocked backends named;
                                  no passwords, no TOTP seeds
  vault.py unlock ID [--stdin]    JSON {"ok", "session", "error", "ask"}; --stdin: the master
                                  password is the first line of stdin (bw; op without its
                                  desktop app) — never an argument, never the shell's log
  vault.py remember ID [--pin]    stdin: the master password, then (--pin) a PIN of one's own. The
                                  master password is checked by unlocking, then kept in the login
                                  keyring (secret-tool; open while the user is logged in) — as it
                                  is, or (--pin) locked with the PIN. JSON as unlock, + "saved"
  vault.py unlock ID --saved [--stdin]
                                  unlock with what was remembered; --stdin: the PIN. Five wrong
                                  PINs, or a master password that no longer fits, forget it
  vault.py forget ID              drop what was remembered
  vault.py lock ID…               lock them (all three when none is named)
  vault.py sync ID…               fetch the vault again (bw, rbw)
  vault.py copy ID ITEM FIELD [--clear SECONDS]
                                  FIELD: password | username | totp → the clipboard; JSON {"ok",
                                  "error"}. After SECONDS (default 30, 0 = never) the clipboard
                                  is cleared if it still holds that secret
  vault.py install ID             in a terminal: install the manager's CLI
  vault.py login ID               in a terminal: sign in for the first time

The session keys of bw and op live in the shell's memory only and come in as $ANGELOS_BW_SESSION
and $ANGELOS_OP_SESSION; nothing is written to disk here.
"""
import hashlib
import hmac
import json
import os
import re
import shutil
import subprocess
import sys
import time

RU = os.environ.get("ANGELOS_LANG", "ru") != "en"
NAMES = {"bw": "Bitwarden", "rbw": "Bitwarden (rbw)", "op": "1Password"}
PACKAGES = {"bw": ("pacman", "bitwarden-cli"), "rbw": ("pacman", "rbw"), "op": ("aur", "1password-cli")}
DOCS = {"bw": "https://bitwarden.com/help/cli/", "rbw": "https://github.com/doy/rbw",
        "op": "https://developer.1password.com/docs/cli/get-started/"}
FIELDS = ("password", "username", "totp")


def t(ru, en):
    return ru if RU else en


def out(obj):
    json.dump(obj, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def run(argv, env=None, stdin=None, timeout=40):
    """(code, stdout, last line of stderr); the CLI never gets a terminal to ask on."""
    e = dict(os.environ)
    for k in ("ANGELOS_VAULT_PW", "ANGELOS_BW_SESSION", "ANGELOS_OP_SESSION"):
        e.pop(k, None)
    e.update(env or {})
    try:
        done = subprocess.run(argv, env=e, input=stdin, stdin=None if stdin is not None else subprocess.DEVNULL,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    except FileNotFoundError:
        return 127, "", argv[0] + ": not found"
    except subprocess.TimeoutExpired:
        return 124, "", t("не ответил за ", "no answer in ") + str(timeout) + t(" с", " s")
    err = [l for l in done.stderr.decode("utf-8", "replace").strip().splitlines() if l.strip()]
    return done.returncode, done.stdout.decode("utf-8", "replace"), err[-1].strip() if err else ""


# ---- the first sign-in's one question of ours: a server of one's own ----
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


# ---- Bitwarden's own CLI ----
class Bw:
    id = "bw"
    ask = "password"

    def env(self):
        s = os.environ.get("ANGELOS_BW_SESSION", "")
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


# ---- rbw: its agent keeps the vault open, its pinentry asks the master password ----
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


# ---- 1Password: its desktop app answers for the CLI (or a session token without the app) ----
class Op:
    id = "op"
    ask = "own"

    def args(self):
        s = os.environ.get("ANGELOS_OP_SESSION", "")
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


BACKENDS = {"bw": Bw(), "rbw": Rbw(), "op": Op()}


# ---- no master password each time: it waits in the login keyring, as it is or under a PIN ----
# The keyring (gnome-keyring, KWallet's secret service) is opened by the login itself, so "as it
# is" means: whoever sits at the unlocked session opens the vault. Under a PIN the keyring holds
# only the password locked with a key made from the PIN (scrypt; an HMAC-SHA256 keystream, then
# an HMAC over it) — a guard against someone at the keyboard, not against a program of the
# user's own that reads the keyring and tries every PIN.
SERVICE = "angelos-vault"
REMEMBERS = ("bw",)
PIN_TRIES = 5
MARKS = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "angelos", "vault-saved.json")


def marks():
    """{id: {"mode": keyring|pin, "tries": n}} — what is remembered (not the secret itself)"""
    try:
        with open(MARKS, encoding="utf-8") as f:
            d = json.load(f)
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def mark(bid, value):
    d = marks()
    if value is None:
        d.pop(bid, None)
    else:
        d[bid] = value
    os.makedirs(os.path.dirname(MARKS), mode=0o700, exist_ok=True)
    tmp = MARKS + ".tmp"
    with open(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w", encoding="utf-8") as f:
        json.dump(d, f)
    os.replace(tmp, MARKS)


def saved_mode(bid):
    return (marks().get(bid) or {}).get("mode", "") if shutil.which("secret-tool") else ""


def keyring(what, bid, value=None):
    """store / lookup / clear; → (ok, text)"""
    argv = ["secret-tool", what] + (["--label", "angelOS: " + NAMES[bid]] if what == "store" else []) + ["service", SERVICE, "backend", bid]
    code, text, err = run(argv, stdin=value.encode() if value is not None else None, timeout=30)
    return code == 0, text if code == 0 else err


def stream(key, nonce, n):
    blocks = [hmac.new(key, nonce + i.to_bytes(4, "big"), hashlib.sha256).digest() for i in range(n // 32 + 1)]
    return b"".join(blocks)[:n]


def seal(secret, pin):
    salt, nonce = os.urandom(16), os.urandom(16)
    key = hashlib.scrypt(pin.encode(), salt=salt, n=2 ** 15, r=8, p=1, maxmem=2 ** 27, dklen=64)
    data = secret.encode()
    ct = bytes(a ^ b for a, b in zip(data, stream(key[:32], nonce, len(data))))
    tag = hmac.new(key[32:], nonce + ct, hashlib.sha256).hexdigest()
    return {"mode": "pin", "salt": salt.hex(), "nonce": nonce.hex(), "ct": ct.hex(), "tag": tag}


def unseal(blob, pin):
    """the secret, or None when the PIN is not the one"""
    try:
        salt, nonce, ct = bytes.fromhex(blob["salt"]), bytes.fromhex(blob["nonce"]), bytes.fromhex(blob["ct"])
        key = hashlib.scrypt(pin.encode(), salt=salt, n=2 ** 15, r=8, p=1, maxmem=2 ** 27, dklen=64)
        if not hmac.compare_digest(hmac.new(key[32:], nonce + ct, hashlib.sha256).hexdigest(), blob["tag"]):
            return None
        return bytes(a ^ b for a, b in zip(ct, stream(key[:32], nonce, len(ct)))).decode()
    except (KeyError, ValueError):
        return None


def forget(bid):
    keyring("clear", bid)
    mark(bid, None)


def remember(bid, password, pin):
    if bid not in REMEMBERS:
        return {"ok": False, "error": t("этот менеджер спрашивает сам", "this manager asks by itself")}
    if not shutil.which("secret-tool"):
        return {"ok": False, "error": t("нет secret-tool (пакет libsecret) — хранить негде", "no secret-tool (the libsecret package): nowhere to keep it")}
    if pin is not None and len(pin) < 4:
        return {"ok": False, "error": t("PIN — хотя бы 4 знака", "a PIN is 4 characters at least")}
    res = BACKENDS[bid].unlock(password)
    if not res.get("ok"):
        return res
    blob = seal(password, pin) if pin is not None else {"mode": "keyring", "pw": password}
    ok, err = keyring("store", bid, json.dumps(blob))
    if not ok:
        return dict(res, saved="", error=t("связка ключей не приняла: ", "the keyring refused: ") + err)
    mark(bid, {"mode": blob["mode"], "tries": 0})
    return dict(res, saved=blob["mode"])


def unlock_saved(bid, pin):
    m = marks().get(bid) or {}
    ok, text = keyring("lookup", bid) if m else (False, "")
    try:
        blob = json.loads(text) if ok else None
    except ValueError:
        blob = None
    if not blob:
        mark(bid, None)
        return {"ok": False, "ask": "password", "saved": "", "error": t("запомненного пароля нет — введи мастер-пароль", "nothing is remembered: type the master password")}
    if blob.get("mode") == "pin":
        if not pin:
            return {"ok": False, "ask": "pin", "saved": "pin", "error": ""}
        password = unseal(blob, pin)
        if password is None:
            tries = int(m.get("tries", 0)) + 1
            if tries >= PIN_TRIES:
                forget(bid)
                return {"ok": False, "ask": "password", "saved": "", "error": t("PIN не подошёл %d раз — он забыт, введи мастер-пароль", "the PIN was wrong %d times: it is forgotten, type the master password") % tries}
            mark(bid, {"mode": "pin", "tries": tries})
            return {"ok": False, "ask": "pin", "saved": "pin", "error": t("PIN не подошёл (ещё попыток: %d)", "wrong PIN (%d more tries)") % (PIN_TRIES - tries)}
    else:
        password = blob.get("pw", "")
    res = BACKENDS[bid].unlock(password)
    if res.get("ok"):
        if m.get("tries"):
            mark(bid, {"mode": blob.get("mode", "keyring"), "tries": 0})
        return dict(res, saved=blob.get("mode", "keyring"))
    # the manager is the judge: signed out, or the master password was changed since
    if BACKENDS[bid].status()[0] == "locked":
        forget(bid)
        return {"ok": False, "ask": "password", "saved": "", "error": t("запомненный мастер-пароль больше не подходит — введи новый", "the remembered master password no longer fits: type the new one")}
    return dict(res, saved=blob.get("mode", "keyring"))


def named(ids, all_when_none=False):
    picked = [BACKENDS[i] for i in ids if i in BACKENDS]
    return picked or (list(BACKENDS.values()) if all_when_none else [])


def status():
    rows = []
    for b in BACKENDS.values():
        row = {"id": b.id, "name": NAMES[b.id], "cli": b.id, "installed": shutil.which(b.id) is not None,
               "state": "missing", "account": "", "ask": b.ask, "saved": saved_mode(b.id) if b.id in REMEMBERS else "",
               "remembers": b.id in REMEMBERS}
        if row["installed"]:
            row["state"], row["account"], _ = b.status()
        rows.append(row)
    out({"backends": rows})
    return 0


def items(ids):
    rows, errors = [], {}
    for b in named(ids):
        try:
            for r in b.items():
                if r["id"] and r["name"]:
                    rows.append(dict(r, backend=b.id))
        except (RuntimeError, ValueError) as e:
            errors[b.id] = str(e)
    rows.sort(key=lambda r: (r["name"].lower(), r["user"].lower()))
    out({"items": rows, "errors": errors})
    return 0


# ---- the clipboard: marked sensitive, wiped later if nothing else was copied meanwhile ----
def clip(secret, clear):
    data = secret.encode()
    argv = ["wl-copy"]
    try:
        if b"--sensitive" in subprocess.run(["wl-copy", "--help"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=5).stdout:
            argv.append("--sensitive")
    except (OSError, subprocess.TimeoutExpired):
        return t("нет wl-copy (пакет wl-clipboard)", "no wl-copy (the wl-clipboard package)")
    # wl-copy stays behind to serve the clipboard: it must not hold our pipes open
    done = subprocess.run(argv + ["--type", "text/plain;charset=utf-8"], input=data, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if done.returncode != 0:
        return "wl-copy: %d" % done.returncode
    if clear > 0:
        subprocess.Popen([sys.executable, os.path.abspath(__file__), "_clear", str(clear), hashlib.sha256(data).hexdigest()],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return ""


def clear_later(seconds, digest):
    time.sleep(seconds)
    try:
        now = subprocess.run(["wl-paste", "--no-newline"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=4).stdout
    except (OSError, subprocess.TimeoutExpired):
        return 0
    if hashlib.sha256(now).hexdigest() == digest:
        subprocess.run(["wl-copy", "--clear"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return 0


def copy(argv):
    clear = 30
    if "--clear" in argv:
        i = argv.index("--clear")
        try:
            clear = max(0, int(argv[i + 1]))
        except (IndexError, ValueError):
            pass
        argv = argv[:i] + argv[i + 2:]
    if len(argv) != 3 or argv[0] not in BACKENDS or argv[2] not in FIELDS:
        out({"ok": False, "error": "usage: vault.py copy ID ITEM password|username|totp"})
        return 2
    secret, err = BACKENDS[argv[0]].secret(argv[1], argv[2])
    if not err and not secret:
        err = t("в записи этого нет", "the entry has none")
    err = err or clip(secret, clear)
    out({"ok": not err, "error": err, "field": argv[2], "clear": clear})
    return 1 if err else 0


def install(bid):
    kind, package = PACKAGES[bid]
    if not shutil.which("pacman"):
        print(t("Здесь нет pacman. Как поставить: ", "No pacman here. How to install it: ") + DOCS[bid])
        return 1
    if kind == "pacman":
        return subprocess.call(["sudo", "pacman", "-S", "--needed", package])
    helper = shutil.which("paru") or shutil.which("yay")
    if not helper:
        print(t("Это пакет из AUR, а paru/yay нет. Как поставить: ", "It is an AUR package and there is no paru/yay. How to install it: ") + DOCS[bid])
        return 1
    return subprocess.call([helper, "-S", "--needed", package])


def interactive(what, bid):
    """a step in a terminal: the result stays on screen until Enter"""
    if bid not in BACKENDS:
        print("vault.py %s bw|rbw|op" % what)
        return 2
    try:
        if what == "login" and not shutil.which(bid):
            print(t("Сначала поставим ", "First, installing ") + NAMES[bid] + "…")
            if install(bid) != 0 or not shutil.which(bid):
                code = 1
            else:
                code = BACKENDS[bid].login()
        else:
            code = install(bid) if what == "install" else BACKENDS[bid].login()
    except (EOFError, KeyboardInterrupt):
        code = 130
    # the manager's own word for it: a sign-in that was left halfway is not "done"
    if what == "login" and code == 0 and shutil.which(bid) and BACKENDS[bid].status()[0] == "setup":
        code = 1
    print("\n" + (t("Готово ♡", "Done ♡") if code == 0 else t("Не получилось (код %d).", "That didn't work (code %d).") % code))
    if sys.stdin.isatty() and os.environ.get("ANGELOS_VAULT_NOWAIT") != "1":
        try:
            input(t("Enter — закрыть", "Enter closes this"))
        except (EOFError, KeyboardInterrupt):
            pass
    return code


def main(argv):
    cmd = argv[0] if argv else "status"
    rest = argv[1:]
    if cmd == "status":
        return status()
    if cmd == "list":
        return items(rest)
    if cmd == "unlock":
        typed = "--stdin" in rest
        saved = "--saved" in rest
        rest = [a for a in rest if a not in ("--stdin", "--saved")]
        if len(rest) != 1 or rest[0] not in BACKENDS:
            out({"ok": False, "error": "usage: vault.py unlock bw|rbw|op [--saved] [--stdin]"})
            return 2
        if saved:
            res = unlock_saved(rest[0], sys.stdin.readline().rstrip("\r\n") if typed else "")
            out(res)
            return 0 if res.get("ok") else 1
        res = BACKENDS[rest[0]].unlock(sys.stdin.readline().rstrip("\r\n") if typed else "")
        out(res)
        return 0 if res.get("ok") else 1
    if cmd == "remember":
        pin = "--pin" in rest
        rest = [a for a in rest if a != "--pin"]
        if len(rest) != 1 or rest[0] not in BACKENDS:
            out({"ok": False, "error": "usage: vault.py remember bw [--pin]"})
            return 2
        password = sys.stdin.readline().rstrip("\r\n")
        res = remember(rest[0], password, sys.stdin.readline().rstrip("\r\n") if pin else None)
        out(res)
        return 0 if res.get("ok") else 1
    if cmd == "forget":
        for b in named(rest):
            forget(b.id)
        out({"ok": True})
        return 0
    if cmd == "lock":
        out({"ok": all([b.lock() for b in named(rest, True) if shutil.which(b.id)])})
        return 0
    if cmd == "sync":
        errors = {}
        for b in named(rest):
            ok, err = b.sync()
            if not ok:
                errors[b.id] = err
        out({"ok": not errors, "errors": errors})
        return 1 if errors else 0
    if cmd == "copy":
        return copy(rest)
    if cmd == "_clear" and len(rest) == 2:
        return clear_later(int(rest[0]), rest[1])
    if cmd in ("install", "login"):
        return interactive(cmd, rest[0] if rest else "")
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
