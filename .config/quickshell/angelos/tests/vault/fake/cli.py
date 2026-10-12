#!/usr/bin/env python3
"""Stand-ins for bw, rbw, op, wl-copy and wl-paste (tests/vault; run as `cli.py TOOL ARGS…` by the
wrappers the tests put on PATH): the same commands and the same
shapes of output as the real ones, over a state file in $FAKE_VAULT_DIR. Nothing here talks to
a real vault or to the real clipboard.

state.json: {"bw": "out|locked", "bw_session": "", "rbw": "unset|locked|unlocked", "rbw_deny": false,
             "op": "out|locked|open", "op_app": false, "op_session": ""}
"""
import json
import os
import sys
from pathlib import Path

DIR = Path(os.environ["FAKE_VAULT_DIR"])
MASTER = "correct horse"
LOGINS = [
    {"id": "11111111-aaaa", "name": "GitHub", "user": "angel@example.com", "password": "gh-secret-1", "url": "https://github.com/login", "totp": "123456"},
    {"id": "22222222-bbbb", "name": "Почта", "user": "ангел", "password": "пароль-ё", "url": "https://mail.example.org", "totp": ""},
    {"id": "33333333-cccc", "name": "Wi-Fi дома", "user": "", "password": "wifi pass with spaces", "url": "", "totp": ""},
]


def state():
    try:
        return json.loads((DIR / "state.json").read_text())
    except (OSError, ValueError):
        return {}


def save(s):
    (DIR / "state.json").write_text(json.dumps(s))


def log(tool, args):
    with open(DIR / "calls.log", "a") as f:
        f.write(tool + " " + " ".join(args) + "\n")


def die(text, code=1):
    sys.stderr.write(text + "\n")
    sys.exit(code)


def by_id(i):
    return next((l for l in LOGINS if l["id"] == i), None) or die("Not found.")


def bw(a):
    s = state()
    mode = s.get("bw", "out")
    key = s.get("bw_session", "")
    opened = mode != "out" and key != "" and os.environ.get("BW_SESSION") == key
    if a[:2] == ["config", "server"]:
        if len(a) == 2:
            print(s.get("bw_server") or "https://bitwarden.com")
            return 0
        s["bw_server"] = None if a[2] == "null" else (a[2] if "://" in a[2] else "https://" + a[2])
        save(s)
        print("Saved setting `config`.")
        return 0
    if a[:1] == ["login"]:
        # the real one asks the e-mail and the password itself; a server that is none cannot answer
        if s.get("bw_server") and "@" in s["bw_server"]:
            die("Error: KDF config is required")
        s["bw"] = "locked"
        save(s)
        print("You are logged in!")
        return 0
    if a[:1] == ["status"]:
        if mode == "out":
            print(json.dumps({"serverUrl": s.get("bw_server"), "lastSync": None, "status": "unauthenticated"}))
        else:
            print(json.dumps({"serverUrl": s.get("bw_server"), "lastSync": "2026-10-11T10:00:00.000Z", "userEmail": "angel@example.com",
                              "userId": "u-1", "status": "unlocked" if opened else "locked"}))
        return 0
    if mode == "out":
        die("You are not logged in.")
    if a[:1] == ["unlock"]:
        var = a[a.index("--passwordenv") + 1] if "--passwordenv" in a else ""
        if os.environ.get(var) != MASTER:
            die("Invalid master password.")
        s["bw_session"] = "session-%d" % (len(key) + 1)
        save(s)
        print(s["bw_session"])
        return 0
    if a[:1] == ["lock"]:
        s["bw_session"] = ""
        save(s)
        print("Your vault is locked.")
        return 0
    if not opened:
        die("Vault is locked.")
    if a[:1] == ["sync"]:
        print("Syncing complete.")
        return 0
    if a[:2] == ["list", "items"]:
        rows = [{"object": "item", "id": l["id"], "type": 1, "name": l["name"], "folderId": None,
                 "login": {"username": l["user"] or None, "password": l["password"], "totp": l["totp"] or None,
                           "uris": [{"match": None, "uri": l["url"]}] if l["url"] else []}} for l in LOGINS]
        rows.append({"object": "item", "id": "99999999-note", "type": 2, "name": "Заметка", "notes": "secret note", "secureNote": {"type": 0}})
        print(json.dumps(rows))
        return 0
    if a[:1] == ["get"] and len(a) == 3:
        l = by_id(a[2])
        value = {"password": l["password"], "username": l["user"], "totp": l["totp"]}.get(a[1], "")
        if not value:
            die("No %s available for this login." % a[1].upper())
        sys.stdout.write(value)
        return 0
    die("fake bw: " + " ".join(a), 2)


def rbw(a):
    s = state()
    mode = s.get("rbw", "unset")
    if a[:2] == ["config", "show"]:
        if mode == "unset":
            die("rbw config show: failed to load config: No such file or directory (os error 2)")
        print(json.dumps({"email": "angel@example.com", "base_url": None, "lock_timeout": 3600, "pinentry": "pinentry"}))
        return 0
    if a[:1] == ["unlocked"]:
        if mode != "unlocked":
            die("rbw unlocked: agent not running")
        return 0
    if a[:3] == ["config", "set", "email"]:
        s["rbw"], s["rbw_email"] = "locked", a[3]
        save(s)
        return 0
    if a[:3] == ["config", "set", "base_url"]:
        s["rbw_url"] = a[3]
        save(s)
        return 0
    if a[:1] == ["login"]:
        return 0
    if a[:1] == ["unlock"]:
        if mode == "unset" or s.get("rbw_deny"):
            die("rbw unlock: failed to read password from pinentry: operation cancelled")
        s["rbw"] = "unlocked"
        save(s)
        return 0
    if a[:1] == ["lock"]:
        if mode == "unlocked":
            s["rbw"] = "locked"
            save(s)
        return 0
    if mode != "unlocked":
        # the real one would open its pinentry here: the helper must never get this far
        (DIR / "pinentry-opened").write_text(" ".join(a))
        die("rbw: pinentry")
    if a[:1] == ["sync"]:
        return 0
    if a[:1] == ["list"]:
        for l in LOGINS:
            print("\t".join([l["id"], l["name"], l["user"], "", "Login"]))
        print("\t".join(["99999999-note", "Заметка", "", "", "Note"]))
        return 0
    if a[:1] == ["get"] and "--field" in a:
        l = by_id(a[-1])
        value = {"password": l["password"], "username": l["user"]}.get(a[a.index("--field") + 1], "")
        if not value:
            die("rbw get: entry has no such field")
        print(value)
        return 0
    if a[:1] == ["code"]:
        l = by_id(a[-1])
        if not l["totp"]:
            die("rbw code: entry does not contain a totp secret")
        print(l["totp"])
        return 0
    die("fake rbw: " + " ".join(a), 2)


def op(a):
    s = state()
    mode = s.get("op", "out")
    token = a[a.index("--session") + 1] if "--session" in a else ""
    a = [x for i, x in enumerate(a) if x != "--session" and (i == 0 or a[i - 1] != "--session")]
    signed = mode == "open" and (s.get("op_app") or (token and token == s.get("op_session")))
    if a[:2] == ["account", "list"]:
        print(json.dumps([] if mode == "out" else [{"url": "my.1password.com", "email": "angel@example.com", "user_uuid": "U1", "account_uuid": "A1"}]))
        return 0
    if a[:1] == ["whoami"]:
        if not signed:
            die("[ERROR] 2026/10/11 10:00:00 account is not signed in")
        print(json.dumps({"url": "my.1password.com", "email": "angel@example.com", "user_uuid": "U1", "account_uuid": "A1"}))
        return 0
    if a[:1] == ["signin"]:
        if mode == "out":
            die("[ERROR] 2026/10/11 10:00:00 No accounts configured for use with 1Password CLI.")
        if s.get("op_app"):
            s["op"] = "open"
            save(s)
            return 0
        typed = "" if sys.stdin.isatty() else sys.stdin.readline().rstrip("\n")
        if typed != MASTER:
            die("[ERROR] 2026/10/11 10:00:00 Authentication: DB: 401: Unauthorized")
        s["op"], s["op_session"] = "open", "op-token-1"
        save(s)
        print("op-token-1")
        return 0
    if a[:1] == ["signout"]:
        if mode != "out":
            s["op"], s["op_session"] = "locked", ""
            save(s)
        return 0
    if not signed:
        die("[ERROR] 2026/10/11 10:00:00 account is not signed in")
    if a[:2] == ["item", "list"]:
        print(json.dumps([{"id": l["id"], "title": l["name"], "category": "LOGIN", "additional_information": l["user"] or "—",
                           "urls": [{"primary": True, "href": l["url"]}] if l["url"] else [],
                           "vault": {"id": "v1", "name": "Personal"}} for l in LOGINS]))
        return 0
    if a[:2] == ["item", "get"]:
        l = by_id(a[2])
        if "--otp" in a:
            if not l["totp"]:
                die("[ERROR] 2026/10/11 10:00:00 item has no one-time password")
            print(l["totp"])
            return 0
        field = a[a.index("--fields") + 1].split("=", 1)[-1]
        if "--reveal" not in a and field == "password":
            print("[use 'op item get %s --reveal' to reveal]" % l["id"])
            return 0
        print({"password": l["password"], "username": l["user"]}.get(field, ""))
        return 0
    die("fake op: " + " ".join(a), 2)


def wl_copy(a):
    if "--help" in a:
        print("Usage: wl-copy\n\t    --sensitive\t\tHint that the content is sensitive.")
        return 0
    if "--clear" in a or "-c" in a:
        (DIR / "clipboard").unlink(missing_ok=True)
        (DIR / "clipboard.args").write_text("--clear")
        return 0
    (DIR / "clipboard").write_bytes(sys.stdin.buffer.read())
    (DIR / "clipboard.args").write_text(" ".join(a))
    return 0


def secret_tool(a):
    """the login keyring as a folder: one file per set of attributes"""
    what = a[0]
    attrs = [x for i, x in enumerate(a[1:]) if x != "--label" and a[i] != "--label"]
    f = DIR / ("keyring-" + "-".join(attrs))
    if what == "store":
        f.write_bytes(sys.stdin.buffer.read())
        return 0
    if what == "lookup":
        if not f.exists():
            return 1
        sys.stdout.buffer.write(f.read_bytes())
        return 0
    if what == "clear":
        f.unlink(missing_ok=True)
        return 0
    return 2


def wl_paste(a):
    try:
        sys.stdout.buffer.write((DIR / "clipboard").read_bytes())
    except OSError:
        die("Nothing is copied")
    return 0


if __name__ == "__main__":
    tool, args = sys.argv[1], sys.argv[2:]
    if tool != "secret-tool":
        log(tool, [x for x in args if not x.startswith("session-") and x != "op-token-1"])
    else:
        log(tool, args)
    sys.exit({"bw": bw, "rbw": rbw, "op": op, "wl-copy": wl_copy, "wl-paste": wl_paste, "secret-tool": secret_tool}[tool](args) or 0)
