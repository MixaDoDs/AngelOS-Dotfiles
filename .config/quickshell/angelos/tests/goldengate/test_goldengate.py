#!/usr/bin/env python3
"""The Golden Gate skin outside the shell — offline, in a throw-away HOME, with stand-ins for
gsettings and fc-list on PATH (nothing of the real session is touched):

  python3 tests/goldengate/test_goldengate.py      exit 0 = all good

  system-on     goldengate.py on: GTK's font Inter, Adwaita icons, appmenu-gtk-module added to
                GTK 3's gtk-modules (next to the ones there), what was set before kept once
  system-off    off: every setting back as it was, our module out, the others stay, the record gone
  no-module     appmenu-gtk-module not installed: gtk-modules untouched
  qt-mac        qt-theme.py with the skin: the Golden Gate stylesheet, Inter and JetBrains Mono,
                Adwaita icons in qt6ct.conf; without it (and no pixel style): qt6ct.conf as before
  variants      render-templates.py: the gtk3/gtk4/niri entries render their Golden Gate files
                with skin goldengate, the usual ones without
  niri-valid    the rendered niri-mac.kdl — floating rules and Mac shortcuts in it — passes
                `niri validate` (when niri is installed)
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
failures = []


def check(name, ok, detail=""):
    print("  %s %s %s" % ("✓" if ok else "✕", name, "" if ok else detail))
    if not ok:
        failures.append(name)


tmp = Path(tempfile.mkdtemp(prefix="aos-gg."))
home = tmp / "home"
bin_ = tmp / "bin"
(home / ".config/gtk-3.0").mkdir(parents=True)
(home / ".config/gtk-4.0").mkdir(parents=True)
(home / ".config/qt6ct").mkdir(parents=True)
bin_.mkdir()
store = tmp / "gsettings.json"
store.write_text(json.dumps({"font-name": "Cozette 12", "icon-theme": "pixora-dark"}))
(bin_ / "gsettings").write_text("""#!/usr/bin/env python3
import json, sys
p = %r
d = json.load(open(p))
if sys.argv[1] == "get":
    v = d.get(sys.argv[3])
    print("'%%s'" %% v if v is not None else "''")
elif sys.argv[1] == "set":
    d[sys.argv[3]] = sys.argv[4]
    json.dump(d, open(p, "w"))
""" % str(store))
(bin_ / "fc-list").write_text("#!/bin/sh\nprintf 'Inter\\nJetBrains Mono\\nCozette\\n'\n")
for f in bin_.iterdir():
    f.chmod(0o755)
module = tmp / "libappmenu-gtk-module.so"
module.write_text("")
ini3 = home / ".config/gtk-3.0/settings.ini"
ini3.write_text("[Settings]\ngtk-font-name=Cozette 12\ngtk-modules=colorreload-gtk-module\n")
ini4 = home / ".config/gtk-4.0/settings.ini"
ini4.write_text("[Settings]\ngtk-font-name=Cozette 12\n")
env = dict(os.environ, HOME=str(home), PATH="%s:%s" % (bin_, os.environ["PATH"]), ANGELOS_APPMENU_MODULE=str(module),
           XDG_CONFIG_HOME=str(home / ".config"))
on = tmp / "on.json"
on.write_text(json.dumps({"skin": "goldengate", "mode": "light"}))
off = tmp / "off.json"
off.write_text(json.dumps({"skin": "", "mode": "light"}))
GG = ROOT / "scripts/goldengate.py"


def run(*args, **kw):
    return subprocess.run([sys.executable] + [str(a) for a in args], env=kw.get("env", env), capture_output=True, text=True, timeout=60)


before3, before4 = ini3.read_text(), ini4.read_text()
r = run(GG, on)
gs = json.loads(store.read_text())
t3 = ini3.read_text()
check("system-on", gs.get("font-name") == "Inter 10" and gs.get("monospace-font-name") == "JetBrains Mono 10"
      and "gtk-font-name=Inter 10" in t3 and "gtk-modules=colorreload-gtk-module:appmenu-gtk-module" in t3
      and (home / ".local/state/angelos/goldengate-before.json").exists(), r.stdout + r.stderr + t3 + json.dumps(gs))
run(GG, on)        # again: nothing doubles, the record stays the first one
check("system-on twice", ini3.read_text().count("appmenu-gtk-module") == 1, ini3.read_text())
r = run(GG, off)
gs = json.loads(store.read_text())
check("system-off", ini3.read_text().replace(" ", "") == before3.replace(" ", "") and ini4.read_text().replace(" ", "") == before4.replace(" ", "")
      and gs.get("font-name") == "Cozette 12" and gs.get("icon-theme") == "pixora-dark"
      and not (home / ".local/state/angelos/goldengate-before.json").exists(), r.stdout + r.stderr + ini3.read_text() + json.dumps(gs))
env2 = dict(env, ANGELOS_APPMENU_MODULE=str(tmp / "none.so"))
run(GG, on, env=env2)
check("no-module", "appmenu-gtk-module" not in ini3.read_text(), ini3.read_text())
run(GG, off, env=env2)

# ---- Qt ----
conf = home / ".config/qt6ct/qt6ct.conf"
conf.write_text("[Appearance]\nicon_theme=pixora-dark\nstyle=Fusion\n\n[Fonts]\ngeneral=\"Cozette,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\"\n")
conf_before = conf.read_text()
pal = {"skin": "goldengate", "mode": "light", "fg": "#1d1d1f", "bg": "#f5f5f7", "bgAlt": "#ececee", "accent": "#0088ff",
       "textDim": "#86868b", "sunken": "#ffffff", "faceAlt": "#ececee"}
qpal = tmp / "qt.json"
qpal.write_text(json.dumps(pal))
r = run(ROOT / "scripts/qt-theme.py", qpal)
qss = (home / ".config/qt6ct/qss/angelos.qss")
c = conf.read_text()
ok = qss.exists() and "Golden Gate" in qss.read_text() and "Inter,10" in c and "JetBrains Mono,10" in c
check("qt-mac", ok, r.stdout + r.stderr + c)
qpal.write_text(json.dumps(dict(pal, skin="")))
r = run(ROOT / "scripts/qt-theme.py", qpal)
c = conf.read_text()
check("qt-mac off", "Cozette" in c and "Inter," not in c and "icon_theme=pixora-dark" in c, r.stdout + r.stderr + c)

# ---- template variants ----
tpl = tmp / "palette.json"
base = json.loads((ROOT / "templates/palette-default.json").read_text())
macp = dict(base, skin="goldengate", macAccent="#0088ff", macWindow="#f5f5f5", macContent="#ffffff", macSidebar="#e8e8ea",
            macPopover="#f6f6f6", macText="#1d1d1f", macLine="rgba(0,0,0,0.12)", macLineHex="#0000001f",
            macControl="rgba(0,0,0,0.05)", macControlHover="rgba(0,0,0,0.09)", macSelectedSidebar="rgba(0,0,0,0.08)",
            macLightOff="#d1d1d6", macOverview="#2c2c30",
            macBinds='binds {\n    Mod+Q { spawn-sh "qs -c angelos ipc call angelos macQuit"; }\n    Ctrl+Up { toggle-overview; }\n    Mod+Shift+3 { screenshot-screen; }\n}\n',
            macWindowRules='window-rule {\n    open-floating true\n}\nwindow-rule {\n    match is-floating=true\n    exclude app-id=r#"^firefox$"#\n    geometry-corner-radius 0 0 16 16\n}\n')
tpl.write_text(json.dumps(macp))
# only the plain templates (the command entries would run the real hooks)
disabled = ",".join(e["id"] for e in json.loads((ROOT / "templates/templates.json").read_text()) if not e.get("template") or e["id"] in ("kitty",))
r = run(ROOT / "scripts/render-templates.py", tpl, disabled)
g3 = (home / ".config/gtk-3.0/angelos.css").read_text() if (home / ".config/gtk-3.0/angelos.css").exists() else ""
g4 = (home / ".config/gtk-4.0/angelos.css").read_text() if (home / ".config/gtk-4.0/angelos.css").exists() else ""
nk = home / ".config/niri/angelos.kdl"
nt = nk.read_text() if nk.exists() else ""
check("variants", "Golden Gate" in g3 and "Golden Gate" in g4 and "niri-mac.kdl" in nt and "{{" not in g3 + g4 + nt, r.stdout + r.stderr + nt[:300])
if shutil.which("niri") and nt:
    v = subprocess.run(["niri", "validate", "-c", str(nk)], capture_output=True, text=True, timeout=30)
    check("niri-valid", v.returncode == 0, (v.stdout + v.stderr)[-600:])
else:
    print("  - niri-valid skipped (no niri)")
tpl.write_text(json.dumps(dict(base, skin="")))
run(ROOT / "scripts/render-templates.py", tpl, disabled)
check("variants off", "Golden Gate" not in (home / ".config/gtk-3.0/angelos.css").read_text() and "niri-mac" not in nk.read_text())

shutil.rmtree(tmp, ignore_errors=True)
if failures:
    print("» Golden Gate system tests FAILED: " + ", ".join(failures))
    sys.exit(1)
print("» Golden Gate system tests passed")
