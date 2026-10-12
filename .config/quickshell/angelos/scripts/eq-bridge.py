#!/usr/bin/env python3
"""Small line protocol between the angelOS bar and EasyEffects 8.3's local socket.

Only the output equalizer is touched. The microphone pipeline is never read or written.
"""

import configparser
import json
import math
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time

FREQUENCIES = (31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000)
PRESETS = {
    "flat": (0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    "bass": (3, 3, 2, 1, 0, -1, -1, 0, 0, 0),
    "voice": (-3, -2, -1, 0, 1, 2, 2, 1, 0, -1),
    "air": (-2, -1, 0, 0, 0, 1, 2, 3, 2, 1),
    "soft": (0, 1, 0, 0, 0, -1, -1, -1, -2, -2),
}
PRESET_NAME = "angelOS Panel EQ"


class EqBridge:
    @staticmethod
    def discover_socket(runtime_dir, flatpak):
        runtime = Path(runtime_dir)
        if flatpak:
            # QStandardPaths::TempLocation inside Flatpak is its private /tmp, which
            # the host sees below XDG_RUNTIME_DIR/.flatpak, not at host /tmp.
            private = runtime / ".flatpak/com.github.wwmm.easyeffects/tmp/EasyEffectsServer"
            legacy = Path(tempfile.gettempdir()) / "EasyEffectsServer"
            return private if private.exists() or not legacy.exists() else legacy
        return runtime / "EasyEffectsServer"

    def __init__(self, socket_path=None, preset_dir=None, config_path=None):
        flatpak = Path.home() / ".var/app/com.github.wwmm.easyeffects"
        native = Path.home() / ".local/share/easyeffects"
        self.socket_path = Path(socket_path or self.discover_socket(
            os.environ.get("XDG_RUNTIME_DIR", "/tmp"), flatpak.exists()))
        self.preset_dir = Path(preset_dir or (
            flatpak / "data/easyeffects/output" if flatpak.exists() else native / "output"
        ))
        self.config_path = Path(config_path or (
            flatpak / "config/easyeffects/db/easyeffectsrc"
            if flatpak.exists() else Path.home() / ".config/easyeffects/db/easyeffectsrc"
        ))

    def request(self, message, reply=False):
        with socket.socket(socket.AF_UNIX) as connection:
            connection.settimeout(0.8)
            connection.connect(str(self.socket_path))
            connection.sendall((message + "\n").encode("utf-8"))
            if not reply:
                return ""
            data = b""
            while not data.endswith(b"\n") and len(data) < 1024:
                chunk = connection.recv(1024)
                if not chunk:
                    break
                data += chunk
            return data.decode("utf-8").strip()

    def get(self, property_name, channel=None):
        prefix = f"get_property:output:equalizer:0:"
        value = self.request(prefix + (channel + ":" if channel else "") + property_name, True)
        if value.startswith("error_") or value == "":
            raise ValueError(value or "EasyEffects не ответил")
        return value

    def set(self, property_name, value, channel=None):
        prefix = "set_property:output:equalizer:0:"
        self.request(prefix + (channel + ":" if channel else "") + property_name + ":" + str(value))

    @staticmethod
    def bootstrap_preset():
        def bands():
            return {
                f"band{i}": {
                    "frequency": freq, "gain": 0.0, "q": 1.0, "width": 4.0,
                    "type": "Bell", "mode": "RLC (BT)", "slope": "x1",
                    "solo": False, "mute": False,
                }
                for i, freq in enumerate(FREQUENCIES)
            }
        return {
            "output": {
                "blocklist": [],
                "plugins_order": ["equalizer#0"],
                "equalizer#0": {
                    "bypass": False, "input-gain": 0.0, "output-gain": 0.0,
                    "mode": "IIR", "decramp": "Off", "num-bands": 10,
                    "split-channels": False, "balance": 0.0,
                    "pitch-left": 0.0, "pitch-right": 0.0,
                    "left": bands(), "right": bands(),
                },
            }
        }

    def state(self, error=""):
        result = {
            "ready": False, "error": error, "gains": list(PRESETS["flat"]),
            "freqs": list(FREQUENCIES), "preset": "", "enabled": False,
        }
        if not self.socket_path.exists():
            result["error"] = error or "EasyEffects не запущен"
            return result
        try:
            count = int(self.get("numBands"))
            if count != 10:
                result["error"] = f"В EasyEffects сейчас {count} полос. Для панели нужно 10."
                return result
            result["gains"] = [float(self.get(f"band{i}Gain", "left")) for i in range(10)]
            result["freqs"] = [round(float(self.get(f"band{i}Frequency", "left"))) for i in range(10)]
            result["enabled"] = self.get("bypass").lower() in ("false", "0")
            result["ready"] = True
            result["error"] = error
            for name, levels in PRESETS.items():
                if all(abs(a - b) < 0.05 for a, b in zip(result["gains"], levels)):
                    result["preset"] = name
                    break
        except (OSError, ValueError, TimeoutError) as exc:
            result["error"] = error or ("Добавьте Equalizer в цепочку выхода EasyEffects"
                                        if "error_plugin_not_found" in str(exc) else str(exc))
        return result

    def _has_other_effects(self):
        config = configparser.ConfigParser(interpolation=None)
        config.read(self.config_path)
        return bool(config.get("StreamOutputs", "plugins", fallback="").strip())

    def start(self):
        if not self.socket_path.exists():
            flatpak = Path.home() / ".var/app/com.github.wwmm.easyeffects"
            if flatpak.exists() and shutil.which("flatpak"):
                command = ["flatpak", "run", "com.github.wwmm.easyeffects", "--service-mode", "--hide-window"]
            elif shutil.which("easyeffects"):
                command = ["easyeffects", "--service-mode", "--hide-window"]
            else:
                return self.state("Установите EasyEffects, чтобы включить EQ")
            subprocess.Popen(command, start_new_session=True, stdin=subprocess.DEVNULL,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            for _ in range(50):
                if self.socket_path.exists():
                    break
                time.sleep(0.2)
        if self.state()["ready"]:
            return self.state()
        if self._has_other_effects():
            return self.state("Цепочка выхода уже занята: добавьте Equalizer в EasyEffects вручную, чтобы её не заменить")
        self.preset_dir.mkdir(parents=True, exist_ok=True)
        destination = self.preset_dir / (PRESET_NAME + ".json")
        if not destination.exists():
            with destination.open("x", encoding="utf-8") as file:
                json.dump(self.bootstrap_preset(), file, indent=2)
        try:
            self.request("load_preset:output:" + PRESET_NAME)
            for _ in range(20):
                time.sleep(0.15)
                if self.state()["ready"]:
                    return self.state()
        except (OSError, ValueError) as exc:
            return self.state(str(exc))
        return self.state("EasyEffects не смог загрузить EQ; проверьте выход и плагин LSP")

    def execute(self, command):
        parts = command.strip().split()
        try:
            if not parts or parts[0] == "status":
                return self.state()
            if parts[0] == "start" and len(parts) == 1:
                return self.start()
            if parts[0] == "set" and len(parts) == 3:
                index = int(parts[1])
                gain = float(parts[2])
                if index not in range(10) or not math.isfinite(gain) or not -12 <= gain <= 12:
                    raise ValueError("Полоса: 0–9; усиление: −12…+12 dB")
                if not self.state()["ready"]:
                    return self.state()
                for channel in ("left", "right"):
                    self.set(f"band{index}Gain", gain, channel)
                self._headroom()
                return self.state()
            if parts[0] == "preset" and len(parts) == 2:
                levels = PRESETS.get(parts[1])
                if levels is None:
                    raise ValueError("Неизвестный пресет")
                if not self.state()["ready"]:
                    return self.state()
                for index, gain in enumerate(levels):
                    for channel in ("left", "right"):
                        self.set(f"band{index}Gain", gain, channel)
                self._headroom()
                return self.state()
            if parts[0] == "toggle" and len(parts) == 1:
                state = self.state()
                if not state["ready"]:
                    return state
                self.set("bypass", str(state["enabled"]).lower())
                return self.state()
            raise ValueError("Неизвестная команда EQ")
        except (OSError, ValueError, TimeoutError) as exc:
            return self.state(str(exc))

    def _headroom(self):
        gains = [float(self.get(f"band{i}Gain", "left")) for i in range(10)]
        self.set("outputGain", -max(0, *gains))


def main():
    bridge = EqBridge()
    for line in sys.stdin:
        try:
            response = bridge.execute(line)
        except Exception as exc:
            response = {"ready": False, "error": str(exc)}
        print(json.dumps(response, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
