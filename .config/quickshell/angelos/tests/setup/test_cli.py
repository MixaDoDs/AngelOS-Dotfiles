#!/usr/bin/env python3
"""Offline setup CLI contract: real entry points, temporary HOME, fake qs only."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
CLI = ROOT / "bin/angelos"
HELPER = ROOT / "scripts/setup-cli.py"

FAKE_QS = """
import json
import os
from pathlib import Path
import sys
import time

marker = Path.home() / ".config/angelos/setup-skipped"
with open(os.environ["QS_LOG"], "a") as log:
    log.write(json.dumps({"args": sys.argv[1:], "marker": marker.is_file()}) + "\\n")
mode = os.environ.get("QS_MODE", "ok")
if mode == "hang":
    time.sleep(30)
if mode == "missing-function":
    print("Function not found: setupSkip")
if mode == "offline":
    print("No running instances", file=sys.stderr)
    sys.exit(7)
"""


class SetupCLI(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="angelos-setup-")
        self.addCleanup(tmp.cleanup)
        self.home = Path(tmp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        # A closed PATH prevents any accidental contact with the real shell.
        for name in ("sed", "id"):
            (self.bin / name).symlink_to(shutil.which(name))
        (self.bin / "python3").symlink_to(sys.executable)
        self.qs = self.bin / "qs"
        self.qs.write_text(f"#!{sys.executable}\n" + FAKE_QS)
        self.qs.chmod(0o755)
        self.xdg = self.home / "other-config"
        (self.xdg / "quickshell").mkdir(parents=True)
        (self.xdg / "quickshell/angelos").symlink_to(ROOT, target_is_directory=True)
        self.config = self.home / ".config/angelos"
        self.config.mkdir(parents=True)
        self.marker = self.config / "setup-skipped"
        self.log = self.home / "qs.log"
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin),
                        XDG_CONFIG_HOME=str(self.xdg),
                        XDG_RUNTIME_DIR=str(self.home / "run"),
                        QS_LOG=str(self.log), QS_MODE="ok", PYTHONDONTWRITEBYTECODE="1")
        self.originals = {}
        for name, content in (("settings.json", b'{"setupDone":false, "custom":42}\n'),
                              ("save.json", b'{"chapter":3, "choices":["stay"]}\n')):
            path = self.config / name
            path.write_bytes(content)
            self.originals[path] = (content, path.stat().st_mtime_ns)

    def run_cli(self, *args, helper=False):
        command = [sys.executable, str(HELPER)] if helper else ["/bin/sh", str(CLI)]
        try:
            return subprocess.run(command + list(args), env=self.env,
                                  capture_output=True, text=True, timeout=5)
        except subprocess.TimeoutExpired:
            self.fail("setup CLI did not bound the IPC attempt to two seconds")

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def assert_skipped(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.marker.is_file(), result.stdout + result.stderr)
        self.assertFalse((self.xdg / "angelos/setup-skipped").exists())
        for path, original in self.originals.items():
            self.assertEqual((path.read_bytes(), path.stat().st_mtime_ns), original)

    def assert_skip_call(self):
        self.assertEqual(self.calls(), [{
            "args": ["-c", "angelos", "ipc", "--any-display", "call", "angelos", "setupSkip"],
            "marker": True,
        }])

    def test_skip_persists_before_void_ipc_without_changing_settings_or_save(self):
        result = self.run_cli("setup", "skip")
        self.assert_skipped(result)
        self.assert_skip_call()
        self.assertNotIn("angelos restart", result.stdout + result.stderr)

    def test_skip_succeeds_when_ipc_is_offline(self):
        self.env["QS_MODE"] = "offline"
        result = self.run_cli("setup", "skip")
        self.assert_skipped(result)
        self.assert_skip_call()
        self.assertIn("angelos restart", result.stdout + result.stderr)

    def test_skip_times_out_hung_ipc(self):
        self.env["QS_MODE"] = "hang"
        start = time.monotonic()
        result = self.run_cli("setup", "skip")
        elapsed = time.monotonic() - start
        self.assert_skipped(result)
        self.assert_skip_call()
        self.assertGreaterEqual(elapsed, 1.8)
        self.assertLess(elapsed, 3.5)
        self.assertIn("angelos restart", result.stdout + result.stderr)

    def test_skip_succeeds_without_qs_installed(self):
        self.qs.unlink()
        result = self.run_cli("setup", "skip")
        self.assert_skipped(result)
        self.assertEqual(self.calls(), [])
        self.assertIn("angelos restart", result.stdout + result.stderr)

    def test_skip_locates_qs_in_local_bin(self):
        local = self.home / ".local/bin"
        local.mkdir(parents=True)
        self.qs.rename(local / "qs")
        result = self.run_cli("setup", "skip")
        self.assert_skipped(result)
        self.assert_skip_call()
        self.assertNotIn("angelos restart", result.stdout + result.stderr)

    def test_skip_handles_old_shell_without_setup_skip(self):
        self.env["QS_MODE"] = "missing-function"
        result = self.run_cli("setup", "skip")
        self.assert_skipped(result)
        self.assert_skip_call()
        self.assertIn("angelos restart", result.stdout + result.stderr)

    def test_plain_setup_preserves_ipc_arguments_and_exit_code(self):
        self.env["QS_MODE"] = "offline"
        result = self.run_cli("setup")
        self.assertEqual(result.returncode, 7)
        self.assertEqual(self.calls(), [{
            "args": ["-c", "angelos", "ipc", "call", "angelos", "setup"],
            "marker": False,
        }])
        self.assertFalse(self.marker.exists())

    def test_unknown_setup_arguments_do_not_write_or_call_ipc(self):
        for args in (("setup", "unknown"), ("setup", "skip", "extra")):
            with self.subTest(args=args):
                result = self.run_cli(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.marker.exists())
                self.assertEqual(self.calls(), [])
                self.assertIn("setup [skip]", result.stdout + result.stderr)

    def test_unknown_top_level_command_does_not_create_marker(self):
        self.env["QS_MODE"] = "offline"
        self.run_cli("unknown")
        self.assertFalse(self.marker.exists())

    def test_help_exposes_skip_without_a_running_shell(self):
        self.env["QS_MODE"] = "offline"
        result = self.run_cli("help")
        self.assertIn("setup [skip]", result.stdout)
        self.assertFalse(self.marker.exists())

    def test_direct_helper_creates_missing_config_and_is_repeatable(self):
        for path in self.originals:
            path.unlink()
        self.originals.clear()
        self.config.rmdir()
        for _ in range(2):
            result = self.run_cli("skip", helper=True)
            self.assert_skipped(result)
        self.assertFalse((self.config / "settings.json").exists())
        self.assertFalse((self.config / "save.json").exists())

    def test_marker_write_failure_is_reported_before_ipc(self):
        self.marker.mkdir()
        result = self.run_cli("setup", "skip")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assertIn("setup-skipped", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_direct_helper_rejects_unknown_command(self):
        result = self.run_cli("unknown", helper=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.marker.exists())
        self.assertEqual(self.calls(), [])
        self.assertIn("setup [skip]", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
