#!/usr/bin/env python3
"""The root half of the setup wizard's app install: one admin password (pkexec, the shell's own
polkit dialog) for the whole run instead of a terminal asking sudo's.

  pkexec apps-root.py UID SOCKET

Listens on SOCKET (in a directory UID owns, mode 0700) for that user's requests — scripts/apps-sudo
sends them: pacman's own commands (paru's too, through --sudo), the author's repositories
(scripts/cachyos-repos.sh) and that user's login shell made fish (chsh -s /usr/bin/fish USER; the
new apps after an update offer it). Nothing else runs. Each request is one JSON line {"argv": [...]};
the answer is the command's output, then a line "\\0RC <exit code>". Prints READY once listening,
and ends when its stdin closes (scripts/apps-install.py, which started it, is done or gone).
"""
import json
import os
import pwd
import selectors
import socket
import stat
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPOS = HERE / "cachyos-repos.sh"
# the tests stand a fake pacman in and run it unprivileged (pkexec clears the environment, so a
# real run never sees these)
PACMAN = os.environ.get("APPS_ROOT_PACMAN", "/usr/bin/pacman")
TEST = os.environ.get("APPS_ROOT_TEST") == "1"


FISH = "/usr/bin/fish"
SHELLS = Path(os.environ.get("APPS_ROOT_SHELLS", "/etc/shells") if TEST else "/etc/shells")
CHSH = os.environ.get("APPS_ROOT_CHSH", "/usr/bin/chsh") if TEST else "/usr/bin/chsh"


def list_fish():
    """chsh refuses a shell /etc/shells doesn't name (fish's package adds itself; a fish built
    by hand doesn't)"""
    try:
        text = SHELLS.read_text()
    except OSError:
        text = ""
    if FISH not in text.split():
        with open(SHELLS, "a") as f:
            f.write(("" if not text or text.endswith("\n") else "\n") + FISH + "\n")


def allowed(argv, uid=None):
    """the command to run for a request, None when it isn't one of ours"""
    # paru's sudo flags before the command; `sudo -v` / `sudo true` only keep a ticket alive
    while argv and argv[0].startswith("-") and argv[0] not in ("--",):
        argv = argv[1:]
    if argv[:1] == ["--"]:
        argv = argv[1:]
    if not argv or argv == ["true"]:
        return []
    if os.path.basename(argv[0]) == "pacman" and all("\n" not in a for a in argv):
        return [PACMAN] + argv[1:]
    if argv[0] in ("bash", "/bin/bash", "/usr/bin/bash") and len(argv) == 2 and Path(argv[1]).resolve() == REPOS:
        return ["/usr/bin/bash", str(REPOS)]
    # the asking user's own login shell, fish and nothing else
    if os.path.basename(argv[0]) == "chsh" and uid is not None and len(argv) == 4 and argv[1:3] == ["-s", FISH]:
        try:
            name = pwd.getpwuid(uid).pw_name
        except KeyError:
            return None
        if argv[3] == name and (TEST or os.path.exists(FISH)):
            return [CHSH, "-s", FISH, name]
    return None


def serve(conn, uid):
    # the peer must be the user who asked for this (SO_PEERCRED: pid, uid, gid)
    import struct
    _, peer_uid, _ = struct.unpack("3i", conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i")))
    if peer_uid != uid:
        return
    f = conn.makefile("rb")
    try:
        req = json.loads(f.readline() or b"{}")
    except ValueError:
        req = {}
    cmd = allowed([str(a) for a in req.get("argv", [])], uid)
    if cmd is None:
        conn.sendall(f"angelOS: not allowed: {' '.join(map(str, req.get('argv', [])))}\n\n\0RC 126\n".encode())
        return
    if not cmd:
        conn.sendall(b"\0RC 0\n")
        return
    if cmd[0] == CHSH:
        list_fish()
    env = {"PATH": "/usr/local/sbin:/usr/local/bin:/usr/bin", "LANG": req.get("lang") or "C.UTF-8", "TERM": "dumb"}
    if TEST:
        env = dict(os.environ, **env)
    p = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         cwd=req.get("cwd") if os.path.isdir(req.get("cwd") or "") else "/", env=env)
    for chunk in iter(lambda: p.stdout.read1(65536), b""):
        try:
            conn.sendall(chunk)
        except OSError:
            p.terminate()
            break
    rc = p.wait()
    try:
        conn.sendall(f"\n\0RC {rc}\n".encode())
    except OSError:
        pass


def main():
    if len(sys.argv) != 3 or (os.geteuid() != 0 and not TEST):
        sys.exit("usage: pkexec apps-root.py UID SOCKET")
    uid, path = int(sys.argv[1]), Path(sys.argv[2])
    # only a private directory of that user (no one else could have put a link there)
    st = os.lstat(path.parent)
    if not stat.S_ISDIR(st.st_mode) or st.st_uid != uid or stat.S_IMODE(st.st_mode) != 0o700:
        sys.exit("apps-root: the socket's directory must be the user's own, mode 0700")
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(str(path))
    if not TEST:
        os.chown(path, uid, -1)
    os.chmod(path, 0o600)
    srv.listen(4)
    print("READY", flush=True)
    sel = selectors.DefaultSelector()
    sel.register(srv, selectors.EVENT_READ, "srv")
    sel.register(sys.stdin, selectors.EVENT_READ, "ctl")
    try:
        while True:
            for key, _ in sel.select():
                if key.data == "ctl":
                    if not sys.stdin.readline():
                        return
                else:
                    conn, _ = srv.accept()
                    with conn:
                        serve(conn, uid)
    finally:
        srv.close()
        path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
