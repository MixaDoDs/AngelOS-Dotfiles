#!/usr/bin/env python3
"""scripts/discord-theme.py in a throw-away $HOME: the theme into every Vencord found (and only
into them, never over someone else's file), apply and revert touching only enabledThemes and
themeLinks, apply refusing a running client, the launcher override set and taken back only when
it is angelOS's — and the DevTools injector against a headless Chromium (Helium) of its own,
on a local page with a strict CSP, through a reload and a theme change.

Nothing here touches the real Discord or the real Helium: the "running" clients are stand-in
processes and a stand-in `flatpak`, the browser runs on its own profile in a temp folder and
only that process (its own session) is stopped.
"""
import http.server
import importlib.util
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/discord-theme.py"
PALETTE = {
    "mode": "dark", "flavor": "wallpaper", "desk": "#141722", "face": "#161a29", "faceAlt": "#191d33",
    "sunken": "#141722", "text": "#fafafa", "textDim": "#b4b5b7", "titleText": "#fafafa",
    "hi": "#191d33", "lo": "#141722", "edge": "#141722", "accent": "#6871b3", "accent2": "#9ba1cc",
    "title1": "#6871b3", "title2": "#6871b3", "danger": "#ff4f6d", "ok": "#57e3a2",
    "select": "#6871b3", "selectText": "#141722", "shadow": "#000000", "color3": "#d8b56b",
    "realm": "heaven", "hell": {}, "fontTitle": "Pixeloid Sans", "fontBody": "CozetteVector",
    "fontMono": "Pixeloid Mono", "sizeBody": 13,
}
HELL = dict(PALETTE, realm="hell", hell={
    "circle": "limbo", "body": "#160609", "face": "#2a0b10", "faceAlt": "#3d1016", "sunken": "#0c0305",
    "hi": "#6e1a21", "lo": "#0c0305", "edge": "#050102", "rim": "#3d1016", "text": "#f3d9c0",
    "textDim": "#a8857a", "accent": "#b3142b", "blood": "#b3142b", "flame": "#ffb02e",
    "ember": "#ff6a1a", "gold": "#d9a441", "ok": "#5f7a3c",
})

STANDIN = "#!/usr/bin/python3\nimport time\nwhile True:\n    time.sleep(0.2)\n"
FLATPAK = '#!/bin/sh\n[ "$1" = ps ] && cat "$HOME/flatpak-ps" 2>/dev/null\nexit 0\n'

DESKTOP = """[Desktop Entry]
Name=Discord
Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=com.discordapp.Discord --file-forwarding com.discordapp.Discord @@u %U @@
Icon=com.discordapp.Discord
Type=Application
DBusActivatable=false
"""


def helium():
    for b in ("helium", "/opt/helium-browser-bin/helium", "chromium", "google-chrome-stable"):
        p = shutil.which(b) if "/" not in b else (b if os.access(b, os.X_OK) else None)
        if p:
            return p
    return None


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        (self.bin / "flatpak").write_text(FLATPAK)
        (self.bin / "flatpak").chmod(0o755)
        self.share = self.home / "sys/share"
        self.env = dict(os.environ, HOME=str(self.home), ANGELOS_TEST="1",
                        PATH="%s:%s" % (self.bin, os.environ.get("PATH", "")),
                        XDG_DATA_HOME=str(self.home / ".local/share"),
                        XDG_DATA_DIRS=str(self.share), XDG_RUNTIME_DIR=str(self.home / "run"))
        (self.home / "run").mkdir()
        self.env.pop("ANGELOS_DISCORD_CMD", None)
        self.procs = []
        self.pal = self.home / "palette.json"
        self.pal.write_text(json.dumps(PALETTE))

    def tearDown(self):
        for p in self.procs:
            if p.poll() is None:
                try:
                    os.killpg(p.pid, signal.SIGKILL)
                except OSError:
                    p.kill()
                p.wait()
        self.tmp.cleanup()

    def run_script(self, *args, env=None):
        r = subprocess.run([sys.executable, str(SCRIPT)] + list(args), env=env or self.env,
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(r.returncode, 0, r.stderr)
        return json.loads(r.stdout) if r.stdout.strip() else None

    def client(self, rel, settings=None):
        d = self.home / rel
        (d / "settings").mkdir(parents=True)
        if settings is not None:
            (d / "settings/settings.json").write_text(json.dumps(settings, indent=4))
        return d


class Build(Base):
    def test_build_puts_the_theme_in_every_vencord_found(self):
        vesk = self.client(".config/vesktop")
        flat = self.client(".var/app/com.discordapp.Discord/config/Vencord")
        out = self.run_script("build", str(self.pal))
        self.assertTrue(out["ok"])
        base = self.home / ".local/share/angelos/discord/angelOS.theme.css"
        text = base.read_text()
        self.assertIn("@name angelOS", text)
        self.assertIn("written by angelOS", text)
        self.assertIn("--ao-accent: #6871b3;", text)
        self.assertIn("border-radius: var(--ao-r) !important", text)
        self.assertIn("--ao-size: 13px;", text)
        for d in (vesk, flat):
            self.assertEqual((d / "themes/angelOS.theme.css").read_text(), text)
        # no Vencord folder made for a client that isn't there
        self.assertFalse((self.home / ".config/equibop").exists())
        self.assertFalse((self.home / ".config/Vencord").exists())
        self.assertEqual(sorted(out["clients"]), ["vencord-flatpak", "vesktop"])

    def test_zero_contrast_frame_is_made_visible(self):
        # the wallpaper palette: hi == faceAlt, edge == lo == desk
        self.run_script("build", str(self.pal))
        text = (self.home / ".local/share/angelos/discord/angelOS.theme.css").read_text()
        vals = dict(l.strip().rstrip(";").split(": ", 1) for l in text.splitlines()
                    if l.strip().startswith(("--ao-hi:", "--ao-lo:", "--ao-edge:", "--ao-face:")))
        self.assertNotEqual(vals["--ao-hi"], PALETTE["faceAlt"])
        self.assertNotEqual(vals["--ao-edge"], PALETTE["desk"])
        self.assertNotEqual(vals["--ao-lo"], vals["--ao-face"])

    def test_same_palette_writes_nothing(self):
        vesk = self.client(".config/vesktop")
        self.run_script("build", str(self.pal))
        f = vesk / "themes/angelOS.theme.css"
        m = f.stat().st_mtime_ns
        time.sleep(0.05)
        out = self.run_script("build", str(self.pal))
        self.assertFalse(out["changed"])
        self.assertEqual(out["clients"]["vesktop"], "same")
        self.assertEqual(f.stat().st_mtime_ns, m)

    def test_someone_elses_file_is_left_alone(self):
        vesk = self.client(".config/vesktop")
        (vesk / "themes").mkdir()
        mine = "/** @name angelOS — my own */\nbody { color: red; }\n"
        (vesk / "themes/angelOS.theme.css").write_text(mine)
        out = self.run_script("build", str(self.pal))
        self.assertIn("skipped", out["clients"]["vesktop"])
        self.assertEqual((vesk / "themes/angelOS.theme.css").read_text(), mine)

    def test_hell_and_light(self):
        self.client(".config/vesktop")
        self.pal.write_text(json.dumps(HELL))
        self.run_script("build", str(self.pal))
        text = (self.home / ".local/share/angelos/discord/angelOS.theme.css").read_text()
        self.assertIn("for hell (limbo)", text)
        self.assertIn('"Jacquard 12 Hell"', text)
        self.assertIn("@font-face", text)
        self.assertIn("--ao-accent: #b3142b;", text)
        light = dict(PALETTE, mode="light", desk="#f6e9f0", face="#fff4fa", faceAlt="#f3e1ec",
                     sunken="#fbeef5", text="#2a1a22", textDim="#7a6470")
        self.pal.write_text(json.dumps(light))
        self.run_script("build", str(self.pal))
        text = (self.home / ".local/share/angelos/discord/angelOS.theme.css").read_text()
        self.assertIn("--ao-scheme: light;", text)
        self.assertNotIn("@font-face", text)


class Apply(Base):
    SETTINGS = {"autoUpdate": True, "useQuickCss": True, "enabledThemes": ["midnight.theme.css"],
                "themeLinks": ["https://example.org/a.theme.css"], "plugins": {"X": {"enabled": True}}}

    def test_apply_and_revert_change_only_the_two_keys(self):
        d = self.client(".config/vesktop", self.SETTINGS)
        out = self.run_script("apply", "vesktop")
        self.assertEqual(out["done"], ["vesktop"])
        cfg = json.loads((d / "settings/settings.json").read_text())
        self.assertEqual(cfg["enabledThemes"], ["angelOS.theme.css"])
        self.assertEqual(cfg["themeLinks"], [])
        for k in ("autoUpdate", "useQuickCss", "plugins"):
            self.assertEqual(cfg[k], self.SETTINGS[k])
        self.assertEqual(json.loads((d / "settings/settings.json.angelos-before").read_text()), self.SETTINGS)
        before = json.loads((self.home / ".local/share/angelos/discord/before.json").read_text())
        self.assertEqual(before["vesktop"], {"enabledThemes": ["midnight.theme.css"],
                                             "themeLinks": ["https://example.org/a.theme.css"]})
        # applied twice: what was before stays the first one
        self.assertEqual(self.run_script("apply", "vesktop")["already"], ["vesktop"])
        out = self.run_script("revert", "vesktop")
        self.assertEqual(out["done"], ["vesktop"])
        self.assertEqual(json.loads((d / "settings/settings.json").read_text()), self.SETTINGS)

    def test_apply_refuses_a_running_client(self):
        d = self.client(".config/vesktop", self.SETTINGS)
        (self.bin / "vesktop").write_text(STANDIN)
        (self.bin / "vesktop").chmod(0o755)
        p = subprocess.Popen([str(self.bin / "vesktop")], start_new_session=True)
        self.procs.append(p)
        time.sleep(0.3)
        out = self.run_script("apply", "vesktop")
        self.assertEqual(out["running"], ["vesktop"])
        self.assertFalse(out["ok"])
        self.assertEqual(json.loads((d / "settings/settings.json").read_text()), self.SETTINGS)
        self.assertIsNone(p.poll(), "the client was not touched")

    def test_apply_refuses_a_running_flatpak(self):
        d = self.client(".var/app/com.discordapp.Discord/config/Vencord", self.SETTINGS)
        (self.home / "flatpak-ps").write_text("com.discordapp.Discord\n")
        out = self.run_script("apply")
        self.assertEqual(out["running"], ["vencord-flatpak"])
        self.assertEqual(json.loads((d / "settings/settings.json").read_text()), self.SETTINGS)
        (self.home / "flatpak-ps").write_text("org.telegram.desktop\n")
        self.assertEqual(self.run_script("apply")["done"], ["vencord-flatpak"])
        st = self.run_script("status")
        self.assertTrue(st["active"])

    def test_status(self):
        self.client(".config/vesktop", self.SETTINGS)
        self.run_script("build", str(self.pal))
        st = self.run_script("status")
        self.assertTrue(st["found"])
        self.assertEqual([c["id"] for c in st["clients"]], ["vesktop"])
        self.assertTrue(st["clients"][0]["installed"])
        self.assertFalse(st["clients"][0]["active"])
        self.assertFalse(st["launcher"])


class Launcher(Base):
    def setUp(self):
        super().setUp()
        (self.share / "applications").mkdir(parents=True)
        (self.share / "applications/com.discordapp.Discord.desktop").write_text(DESKTOP)
        self.dest = self.home / ".local/share/applications/com.discordapp.Discord.desktop"

    def test_on_and_off(self):
        out = self.run_script("launcher", "on")
        self.assertTrue(out["ok"])
        text = self.dest.read_text()
        self.assertIn("X-AngelOS=discord", text)
        self.assertIn("discord-theme.py launch %U", text)
        self.assertNotIn("DBusActivatable", text)
        self.assertNotIn("--remote-allow-origins", text)
        self.assertTrue(self.run_script("status")["launcher"])
        self.run_script("launcher", "off")
        self.assertFalse(self.dest.exists())

    def test_someone_elses_override_stays(self):
        self.dest.parent.mkdir(parents=True)
        mine = DESKTOP.replace("Name=Discord", "Name=My Discord")
        self.dest.write_text(mine)
        out = self.run_script("launcher", "on")
        self.assertFalse(out["ok"])
        self.run_script("launcher", "off")
        self.assertEqual(self.dest.read_text(), mine)


PAGE = b"""<!doctype html><html class="theme-dark"><head><title>angelos-test</title></head>
<body><div id="box" style="border-radius: 12px; width: 40px; height: 40px">x</div></body></html>"""


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        # as strict as Discord's could be: no inline styles, no data: fonts
        self.send_header("Content-Security-Policy", "default-src 'self'; style-src 'self'; script-src 'self'")
        self.end_headers()
        self.wfile.write(PAGE)

    def log_message(self, *a):
        pass


@unittest.skipUnless(helium(), "no Chromium here")
class Inject(Base):
    def setUp(self):
        super().setUp()
        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.url = "http://127.0.0.1:%d/angelos-test" % self.server.server_address[1]
        self.env["ANGELOS_DISCORD_URL_MATCH"] = "angelos-test"
        spec = importlib.util.spec_from_file_location("discord_theme", SCRIPT)
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)
        self.run_script("build", str(self.pal))
        self.theme = self.home / ".local/share/angelos/discord/angelOS.theme.css"

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        super().tearDown()

    def browser(self, port_arg=True):
        prof = self.home / ("prof%d" % len(self.procs))
        args = [helium(), "--headless=new", "--user-data-dir=%s" % prof, "--no-first-run",
                "--disable-gpu", "--disable-extensions"]
        if port_arg:
            args.append("--remote-debugging-port=0")
        p = subprocess.Popen(args + [self.url], start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.procs.append(p)
        return p, prof

    def port_of(self, prof):
        f = prof / "DevToolsActivePort"
        for _ in range(100):
            if f.exists() and f.read_text().strip():
                return int(f.read_text().split()[0])
            time.sleep(0.1)
        self.fail("no DevToolsActivePort")

    def page(self, port):
        for _ in range(100):
            try:
                ts = [t for t in json.load(__import__("urllib.request").request.urlopen(
                    "http://127.0.0.1:%d/json/list" % port, timeout=2))
                    if t.get("type") == "page" and "angelos-test" in t.get("url", "")]
                if ts:
                    return self.mod.WS(ts[0]["webSocketDebuggerUrl"])
            except OSError:
                pass
            time.sleep(0.1)
        self.fail("no page")

    def accent(self, ws):
        return ws.evaluate("getComputedStyle(document.documentElement).getPropertyValue('--ao-accent').trim()")

    def test_inject_survives_a_reload_and_follows_the_file(self):
        p, prof = self.browser()
        port = self.port_of(prof)
        ws = self.page(port)
        for _ in range(50):
            if ws.evaluate("document.readyState") == "complete":
                break
            time.sleep(0.1)
        self.assertEqual(self.run_script("inject", "--port", str(port), "--once")["applied"], 1)
        self.assertEqual(self.accent(ws), "#6871b3")
        # the strict CSP does not stop a constructed stylesheet
        self.assertEqual(ws.evaluate("getComputedStyle(document.getElementById('box')).borderTopLeftRadius"), "4px")
        self.assertTrue(ws.evaluate("!!document.getElementById('angelos-discord').dataset.v"))
        # nothing to do the second time
        self.assertEqual(self.run_script("inject", "--port", str(port), "--once")["applied"], 0)
        # the palette changes: the new theme goes in
        self.pal.write_text(json.dumps(dict(PALETTE, accent="#ff5cad")))
        self.run_script("build", str(self.pal))
        self.assertEqual(self.run_script("inject", "--port", str(port), "--once")["applied"], 1)
        self.assertEqual(self.accent(ws), "#ff5cad")
        # Ctrl+R: the page forgets it, the injector puts it back
        ws.call("Page.reload")
        ws.close()
        time.sleep(1)
        ws = self.page(port)
        for _ in range(50):
            if ws.evaluate("document.readyState") == "complete":
                break
            time.sleep(0.1)
        self.assertEqual(self.accent(ws), "")
        self.assertEqual(self.run_script("inject", "--port", str(port), "--once")["applied"], 1)
        self.assertEqual(self.accent(ws), "#ff5cad")
        ws.close()

    def test_launch_keeps_the_theme_while_the_app_lives(self):
        prof = self.home / "launched"
        self.env["ANGELOS_DISCORD_CMD"] = "%s --headless=new --user-data-dir=%s --no-first-run --disable-gpu --disable-extensions %s" % (
            helium(), prof, self.url)
        lp = subprocess.Popen([sys.executable, str(SCRIPT), "launch"], env=self.env, start_new_session=True,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.procs.append(lp)
        state = self.home / "run/angelos-discord.json"
        for _ in range(100):
            if state.exists():
                break
            time.sleep(0.1)
        st = json.loads(state.read_text())
        self.procs.append(type("P", (), {"pid": st["child"], "poll": lambda s: None, "wait": lambda s: None,
                                         "kill": lambda s: None})())
        ws = self.page(st["port"])
        for _ in range(100):
            if self.accent(ws) == "#6871b3":
                break
            time.sleep(0.1)
        self.assertEqual(self.accent(ws), "#6871b3")
        ws.close()
        # the app closes: launch is done and forgets its state
        os.killpg(st["child"], signal.SIGTERM)
        lp.wait(timeout=20)
        self.assertFalse(state.exists())


if __name__ == "__main__":
    unittest.main()
