#!/usr/bin/env python3
"""Generic host for bundled password managers."""

import json
import os
import subprocess
import sys
from pathlib import Path


def plugins():
    try:
        value = json.loads(os.environ.get("ANGELOS_VAULT_PLUGINS", "[]"))
    except (TypeError, ValueError):
        return []
    return [p for p in value if p.get("id") and p.get("dir") and p.get("entry")]


def by_id():
    return {p["id"]: p for p in plugins()}


def command(plugin, args):
    env = os.environ.copy()
    env["ANGELOS_VAULT_CORE"] = str(Path(__file__).resolve().parent)
    env["ANGELOS_VAULT_BACKEND_ID"] = plugin["id"]
    vault = plugin.get("vault") or {}
    env["ANGELOS_VAULT_PACKAGE_MANAGER"] = vault.get("packageManager", "")
    env["ANGELOS_VAULT_PACKAGE"] = vault.get("package", "")
    env["ANGELOS_VAULT_DOCS"] = vault.get("docs", "")
    try:
        sessions = json.loads(env.get("ANGELOS_VAULT_SESSIONS", "{}"))
    except (TypeError, ValueError):
        sessions = {}
    env["ANGELOS_VAULT_SESSION"] = sessions.get(plugin["id"], "")
    return [sys.executable, str(Path(plugin["dir"]) / plugin["entry"]), *args], env


def json_call(plugin, args):
    argv, env = command(plugin, args)
    result = subprocess.run(argv, env=env, stdin=sys.stdin, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True)
    lines = [line for line in result.stdout.splitlines() if line.strip()]
    try:
        value = json.loads(lines[-1]) if lines else {"ok": False, "error": result.stderr.strip()}
    except ValueError:
        value = {"ok": False, "error": lines[-1] if lines else result.stderr.strip()}
    return result.returncode, value


def status():
    rows = []
    for plugin in plugins():
        _, value = json_call(plugin, ["status"])
        rows.extend(value.get("backends", []))
    print(json.dumps({"backends": rows}, ensure_ascii=False))
    return 0


def list_items(ids):
    available = by_id()
    rows, errors = [], {}
    targets = [available[i] for i in ids if i in available] if ids else list(available.values())
    for plugin in targets:
        code, value = json_call(plugin, ["list"])
        rows.extend(value.get("items", []))
        errors.update(value.get("errors", {}))
        if code and plugin["id"] not in errors:
            errors[plugin["id"]] = value.get("error", "list failed")
    rows.sort(key=lambda row: (row.get("name", "").lower(), row.get("user", "").lower()))
    print(json.dumps({"items": rows, "errors": errors}, ensure_ascii=False))
    return 1 if errors and not rows else 0


def forward(command_name, args):
    if not args or args[0] not in by_id():
        print(json.dumps({"ok": False, "error": "unknown or disabled manager"}, ensure_ascii=False))
        return 2
    plugin = by_id()[args[0]]
    code, value = json_call(plugin, [command_name, *args[1:]])
    print(json.dumps(value, ensure_ascii=False))
    return code


def aggregate(command_name, ids):
    available = by_id()
    targets = [available[i] for i in ids if i in available] if ids else list(available.values())
    errors = {}
    ok = True
    for plugin in targets:
        code, value = json_call(plugin, [command_name])
        ok = ok and code == 0 and value.get("ok", code == 0)
        errors.update(value.get("errors", {}))
        if not value.get("ok", code == 0):
            errors[plugin["id"]] = value.get("error", "operation failed")
    print(json.dumps({"ok": ok, "errors": errors}, ensure_ascii=False))
    return 0 if ok else 1


def interactive(command_name, args):
    if not args or args[0] not in by_id():
        print("vault.py %s ID" % command_name)
        return 2
    argv, env = command(by_id()[args[0]], [command_name])
    return subprocess.call(argv, env=env)


def main(argv):
    command_name, args = (argv[0], argv[1:]) if argv else ("status", [])
    if command_name == "status":
        return status()
    if command_name == "list":
        return list_items(args)
    if command_name in ("unlock", "remember", "forget", "copy"):
        return forward(command_name, args)
    if command_name in ("lock", "sync"):
        return aggregate(command_name, args)
    if command_name in ("install", "login"):
        return interactive(command_name, args)
    print(json.dumps({"ok": False, "error": "unknown command"}, ensure_ascii=False))
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
