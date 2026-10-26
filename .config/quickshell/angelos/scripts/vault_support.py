#!/usr/bin/env python3
"""Manager-neutral protocol helpers used by bundled password-manager adapters."""

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
FIELDS = ("password", "username", "totp")
SERVICE = "angelos-vault"
PIN_TRIES = 5
MARKS = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "angelos", "vault-saved.json")


def t(ru, en):
    return ru if RU else en


def out(obj):
    json.dump(obj, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def run(argv, env=None, stdin=None, timeout=40):
    e = dict(os.environ)
    for key in ("ANGELOS_VAULT_PW", "ANGELOS_VAULT_SESSION"):
        e.pop(key, None)
    e.update(env or {})
    try:
        done = subprocess.run(argv, env=e, input=stdin, stdin=None if stdin is not None else subprocess.DEVNULL,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    except FileNotFoundError:
        return 127, "", argv[0] + ": not found"
    except subprocess.TimeoutExpired:
        return 124, "", t("не ответил за ", "no answer in ") + str(timeout) + t(" с", " s")
    err = [line for line in done.stderr.decode("utf-8", "replace").strip().splitlines() if line.strip()]
    return done.returncode, done.stdout.decode("utf-8", "replace"), err[-1].strip() if err else ""


def marks():
    try:
        with open(MARKS, encoding="utf-8") as handle:
            value = json.load(handle)
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def mark(plugin_id, value):
    data = marks()
    if value is None:
        data.pop(plugin_id, None)
    else:
        data[plugin_id] = value
    os.makedirs(os.path.dirname(MARKS), mode=0o700, exist_ok=True)
    temp = MARKS + ".tmp"
    with open(os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w", encoding="utf-8") as handle:
        json.dump(data, handle)
    os.replace(temp, MARKS)


def saved_mode(plugin_id):
    return (marks().get(plugin_id) or {}).get("mode", "") if shutil.which("secret-tool") else ""


def keyring(what, plugin_id, label, value=None):
    argv = ["secret-tool", what]
    if what == "store":
        argv += ["--label", "angelOS: " + label]
    argv += ["service", SERVICE, "backend", plugin_id]
    code, text, err = run(argv, stdin=value.encode() if value is not None else None, timeout=30)
    return code == 0, text if code == 0 else err


def stream(key, nonce, length):
    blocks = [hmac.new(key, nonce + i.to_bytes(4, "big"), hashlib.sha256).digest() for i in range(length // 32 + 1)]
    return b"".join(blocks)[:length]


def seal(secret, pin):
    salt, nonce = os.urandom(16), os.urandom(16)
    key = hashlib.scrypt(pin.encode(), salt=salt, n=2 ** 15, r=8, p=1, maxmem=2 ** 27, dklen=64)
    data = secret.encode()
    cipher = bytes(a ^ b for a, b in zip(data, stream(key[:32], nonce, len(data))))
    tag = hmac.new(key[32:], nonce + cipher, hashlib.sha256).hexdigest()
    return {"mode": "pin", "salt": salt.hex(), "nonce": nonce.hex(), "ct": cipher.hex(), "tag": tag}


def unseal(blob, pin):
    try:
        salt = bytes.fromhex(blob["salt"])
        nonce = bytes.fromhex(blob["nonce"])
        cipher = bytes.fromhex(blob["ct"])
        key = hashlib.scrypt(pin.encode(), salt=salt, n=2 ** 15, r=8, p=1, maxmem=2 ** 27, dklen=64)
        if not hmac.compare_digest(hmac.new(key[32:], nonce + cipher, hashlib.sha256).hexdigest(), blob["tag"]):
            return None
        return bytes(a ^ b for a, b in zip(cipher, stream(key[:32], nonce, len(cipher)))).decode()
    except (KeyError, ValueError):
        return None


def forget(backend):
    keyring("clear", backend.plugin_id, backend.name)
    mark(backend.plugin_id, None)


def remember(backend, password, pin):
    if not backend.remembers:
        return {"ok": False, "error": t("этот менеджер спрашивает сам", "this manager asks by itself")}
    if not shutil.which("secret-tool"):
        return {"ok": False, "error": t("нет secret-tool (пакет libsecret) — хранить негде", "no secret-tool (the libsecret package): nowhere to keep it")}
    if pin is not None and len(pin) < 4:
        return {"ok": False, "error": t("PIN — хотя бы 4 знака", "a PIN is 4 characters at least")}
    result = backend.unlock(password)
    if not result.get("ok"):
        return result
    blob = seal(password, pin) if pin is not None else {"mode": "keyring", "pw": password}
    ok, err = keyring("store", backend.plugin_id, backend.name, json.dumps(blob))
    if not ok:
        return dict(result, saved="", error=t("связка ключей не приняла: ", "the keyring refused: ") + err)
    mark(backend.plugin_id, {"mode": blob["mode"], "tries": 0})
    return dict(result, saved=blob["mode"])


def unlock_saved(backend, pin):
    saved = marks().get(backend.plugin_id) or {}
    ok, text = keyring("lookup", backend.plugin_id, backend.name) if saved else (False, "")
    try:
        blob = json.loads(text) if ok else None
    except ValueError:
        blob = None
    if not blob:
        mark(backend.plugin_id, None)
        return {"ok": False, "ask": "password", "saved": "", "error": t("запомненного пароля нет — введи мастер-пароль", "nothing is remembered: type the master password")}
    if blob.get("mode") == "pin":
        if not pin:
            return {"ok": False, "ask": "pin", "saved": "pin", "error": ""}
        password = unseal(blob, pin)
        if password is None:
            tries = int(saved.get("tries", 0)) + 1
            if tries >= PIN_TRIES:
                forget(backend)
                return {"ok": False, "ask": "password", "saved": "", "error": t("PIN не подошёл %d раз — он забыт, введи мастер-пароль", "the PIN was wrong %d times: it is forgotten, type the master password") % tries}
            mark(backend.plugin_id, {"mode": "pin", "tries": tries})
            return {"ok": False, "ask": "pin", "saved": "pin", "error": t("PIN не подошёл (ещё попыток: %d)", "wrong PIN (%d more tries)") % (PIN_TRIES - tries)}
    else:
        password = blob.get("pw", "")
    result = backend.unlock(password)
    if result.get("ok"):
        if saved.get("tries"):
            mark(backend.plugin_id, {"mode": blob.get("mode", "keyring"), "tries": 0})
        return dict(result, saved=blob.get("mode", "keyring"))
    if backend.status()[0] == "locked":
        forget(backend)
        return {"ok": False, "ask": "password", "saved": "", "error": t("запомненный мастер-пароль больше не подходит — введи новый", "the remembered master password no longer fits: type the new one")}
    return dict(result, saved=blob.get("mode", "keyring"))


def clip(backend, item, field, clear):
    secret, error = backend.secret(item, field)
    if not error and not secret:
        error = t("в записи этого нет", "the entry has none")
    if error:
        return {"ok": False, "error": error, "field": field, "clear": clear}
    try:
        args = ["wl-copy"]
        if b"--sensitive" in subprocess.run(["wl-copy", "--help"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=5).stdout:
            args.append("--sensitive")
    except (OSError, subprocess.TimeoutExpired):
        return {"ok": False, "error": t("нет wl-copy (пакет wl-clipboard)", "no wl-copy (the wl-clipboard package)"), "field": field, "clear": clear}
    done = subprocess.run(args + ["--type", "text/plain;charset=utf-8"], input=secret.encode(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if done.returncode:
        return {"ok": False, "error": "wl-copy: %d" % done.returncode, "field": field, "clear": clear}
    if clear > 0:
        digest = hashlib.sha256(secret.encode()).hexdigest()
        subprocess.Popen([sys.executable, os.path.abspath(__file__), "_clear", str(clear), digest], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return {"ok": True, "error": "", "field": field, "clear": clear}


def clear_later(seconds, digest):
    time.sleep(seconds)
    try:
        current = subprocess.run(["wl-paste", "--no-newline"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=4).stdout
    except (OSError, subprocess.TimeoutExpired):
        return 0
    if hashlib.sha256(current).hexdigest() == digest:
        subprocess.run(["wl-copy", "--clear"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return 0


def serve(backend, argv):
    command = argv[0] if argv else "status"
    args = argv[1:]
    if command == "status":
        cli = backend.cli
        row = {"id": backend.plugin_id, "name": backend.name, "cli": cli, "installed": shutil.which(cli) is not None,
               "state": "missing", "account": "", "ask": backend.ask, "saved": saved_mode(backend.plugin_id),
               "remembers": backend.remembers}
        if row["installed"]:
            row["state"], row["account"], _ = backend.status()
        out({"backends": [row]})
        return 0
    if command == "list":
        try:
            rows = [dict(row, backend=backend.plugin_id) for row in backend.items()]
            out({"items": rows, "errors": {}})
            return 0
        except (RuntimeError, ValueError) as exc:
            out({"items": [], "errors": {backend.plugin_id: str(exc)}})
            return 1
    if command in ("unlock", "remember", "forget", "copy", "lock", "sync", "install", "login"):
        args = [arg for arg in args if arg != backend.plugin_id]
    if command == "unlock":
        typed = "--stdin" in args
        saved = "--saved" in args
        args = [arg for arg in args if arg not in ("--stdin", "--saved")]
        result = unlock_saved(backend, sys.stdin.readline().rstrip("\r\n") if typed else "") if saved else backend.unlock(sys.stdin.readline().rstrip("\r\n") if typed else "")
        out(result)
        return 0 if result.get("ok") else 1
    if command == "remember":
        pin = "--pin" in args
        password = sys.stdin.readline().rstrip("\r\n")
        result = remember(backend, password, sys.stdin.readline().rstrip("\r\n") if pin else None)
        out(result)
        return 0 if result.get("ok") else 1
    if command == "forget":
        forget(backend)
        out({"ok": True})
        return 0
    if command == "copy":
        clear = 30
        if "--clear" in args:
            index = args.index("--clear")
            try:
                clear = max(0, int(args[index + 1]))
            except (IndexError, ValueError):
                pass
            args = args[:index]
        if len(args) != 2 or args[1] not in FIELDS:
            out({"ok": False, "error": "usage: vault.py copy ITEM password|username|totp"})
            return 2
        result = clip(backend, args[0], args[1], clear)
        out(result)
        return 0 if result.get("ok") else 1
    if command == "lock":
        out({"ok": backend.lock()})
        return 0
    if command == "sync":
        ok, error = backend.sync()
        out({"ok": ok, "errors": {backend.plugin_id: error} if error else {}})
        return 0 if ok else 1
    if command in ("install", "login"):
        return backend.interactive(command)
    if command == "_clear" and len(args) == 2:
        return clear_later(int(args[0]), args[1])
    out({"ok": False, "error": "unknown command"})
    return 2


if __name__ == "__main__" and len(sys.argv) == 4 and sys.argv[1] == "_clear":
    sys.exit(clear_later(int(sys.argv[2]), sys.argv[3]))
