"""Contract tests for the bottom-bar EQ bridge (a fake EasyEffects Unix socket)."""

import importlib.util
import json
import socket
import threading
import unittest
from tempfile import TemporaryDirectory
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "eq-bridge.py"
SPEC = importlib.util.spec_from_file_location("eq_bridge", SCRIPT)


class EqBridgeTest(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.module = importlib.util.module_from_spec(SPEC)
        SPEC.loader.exec_module(self.module)
        self.path = self.root / "EasyEffectsServer"
        self.listener = socket.socket(socket.AF_UNIX)
        self.listener.bind(str(self.path))
        self.listener.listen()
        self.listener.settimeout(0.1)
        self.addCleanup(self.listener.close)
        self.values = {
            "output:equalizer:0:numBands": "10",
            "output:equalizer:0:bypass": "false",
            "output:equalizer:0:outputGain": "0",
        }
        for i, freq in enumerate((31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000)):
            for channel in ("left", "right"):
                self.values[f"output:equalizer:0:{channel}:band{i}Gain"] = "0"
                self.values[f"output:equalizer:0:{channel}:band{i}Frequency"] = str(freq)
        self.events = []
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self.serve, daemon=True)
        self.thread.start()
        self.addCleanup(self.close_server)
        self.bridge = self.module.EqBridge(self.path, self.root)

    def close_server(self):
        self.stop.set()
        self.thread.join(timeout=1)

    def serve(self):
        while not self.stop.is_set():
            try:
                connection, _ = self.listener.accept()
            except socket.timeout:
                continue
            with connection:
                data = b""
                while not data.endswith(b"\n"):
                    chunk = connection.recv(1024)
                    if not chunk:
                        break
                    data += chunk
                command = data.decode().strip()
                self.events.append(command)
                if command.startswith("get_property:"):
                    key = command.partition(":")[2]
                    connection.sendall((self.values.get(key, "error_plugin_not_found") + "\n").encode())
                elif command.startswith("set_property:"):
                    key, _, value = command.partition(":")[2].rpartition(":")
                    self.values[key] = value

    def test_set_gain_updates_both_channels_and_headroom(self):
        result = self.bridge.execute("set 2 5.5")
        self.assertTrue(result["ready"])
        self.assertEqual(result["gains"][2], 5.5)
        self.assertEqual(self.values["output:equalizer:0:left:band2Gain"], "5.5")
        self.assertEqual(self.values["output:equalizer:0:right:band2Gain"], "5.5")
        self.assertEqual(self.values["output:equalizer:0:outputGain"], "-5.5")

    def test_presets_change_real_bands_not_just_the_label(self):
        result = self.bridge.execute("preset voice")
        self.assertEqual(result["preset"], "voice")
        self.assertLess(result["gains"][0], 0)
        self.assertGreater(result["gains"][5], 0)
        self.assertEqual(float(self.values["output:equalizer:0:right:band5Gain"]), result["gains"][5])
        self.assertGreaterEqual(len([c for c in self.events if c.startswith("set_property:")]), 21)

    def test_invalid_input_never_reaches_audio_server(self):
        for command in ("set -1 4", "set 0 nan", "set 10 2", "set 1 100", "preset not-real"):
            self.assertTrue(self.bridge.execute(command)["error"])
        self.assertFalse(any(c.startswith("set_property:") for c in self.events))

    def test_start_refuses_to_replace_existing_effect_chain(self):
        del self.values["output:equalizer:0:numBands"]
        config = self.root / "easyeffectsrc"
        config.write_text("[StreamOutputs]\nplugins=compressor#0\n")
        bridge = self.module.EqBridge(self.path, self.root, config_path=config)
        result = bridge.execute("start")
        self.assertFalse(result["ready"])
        self.assertTrue(result["error"])
        self.assertFalse(any(c.startswith("load_preset:") for c in self.events))

    def test_bootstrap_preset_contains_real_stereo_bands(self):
        preset = self.bridge.bootstrap_preset()
        eq = preset["output"]["equalizer#0"]
        self.assertEqual(preset["output"]["plugins_order"], ["equalizer#0"])
        self.assertEqual(eq["num-bands"], 10)
        self.assertEqual(eq["left"]["band0"]["frequency"], 31)
        self.assertEqual(eq["right"]["band9"]["frequency"], 16000)
        self.assertEqual(eq["output-gain"], 0)
        json.dumps(preset)

    def test_flatpak_socket_is_in_private_runtime_tmp(self):
        private = self.root / ".flatpak/com.github.wwmm.easyeffects/tmp/EasyEffectsServer"
        private.parent.mkdir(parents=True)
        private.touch()
        self.assertEqual(self.module.EqBridge.discover_socket(self.root, True), private)
