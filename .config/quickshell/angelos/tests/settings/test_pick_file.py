#!/usr/bin/env python3
"""scripts/pick-file.py — the avatar's file chooser (Settings → Account). Offline, on a private
session bus (it re-runs itself under dbus-run-session), with a stand-in portal (fake_portal.py)
and stand-in zenity; the session's own portal is never asked.

  python3 tests/settings/test_pick_file.py    exit 0 = all good, 77 = skipped (no gi / dbus-run-session)

  portal       the portal's file chooser: title and filters passed, the file:// URI as a path
  cancel       cancelled in the portal: exit 1, nothing printed, zenity not tried
  failed       the portal couldn't show it (response 2): zenity is asked instead
  zenity       no portal on the bus: zenity
  none         no portal, no zenity, no kdialog: exit 2 and why — the avatar button used to do
               nothing at all when zenity (never installed by angelOS) was missing
  remember     the next chooser opens in the folder of the last pick (per --remember key), not ~
  start        --start DIR wins over the remembered folder; zenity gets it as --filename=DIR/
  multi        --multi: the portal is asked for several, every path printed on its own line
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE.parents[1] / "scripts/pick-file.py"
FAKE = HERE / "fake_portal.py"

try:
    from gi.repository import Gio  # noqa: F401
except ImportError:
    print("SKIP: python-gobject (gi) is not installed")
    sys.exit(77)

# a bus that starts nothing by itself: the stock session config would activate the machine's own
# xdg-desktop-portal, which opens a real dialog; and no display, a throw-away home
BUS = """<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig><type>session</type><listen>unix:tmpdir=%s</listen><auth>EXTERNAL</auth>
<policy context="default"><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy>
</busconfig>"""

if not os.environ.get("PICK_TEST_BUS"):
    if not shutil.which("dbus-run-session"):
        print("SKIP: dbus-run-session is missing")
        sys.exit(77)
    home = tempfile.mkdtemp()
    conf = Path(home) / "bus.conf"
    conf.write_text(BUS % home)
    env = {k: v for k, v in os.environ.items() if k not in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS")}
    env.update(PICK_TEST_BUS="1", HOME=home, XDG_CONFIG_HOME=home + "/.config", XDG_CACHE_HOME=home + "/.cache",
               XDG_DATA_HOME=home + "/.local/share", XDG_RUNTIME_DIR=home)
    rc = subprocess.run(["dbus-run-session", "--config-file=" + str(conf), "--", sys.executable, __file__], env=env).returncode
    shutil.rmtree(home, ignore_errors=True)
    sys.exit(rc)

failures = []
tmp = Path(tempfile.mkdtemp())
# a PATH with python3 and sh, and zenity only where a case puts it
bare = tmp / "bin"
bare.mkdir()
for tool in ("python3", "sh"):
    (bare / tool).symlink_to(shutil.which(tool))
withz = tmp / "zbin"
withz.mkdir()
(withz / "zenity").write_text("#!/bin/sh\necho \"$*\" > \"%s/zenity-args\"\necho /from/zenity.png\n" % tmp)
(withz / "zenity").chmod(0o755)


def check(name, ok, detail=""):
    print("  %s %s %s" % ("✓" if ok else "✕", name, "" if ok else detail))
    if not ok:
        failures.append(name)


def pick(zenity=False, opts=()):
    path = f"{withz}:{bare}" if zenity else str(bare)
    (tmp / "zenity-args").unlink(missing_ok=True)
    r = subprocess.run([sys.executable, str(SCRIPT), *opts, "angelOS — аватарка", "Картинки", "*.png", "*.jpg"],
                       env=dict(os.environ, PATH=path), capture_output=True, text=True, timeout=20)
    return r.returncode, r.stdout.strip(), r.stderr


def portal(code, *uris):
    p = subprocess.Popen([sys.executable, str(FAKE), str(code), *uris], stdout=subprocess.PIPE, text=True)
    assert p.stdout.readline().strip() == "ready"
    return p


p = portal(0, "file:///home/me/My%20Pictures/angel.png")
rc, out, err = pick()
call = json.loads(p.stdout.readline())
p.terminate()
check("portal", rc == 0 and out == "/home/me/My Pictures/angel.png", f"rc={rc} out={out!r} {err}")
check("portal: title and filters", call["title"] == "angelOS — аватарка" and call["filters"] == [["Картинки", [[0, "*.png"], [0, "*.jpg"]]]], str(call))

p = portal(1)
rc, out, err = pick(zenity=True)
p.terminate()
check("cancel", rc == 1 and out == "" and not (tmp / "zenity-args").exists(), f"rc={rc} out={out!r} {err}")

p = portal(2)
rc, out, err = pick(zenity=True)
p.terminate()
check("failed", rc == 0 and out == "/from/zenity.png", f"rc={rc} out={out!r} {err}")

rc, out, err = pick(zenity=True)
args = (tmp / "zenity-args").read_text() if (tmp / "zenity-args").exists() else ""
check("zenity", rc == 0 and out == "/from/zenity.png" and "--file-filter=Картинки | *.png *.jpg" in args, f"rc={rc} out={out!r} args={args!r} {err}")

# remember: two folders that exist, one key each
pics, art = tmp / "My Pictures", tmp / "art"
pics.mkdir()
art.mkdir()
p = portal(0, (pics / "a.png").as_uri())
pick(opts=("--remember", "walls"))
first = json.loads(p.stdout.readline())
p.terminate()
p = portal(0, (art / "b.png").as_uri())
pick(opts=("--remember", "walls"))
second = json.loads(p.stdout.readline())
p.terminate()
check("remember", first["current_folder"] in (None, "") or first["current_folder"] != str(pics), str(first))
check("remember: opens where the last pick was", second["current_folder"] == str(pics), str(second))
p = portal(0, (pics / "c.png").as_uri())
pick(opts=("--remember", "other"))
other = json.loads(p.stdout.readline())
p.terminate()
check("remember: per key", other["current_folder"] != str(art), str(other))

p = portal(0, (pics / "d.png").as_uri())
pick(opts=("--remember", "walls", "--start", str(art)))
started = json.loads(p.stdout.readline())
p.terminate()
check("start", started["current_folder"] == str(art), str(started))
rc, out, err = pick(zenity=True, opts=("--start", str(art)))
args = (tmp / "zenity-args").read_text() if (tmp / "zenity-args").exists() else ""
check("start: zenity", f"--filename={art}/" in args, args)

p = portal(0, (pics / "e.png").as_uri(), (pics / "f g.png").as_uri())
rc, out, err = pick(opts=("--multi",))
call = json.loads(p.stdout.readline())
p.terminate()
check("multi", rc == 0 and out.split("\n") == [str(pics / "e.png"), str(pics / "f g.png")] and call["multiple"], f"rc={rc} out={out!r} {call}")

rc, out, err = pick()
check("none", rc == 2 and out == "" and "no file chooser" in err, f"rc={rc} out={out!r} {err}")

shutil.rmtree(tmp, ignore_errors=True)
print("FAILED: " + ", ".join(failures) if failures else "OK")
sys.exit(1 if failures else 0)
