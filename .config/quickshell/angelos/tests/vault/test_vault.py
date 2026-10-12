#!/usr/bin/env python3
"""scripts/vault.py against stand-ins of bw, rbw, op and the clipboard (tests/vault/fake): the
states, the list without a single secret in it, unlocking, the copy that goes to the clipboard
marked sensitive and is wiped afterwards — and that a locked rbw is never asked anything
(the real one would pop its pinentry up).
Run: python3 tests/vault/test_vault.py   (scripts/check.sh runs it)
"""
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FAKE = Path(__file__).resolve().parent / "fake"
SCRIPT = ROOT / "scripts" / "vault.py"
SECRETS = ("gh-secret-1", "пароль-ё", "wifi pass with spaces", "secret note")


class Vault(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp(prefix="aos-vault-"))
        self.bin = self.dir / "bin"
        self.bin.mkdir()
        self.tools("bw", "rbw", "op", "wl-copy", "wl-paste", "secret-tool")
        self.state(bw="locked", rbw="locked", op="locked")

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def tools(self, *names):
        """only these exist; python3 comes from the system, nothing else does"""
        shutil.rmtree(self.bin)
        self.bin.mkdir()
        os.symlink(shutil.which("python3"), self.bin / "python3")
        os.symlink(shutil.which("sh"), self.bin / "sh")
        os.symlink(shutil.which("dirname"), self.bin / "dirname")
        for n in names:
            (self.bin / n).write_text('#!/bin/sh\nexec python3 "%s/cli.py" %s "$@"\n' % (FAKE, n))
            (self.bin / n).chmod(0o755)

    def state(self, **kw):
        f = self.dir / "state.json"
        s = json.loads(f.read_text()) if f.exists() else {}
        s.update(kw)
        f.write_text(json.dumps(s))

    def run_vault(self, *args, stdin=None, **env):
        e = {"PATH": str(self.bin), "HOME": str(self.dir), "FAKE_VAULT_DIR": str(self.dir), "ANGELOS_LANG": "en", "ANGELOS_TEST": "1",
             "XDG_STATE_HOME": str(self.dir / "state")}
        e.update(env)
        done = subprocess.run([sys.executable, str(SCRIPT), *args], env=e, input=stdin, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, text=True, timeout=30)
        self.last = done
        return json.loads(done.stdout.strip().splitlines()[-1])

    def backends(self, **env):
        return {b["id"]: b for b in self.run_vault("status", **env)["backends"]}

    def calls(self):
        f = self.dir / "calls.log"
        return f.read_text().splitlines() if f.exists() else []

    def test_states(self):
        b = self.backends()
        self.assertEqual([b[i]["state"] for i in ("bw", "rbw", "op")], ["locked", "locked", "locked"])
        self.assertEqual(b["bw"]["account"], "angel@example.com")
        self.assertEqual((b["bw"]["ask"], b["rbw"]["ask"]), ("password", "own"))
        self.state(bw="out", rbw="unset", op="out")
        b = self.backends()
        self.assertEqual([b[i]["state"] for i in ("bw", "rbw", "op")], ["setup", "setup", "setup"])
        self.tools("wl-copy", "wl-paste")
        b = self.backends()
        self.assertEqual([(b[i]["installed"], b[i]["state"]) for i in ("bw", "rbw", "op")], [(False, "missing")] * 3)

    def test_bw_unlock_list_copy(self):
        wrong = self.run_vault("unlock", "bw", "--stdin", stdin="nope\n")
        self.assertFalse(wrong["ok"])
        self.assertIn("Invalid master password", wrong["error"])
        self.assertEqual(self.run_vault("unlock", "bw")["ask"], "password")       # nothing typed: ask
        res = self.run_vault("unlock", "bw", "--stdin", stdin="correct horse\n")
        self.assertTrue(res["ok"] and res["session"])
        key = res["session"]
        self.assertEqual(self.backends()["bw"]["state"], "locked")               # no key, no vault
        self.assertEqual(self.backends(ANGELOS_BW_SESSION=key)["bw"]["state"], "unlocked")
        listed = self.run_vault("list", "bw", ANGELOS_BW_SESSION=key)
        self.assertEqual([i["name"] for i in listed["items"]], ["GitHub", "Wi-Fi дома", "Почта"])   # logins only, by name
        github = listed["items"][0]
        self.assertEqual((github["backend"], github["user"], github["url"], github["totp"]), ("bw", "angel@example.com", "https://github.com/login", True))
        for secret in SECRETS + ("123456",):
            self.assertNotIn(secret, self.last.stdout)
        ok = self.run_vault("copy", "bw", github["id"], "password", "--clear", "0", ANGELOS_BW_SESSION=key)
        self.assertTrue(ok["ok"], ok)
        self.assertNotIn("gh-secret-1", self.last.stdout + self.last.stderr)
        self.assertEqual((self.dir / "clipboard").read_text(), "gh-secret-1")
        self.assertIn("--sensitive", (self.dir / "clipboard.args").read_text())
        self.run_vault("copy", "bw", "22222222-bbbb", "password", "--clear", "0", ANGELOS_BW_SESSION=key)
        self.assertEqual((self.dir / "clipboard").read_text(), "пароль-ё")
        self.run_vault("copy", "bw", github["id"], "totp", "--clear", "0", ANGELOS_BW_SESSION=key)
        self.assertEqual((self.dir / "clipboard").read_text(), "123456")
        none = self.run_vault("copy", "bw", "33333333-cccc", "totp", "--clear", "0", ANGELOS_BW_SESSION=key)
        self.assertFalse(none["ok"])
        self.assertEqual((self.dir / "clipboard").read_text(), "123456")          # a failed copy leaves the clipboard
        # the key is the manager's own business: never an argument of anything
        self.assertFalse([c for c in self.calls() if key in c or "correct horse" in c])
        self.assertTrue(self.run_vault("lock", "bw", ANGELOS_BW_SESSION=key)["ok"])
        self.assertEqual(self.backends(ANGELOS_BW_SESSION=key)["bw"]["state"], "locked")
        self.assertIn("bw", self.run_vault("list", "bw", ANGELOS_BW_SESSION=key)["errors"])

    def test_clipboard_wiped(self):
        key = self.run_vault("unlock", "bw", "--stdin", stdin="correct horse\n")["session"]
        self.run_vault("copy", "bw", "11111111-aaaa", "password", "--clear", "1", ANGELOS_BW_SESSION=key)
        self.assertEqual((self.dir / "clipboard").read_text(), "gh-secret-1")
        for _ in range(60):
            if not (self.dir / "clipboard").exists():
                break
            time.sleep(0.1)
        self.assertFalse((self.dir / "clipboard").exists(), "the secret is still in the clipboard")
        # something else copied meanwhile stays
        self.run_vault("copy", "bw", "11111111-aaaa", "password", "--clear", "1", ANGELOS_BW_SESSION=key)
        (self.dir / "clipboard").write_text("my own text")
        time.sleep(2.5)
        self.assertEqual((self.dir / "clipboard").read_text(), "my own text")

    def test_rbw_never_asked_while_locked(self):
        listed = self.run_vault("list", "rbw")
        self.assertEqual(listed["items"], [])
        self.assertIn("rbw", listed["errors"])
        self.assertFalse(self.run_vault("copy", "rbw", "11111111-aaaa", "password")["ok"])
        self.assertFalse((self.dir / "pinentry-opened").exists(), "a locked rbw was asked: its pinentry would have opened")
        self.state(rbw_deny=True)
        self.assertFalse(self.run_vault("unlock", "rbw")["ok"])
        self.state(rbw_deny=False)
        self.assertTrue(self.run_vault("unlock", "rbw")["ok"])
        listed = self.run_vault("list", "rbw")
        self.assertEqual(len(listed["items"]), 3)                                 # the note is no login
        self.run_vault("copy", "rbw", "33333333-cccc", "password", "--clear", "0")
        self.assertEqual((self.dir / "clipboard").read_text(), "wifi pass with spaces")
        self.run_vault("copy", "rbw", "11111111-aaaa", "totp", "--clear", "0")
        self.assertEqual((self.dir / "clipboard").read_text(), "123456")
        self.run_vault("copy", "rbw", "11111111-aaaa", "username", "--clear", "0")
        self.assertEqual((self.dir / "clipboard").read_text(), "angel@example.com")

    def test_op_app_and_token(self):
        # with the desktop app: it answers by itself
        self.state(op_app=True)
        res = self.run_vault("unlock", "op")
        self.assertEqual((res["ok"], res["session"]), (True, ""))
        self.assertEqual(self.backends()["op"]["state"], "unlocked")
        listed = self.run_vault("list", "op")
        self.assertEqual([i["name"] for i in listed["items"]], ["GitHub", "Wi-Fi дома", "Почта"])
        self.assertEqual(listed["items"][1]["user"], "")
        self.run_vault("copy", "op", "11111111-aaaa", "password", "--clear", "0")
        self.assertEqual((self.dir / "clipboard").read_text(), "gh-secret-1")
        self.run_vault("lock", "op")
        # without it: nothing typed → the shell is told to ask; then a token
        self.state(op_app=False, op="locked")
        res = self.run_vault("unlock", "op")
        self.assertEqual((res["ok"], res["ask"], res["error"]), (False, "password", ""))
        self.assertFalse(self.run_vault("unlock", "op", "--stdin", stdin="nope\n")["ok"])
        res = self.run_vault("unlock", "op", "--stdin", stdin="correct horse\n")
        self.assertTrue(res["ok"] and res["session"])
        self.assertEqual(self.backends()["op"]["state"], "locked")
        self.assertEqual(self.backends(ANGELOS_OP_SESSION=res["session"])["op"]["state"], "unlocked")
        self.run_vault("copy", "op", "11111111-aaaa", "totp", "--clear", "0", ANGELOS_OP_SESSION=res["session"])
        self.assertEqual((self.dir / "clipboard").read_text(), "123456")

    def login(self, bid, typed):
        """the terminal's first sign-in, with these lines typed; → (exit code, what it printed, the state)"""
        e = {"PATH": str(self.bin), "HOME": str(self.dir), "FAKE_VAULT_DIR": str(self.dir), "ANGELOS_LANG": "en"}
        done = subprocess.run([sys.executable, str(SCRIPT), "login", bid], env=e, input=typed, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True, timeout=30)
        return done.returncode, done.stdout, json.loads((self.dir / "state.json").read_text())

    def test_first_sign_in_and_the_server_question(self):
        spec = importlib.util.spec_from_file_location("vault", SCRIPT)
        vault = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(vault)
        for typed, want in (("", ""), ("  ", ""), ("eu", "https://vault.bitwarden.eu"), ("vault.example.org", "https://vault.example.org"),
                            ("https://vw.home.lan:8443/", "https://vw.home.lan:8443"), ("http://localhost:8080", "http://localhost:8080"),
                            ("angel@example.com", None), ("my password", None), ("да", None), ("vaultwarden", None)):
            self.assertEqual(vault.server_url(typed), want, typed)
        # Enter: the usual Bitwarden, nothing set
        self.state(bw="out")
        code, said, st = self.login("bw", "\n")
        self.assertEqual((code, st["bw"], st.get("bw_server")), (0, "locked", None), said)
        # the e-mail typed where the server was asked (what happened to the author): told so, asked
        # again, never set as the server
        self.state(bw="out")
        code, said, st = self.login("bw", "angel@example.com\n\n")
        self.assertEqual((code, st.get("bw_server")), (0, None), said)
        self.assertIn("looks like an e-mail", said)
        # …and one already set that way by an earlier try is put right by a plain Enter
        self.state(bw="out", bw_server="https://angel@example.com")
        code, said, st = self.login("bw", "\n")
        self.assertEqual((code, st["bw"], st.get("bw_server")), (0, "locked", None), said)
        self.assertIn("angel@example.com", said)
        # a server of one's own: set; kept by Enter the next time; "no" goes back to bitwarden.com
        self.state(bw="out")
        self.assertEqual(self.login("bw", "vw.example.org\n")[2].get("bw_server"), "https://vw.example.org")
        self.state(bw="out")
        self.assertEqual(self.login("bw", "\n")[2].get("bw_server"), "https://vw.example.org")
        self.state(bw="out")
        self.assertEqual(self.login("bw", "no\n")[2].get("bw_server"), None)
        # rbw: the e-mail first, then the same question
        self.state(rbw="unset")
        code, said, st = self.login("rbw", "angel@example.com\nangel@example.com\n\n")
        self.assertEqual((code, st.get("rbw_email"), st.get("rbw_url")), (0, "angel@example.com", None), said)
        self.state(rbw="unset")
        self.assertEqual(self.login("rbw", "not-a-mail\n")[0], 1)

    def kept(self):
        f = self.dir / "keyring-service-angelos-vault-backend-bw"
        return f.read_text() if f.exists() else None

    def test_remembered_in_the_keyring(self):
        self.assertEqual(self.backends()["bw"]["saved"], "")
        self.assertFalse(self.run_vault("remember", "bw", stdin="nope\n")["ok"])           # checked by unlocking first
        self.assertIsNone(self.kept())
        self.assertFalse(self.run_vault("remember", "rbw", stdin="x\n")["ok"])             # rbw asks by itself
        res = self.run_vault("remember", "bw", stdin="correct horse\n")
        self.assertTrue(res["ok"] and res["session"] and res["saved"] == "keyring")
        self.assertEqual(self.backends()["bw"]["saved"], "keyring")
        self.run_vault("lock", "bw")
        res = self.run_vault("unlock", "bw", "--saved")                                    # nothing typed at all
        self.assertTrue(res["ok"] and res["session"])
        self.assertEqual(self.backends(ANGELOS_BW_SESSION=res["session"])["bw"]["state"], "unlocked")
        self.assertFalse([c for c in self.calls() if "correct horse" in c])
        self.run_vault("forget", "bw")
        self.assertIsNone(self.kept())
        self.assertEqual(self.backends()["bw"]["saved"], "")
        res = self.run_vault("unlock", "bw", "--saved")
        self.assertEqual((res["ok"], res["ask"]), (False, "password"))
        # a master password changed since: forgotten, asked for again
        self.run_vault("remember", "bw", stdin="correct horse\n")
        (self.dir / "keyring-service-angelos-vault-backend-bw").write_text(json.dumps({"mode": "keyring", "pw": "old one"}))
        res = self.run_vault("unlock", "bw", "--saved")
        self.assertEqual((res["ok"], res["ask"], res["saved"]), (False, "password", ""))
        self.assertIsNone(self.kept())

    def test_remembered_under_a_pin(self):
        self.assertFalse(self.run_vault("remember", "bw", "--pin", stdin="correct horse\n12\n")["ok"])   # too short
        res = self.run_vault("remember", "bw", "--pin", stdin="correct horse\n4821\n")
        self.assertEqual((res["ok"], res["saved"]), (True, "pin"))
        self.assertNotIn("correct horse", self.kept())                                     # only its locked form is kept
        self.assertNotIn("4821", self.kept())
        self.assertEqual(self.backends()["bw"]["saved"], "pin")
        self.run_vault("lock", "bw")
        self.assertEqual(self.run_vault("unlock", "bw", "--saved")["ask"], "pin")          # no PIN typed: ask for it
        bad = self.run_vault("unlock", "bw", "--saved", "--stdin", stdin="0000\n")
        self.assertEqual((bad["ok"], bad["ask"]), (False, "pin"))
        self.assertIn("4", bad["error"])
        res = self.run_vault("unlock", "bw", "--saved", "--stdin", stdin="4821\n")
        self.assertTrue(res["ok"] and res["session"])
        # a right PIN gives the tries back; five wrong ones in a row forget it
        for n in range(4):
            self.assertEqual(self.run_vault("unlock", "bw", "--saved", "--stdin", stdin="1111\n")["ask"], "pin", n)
        last = self.run_vault("unlock", "bw", "--saved", "--stdin", stdin="1111\n")
        self.assertEqual((last["ok"], last["ask"], last["saved"]), (False, "password", ""))
        self.assertIsNone(self.kept())
        self.assertFalse(self.run_vault("unlock", "bw", "--saved", "--stdin", stdin="4821\n")["ok"])
        self.assertTrue(self.run_vault("unlock", "bw", "--stdin", stdin="correct horse\n")["ok"])   # the master password still works

    def test_bad_requests(self):
        self.assertFalse(self.run_vault("copy", "bw", "11111111-aaaa", "notes")["ok"])
        self.assertFalse(self.run_vault("copy", "nope", "x", "password")["ok"])
        self.assertFalse(self.run_vault("unlock", "nope")["ok"])
        self.assertEqual(self.run_vault("list", "nope")["items"], [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
