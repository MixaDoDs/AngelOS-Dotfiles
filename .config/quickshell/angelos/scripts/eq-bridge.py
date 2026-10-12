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
import shlex
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
RODE_OUTPUTS = {
    "rcp_duo_game_in": "Game",
    "rcp_duo_system_in": "System",
    "rcp_duo_chat_in": "Chat",
    "rcp_duo_music_in": "Music",
}
EE_OUTPUT_NODE = "ee_soe_output_level"
EE_SINK = "easyeffects_sink"
IGNORED_APPLICATIONS = {"angelos-sfx", "easyeffects", "Easy Effects", "pw-record"}
# Share of the largest boost taken back from the output gain. Bell bands lift the whole
# signal by far less than their peak, so full compensation only makes everything quieter.
HEADROOM_SHARE = 0.5


def output_choices(sinks):
    """The RØDECaster's virtual channels when it is there, otherwise every other output."""
    names = {sink.get("name") for sink in sinks}
    rode = [{"name": name, "label": label} for name, label in RODE_OUTPUTS.items() if name in names]
    if rode:
        return rode
    return [
        {"name": sink["name"], "label": str(sink.get("description") or sink["name"])}
        for sink in sinks
        if sink.get("name") and sink["name"] != EE_SINK
    ]


def source_snapshot(sinks, sink_inputs):
    """Return selectable app groups and the four RØDECaster virtual output channels."""
    sinks_by_index = {str(item.get("index")): item.get("name", "") for item in sinks}
    apps = {}
    for item in sink_inputs:
        props = item.get("properties") or {}
        app_name = str(props.get("application.name") or "").strip()
        if not app_name or app_name in IGNORED_APPLICATIONS:
            continue
        sink_name = sinks_by_index.get(str(item.get("sink")), "")
        group = apps.setdefault(app_name, {
            "id": app_name,
            "app": app_name,
            "streams": [],
            "sinks": [],
        })
        stream_name = str(props.get("media.name") or props.get("node.name") or "Audio")
        group["streams"].append({
            "id": str(item.get("index")),
            "name": stream_name,
            "sink": sink_name,
            "process": str(props.get("application.process.id") or ""),
            "serial": str(props.get("object.serial") or ""),
        })
        if sink_name and sink_name not in group["sinks"]:
            group["sinks"].append(sink_name)

    return {
        "apps": sorted(apps.values(), key=lambda app: app["app"].casefold()),
        "outputs": output_choices(sinks),
        "rode": any(sink.get("name") in RODE_OUTPUTS for sink in sinks),
    }


def same_stream_identity(item, saved):
    props = item.get("properties") or {}
    if props.get("application.name") != saved.get("app"):
        return False
    saved_process = saved.get("process") or ""
    if saved_process and str(props.get("application.process.id") or "") != saved_process:
        return False
    saved_serial = saved.get("serial") or ""
    if saved_serial and str(props.get("object.serial") or "") != saved_serial:
        return False
    saved_stream = saved.get("stream") or ""
    current_stream = str(props.get("media.name") or props.get("node.name") or "")
    return not saved_stream or current_stream == saved_stream


def parse_ee_target(links):
    """Find the stereo sink currently receiving EasyEffects' output-level node."""
    targets = set()
    current_target = ""
    for line in links.splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("|"):
            # only an output's playback ports: a recorder listening to the node is not a target
            node, _, port = stripped.partition(":")
            current_target = node if port.startswith("playback_") else ""
        elif (current_target and stripped.startswith("|<- ")
              and f"{EE_OUTPUT_NODE}:output_" in stripped):
            targets.add(current_target)
    return targets.pop() if len(targets) == 1 else ""


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

    def __init__(self, socket_path=None, preset_dir=None, config_path=None,
                 route_state_path=None, command_runner=None):
        flatpak = Path.home() / ".var/app/com.github.wwmm.easyeffects"
        native = Path.home() / ".local/share/easyeffects"
        # kept across reboots: PipeWire remembers that the app plays into EasyEffects too
        state_home = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
        self.socket_path = Path(socket_path or self.discover_socket(
            os.environ.get("XDG_RUNTIME_DIR", "/tmp"), flatpak.exists()))
        self.preset_dir = Path(preset_dir or (
            flatpak / "data/easyeffects/output" if flatpak.exists() else native / "output"
        ))
        self.config_path = Path(config_path or (
            flatpak / "config/easyeffects/db/easyeffectsrc"
            if flatpak.exists() else Path.home() / ".config/easyeffects/db/easyeffectsrc"
        ))
        self.route_state_path = Path(route_state_path or state_home / "angelos/eq-route.json")
        self.command_runner = command_runner or subprocess.run

    def _run(self, *args):
        try:
            result = self.command_runner(
                list(args), check=True, capture_output=True, text=True, timeout=3
            )
        except subprocess.CalledProcessError as exc:
            message = (exc.stderr or exc.stdout or "").strip()
            raise ValueError(message or f"Команда {args[0]} завершилась с ошибкой") from exc
        return result.stdout.strip()

    def _audio_snapshot(self):
        sinks = json.loads(self._run("pactl", "-f", "json", "list", "sinks"))
        streams = json.loads(self._run("pactl", "-f", "json", "list", "sink-inputs"))
        return sinks, streams

    def sources(self):
        sinks, streams = self._audio_snapshot()
        result = source_snapshot(sinks, streams)
        self._keep_output_target()
        result["route"] = self.route_view(sinks, streams)
        return result

    @staticmethod
    def _apps_in_ee(sinks, streams):
        sink_names = {str(item.get("index")): item.get("name", "") for item in sinks}
        apps = []
        for item in streams:
            name = (item.get("properties") or {}).get("application.name") or ""
            if (name and name not in IGNORED_APPLICATIONS and name not in apps
                    and sink_names.get(str(item.get("sink"))) == EE_SINK):
                apps.append(name)
        return apps

    def route_view(self, sinks=None, streams=None):
        """What the panel shows: the saved route, or an app that plays into EasyEffects
        without one (PipeWire put it back there after a restart)."""
        state = self._load_route_state()
        if state:
            return {"active": True, "app": state.get("app", ""), "output": state.get("output", "")}
        if sinks is None or streams is None:
            sinks, streams = self._audio_snapshot()
        apps = self._apps_in_ee(sinks, streams)
        if apps:
            return {"active": True, "app": apps[0],
                    "output": parse_ee_target(self._run("pw-link", "-l"))}
        return {"active": False, "app": "", "output": ""}

    def _keep_output_target(self):
        """EasyEffects links itself back to its own output device when its pipeline is
        rebuilt (a preset, a restart); put the routed channel back."""
        state = self._load_route_state()
        if not state or not state.get("output"):
            return
        try:
            current = parse_ee_target(self._run("pw-link", "-l"))
            if current and current != state["output"]:
                self._set_output_target(state["output"])
        except (OSError, subprocess.SubprocessError, ValueError):
            pass

    def _load_route_state(self):
        try:
            return json.loads(self.route_state_path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return None

    def _save_route_state(self, state):
        self.route_state_path.parent.mkdir(parents=True, exist_ok=True)
        temp_path = self.route_state_path.with_suffix(".tmp")
        temp_path.write_text(json.dumps(state, ensure_ascii=False), encoding="utf-8")
        temp_path.replace(self.route_state_path)

    def _clear_route_state(self):
        try:
            self.route_state_path.unlink()
        except FileNotFoundError:
            pass

    def _set_output_target(self, target, missing_ok=False):
        sinks, _ = self._audio_snapshot()
        if target == EE_SINK or target not in {sink.get("name") for sink in sinks}:
            if missing_ok:
                return
            raise ValueError("Выбранный выход сейчас недоступен")
        previous = self._wait_ee_target()
        if not previous:
            raise ValueError("EasyEffects не подключил свой выход — проверьте, что он запущен")
        if previous == target:
            return previous

        changed = []
        try:
            for channel in ("FL", "FR"):
                source = f"{EE_OUTPUT_NODE}:output_{channel}"
                old_port = f"{previous}:playback_{channel}"
                new_port = f"{target}:playback_{channel}"
                self._run("pw-link", "-d", source, old_port)
                self._run("pw-link", source, new_port)
                changed.append((source, old_port, new_port))
        except (OSError, subprocess.SubprocessError, ValueError):
            for source, old_port, new_port in reversed(changed):
                try:
                    self._run("pw-link", "-d", source, new_port)
                    self._run("pw-link", source, old_port)
                except (OSError, subprocess.SubprocessError, ValueError):
                    pass
            raise
        return previous

    def _wait_ee_target(self, seconds=2.0):
        """Where EasyEffects plays. With nothing playing into it its output is not linked
        at all; it links itself a moment after the first stream arrives."""
        deadline = time.monotonic() + seconds
        while True:
            target = parse_ee_target(self._run("pw-link", "-l"))
            if target or time.monotonic() >= deadline:
                return target
            time.sleep(0.1)

    def _move_input(self, stream_id, sink_name):
        self._run("pactl", "move-sink-input", str(stream_id), sink_name)

    def _restore_output_target(self, state):
        target = state.get("previous_output")
        if target:
            current = parse_ee_target(self._run("pw-link", "-l"))
            if current == state.get("output"):
                self._set_output_target(target, missing_ok=True)

    def release_route(self):
        state = self._load_route_state()
        sinks, live_inputs = self._audio_snapshot()
        sink_names = {str(item.get("index")): item.get("name", "") for item in sinks}
        if not state:
            # no record of where they came from: onto the channel they are heard on now
            target = parse_ee_target(self._run("pw-link", "-l"))
            apps = self._apps_in_ee(sinks, live_inputs)
            if apps and not target:
                raise ValueError("Не удалось определить текущий выход EasyEffects")
            for item in live_inputs:
                if ((item.get("properties") or {}).get("application.name") in apps
                        and sink_names.get(str(item.get("sink"))) == EE_SINK):
                    self._move_input(item["index"], target)
            return {"active": False, "app": "", "output": ""}

        failures = []
        saved_by_id = {str(saved.get("id")): saved for saved in state.get("streams", [])}
        home = self._home_sink(state)
        for current in live_inputs:
            if ((current.get("properties") or {}).get("application.name") != state.get("app")
                    or sink_names.get(str(current.get("sink"))) != EE_SINK):
                continue
            saved = saved_by_id.get(str(current.get("index")))
            # audio the app started later (or after a restart) goes where the rest came from
            target = saved["sink"] if saved and same_stream_identity(current, saved) else home
            if not target or target == EE_SINK:
                continue
            try:
                self._move_input(current["index"], target)
            except (OSError, subprocess.SubprocessError, ValueError) as exc:
                failures.append(str(exc))
        try:
            self._restore_output_target(state)
        except (OSError, subprocess.SubprocessError, ValueError) as exc:
            failures.append(str(exc))
        if failures:
            raise ValueError("Не удалось полностью вернуть исходную маршрутизацию: " + failures[0])
        self._clear_route_state()
        return {"active": False, "app": "", "output": ""}

    @staticmethod
    def _home_sink(state):
        sinks = [s.get("sink") for s in state.get("streams", []) if s.get("sink") not in ("", EE_SINK, None)]
        return max(set(sinks), key=sinks.count) if sinks else state.get("output", "")

    def route_application(self, app_name, output_name, direct=False):
        if not app_name or not output_name:
            raise ValueError("Выберите активное приложение и канал")
        sinks, inputs = self._audio_snapshot()
        sink_names = {str(item.get("index")): item.get("name", "") for item in sinks}
        app_inputs = [
            item for item in inputs
            if (item.get("properties") or {}).get("application.name") == app_name
        ]
        if not app_inputs:
            raise ValueError("Приложение уже не воспроизводит звук — обновите список")
        if output_name not in {item["name"] for item in output_choices(sinks)}:
            raise ValueError("Выбранный канал сейчас недоступен")

        previous_state = self._load_route_state()
        if previous_state and previous_state.get("app") != app_name:
            self.release_route()
            sinks, inputs = self._audio_snapshot()
            sink_names = {str(item.get("index")): item.get("name", "") for item in sinks}
            app_inputs = [
                item for item in inputs
                if (item.get("properties") or {}).get("application.name") == app_name
            ]
            if not app_inputs:
                raise ValueError("Приложение уже не воспроизводит звук — обновите список")

        app_ids = {str(item.get("index")) for item in app_inputs}
        other_ee_apps = sorted({
            (item.get("properties") or {}).get("application.name", "")
            for item in inputs
            if sink_names.get(str(item.get("sink"))) == EE_SINK
            and str(item.get("index")) not in app_ids
            and (item.get("properties") or {}).get("application.name") not in IGNORED_APPLICATIONS
        })
        if not direct and other_ee_apps:
            raise ValueError(
                "В EasyEffects уже есть другое приложение: " + ", ".join(other_ee_apps)
                + ". Сначала переведите его в DIRECT."
            )

        if direct:
            if previous_state and previous_state.get("app") != app_name:
                self.release_route()
                _, inputs = self._audio_snapshot()
                app_inputs = [
                    item for item in inputs
                    if (item.get("properties") or {}).get("application.name") == app_name
                ]
                if not app_inputs:
                    raise ValueError("Приложение уже не воспроизводит звук — обновите список")
            for item in app_inputs:
                self._move_input(item["index"], output_name)
            if previous_state and previous_state.get("app") == app_name:
                self._restore_output_target(previous_state)
                self._clear_route_state()
            return {"active": False, "app": app_name, "output": output_name}

        if previous_state and previous_state.get("app") == app_name:
            original_streams = list(previous_state.get("streams", []))
            saved_ids = {str(saved.get("id")) for saved in original_streams}
            for item in app_inputs:
                stream_id = str(item.get("index"))
                if stream_id in saved_ids:
                    continue
                sink_name = sink_names.get(str(item.get("sink")), "")
                if sink_name == EE_SINK:
                    # PipeWire sent the app's new audio straight into EasyEffects
                    sink_name = self._home_sink(previous_state)
                props = item.get("properties") or {}
                original_streams.append({
                    "id": stream_id,
                    "app": app_name,
                    "sink": sink_name,
                    "process": str(props.get("application.process.id") or ""),
                    "serial": str(props.get("object.serial") or ""),
                    "stream": str(props.get("media.name") or props.get("node.name") or ""),
                })
                saved_ids.add(stream_id)
            previous_output = previous_state.get("previous_output", "")
        else:
            original_streams = [
                {
                    "id": str(item["index"]),
                    "app": app_name,
                    # already in EasyEffects with no record (after a restart): the chosen
                    # channel is where it goes back to
                    "sink": (output_name if sink_names.get(str(item.get("sink"))) == EE_SINK
                             else sink_names.get(str(item.get("sink")), "")),
                    "process": str((item.get("properties") or {}).get("application.process.id") or ""),
                    "serial": str((item.get("properties") or {}).get("object.serial") or ""),
                    "stream": str(
                        (item.get("properties") or {}).get("media.name")
                        or (item.get("properties") or {}).get("node.name")
                        or ""
                    ),
                }
                for item in app_inputs
            ]
            # empty while nothing plays into EasyEffects: known once the app is in
            previous_output = parse_ee_target(self._run("pw-link", "-l"))

        moved = []
        output_changed = False
        try:
            for item in app_inputs:
                if sink_names.get(str(item.get("sink"))) != EE_SINK:
                    self._move_input(item["index"], EE_SINK)
                    moved.append(item)
            if not previous_output:
                # a cold EasyEffects takes a few seconds to build its chain and link it
                previous_output = self._wait_ee_target(6.0)
            if not previous_output:
                for channel in ("FL", "FR"):
                    self._run("pw-link", f"{EE_OUTPUT_NODE}:output_{channel}",
                              f"{output_name}:playback_{channel}")
            elif previous_output != output_name:
                self._set_output_target(output_name)
                output_changed = True
        except (OSError, subprocess.SubprocessError, ValueError):
            for item in reversed(moved):
                try:
                    self._move_input(item["index"], sink_names.get(str(item.get("sink")), ""))
                except (OSError, subprocess.SubprocessError, ValueError):
                    pass
            if output_changed:
                try:
                    self._set_output_target(previous_output)
                except (OSError, subprocess.SubprocessError, ValueError):
                    pass
            raise

        state = {
            "app": app_name,
            "streams": original_streams,
            "previous_output": previous_output,
            "output": output_name,
        }
        self._save_route_state(state)
        return {"active": True, "app": app_name, "output": output_name}

    def request(self, message, reply=False):
        with socket.socket(socket.AF_UNIX) as connection:
            connection.settimeout(0.8)
            for attempt in range(20):
                try:
                    connection.connect(str(self.socket_path))
                    break
                except BlockingIOError:
                    # its queue is full (a preset is some forty requests in a row)
                    if attempt == 19:
                        raise
                    time.sleep(0.02)
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
        parts = command.strip().split(maxsplit=1)
        action = parts[0] if parts else ""
        try:
            if not parts or action == "status":
                return self.state()
            if action == "sources" and len(parts) == 1:
                return self.sources()
            if action in ("route", "direct") and len(parts) == 2:
                payload = json.loads(parts[1])
                if not isinstance(payload, dict):
                    raise ValueError("Некорректные параметры маршрутизации")
                return {
                    "route": self.route_application(
                        str(payload.get("app") or ""),
                        str(payload.get("output") or ""),
                        direct=action == "direct",
                    ),
                    "error": "",
                }
            if action == "release" and len(parts) == 1:
                return {"route": self.release_route(), "error": ""}
            if action == "start" and len(parts) == 1:
                return self.start()
            args = parts[1].split() if len(parts) == 2 else []
            if action == "set" and len(args) == 2:
                index = int(args[0])
                gain = float(args[1])
                if index not in range(10) or not math.isfinite(gain) or not -12 <= gain <= 12:
                    raise ValueError("Полоса: 0–9; усиление: −12…+12 dB")
                if not self.state()["ready"]:
                    return self.state()
                for channel in ("left", "right"):
                    self.set(f"band{index}Gain", gain, channel)
                self._headroom()
                return self.state()
            if action == "preset" and len(args) == 1:
                levels = PRESETS.get(args[0])
                if levels is None:
                    raise ValueError("Неизвестный пресет")
                if not self.state()["ready"]:
                    return self.state()
                for index, gain in enumerate(levels):
                    for channel in ("left", "right"):
                        self.set(f"band{index}Gain", gain, channel)
                self._headroom()
                return self.state()
            if action == "toggle" and len(parts) == 1:
                state = self.state()
                if not state["ready"]:
                    return state
                self.set("bypass", str(state["enabled"]).lower())
                return self.state()
            raise ValueError("Неизвестная команда EQ")
        except (OSError, ValueError, TimeoutError) as exc:
            result = self.state(str(exc))
            try:
                result["route"] = self.route_view()
            except (OSError, subprocess.SubprocessError, ValueError):
                pass
            return result

    def _headroom(self):
        gains = [float(self.get(f"band{i}Gain", "left")) for i in range(10)]
        self.set("outputGain", round(-HEADROOM_SHARE * max(0, *gains), 2))


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
