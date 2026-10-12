import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace


BRIDGE_PATH = Path(__file__).parents[1] / "scripts" / "eq-bridge.py"
SPEC = importlib.util.spec_from_file_location("eq_bridge", BRIDGE_PATH)
eq_bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(eq_bridge)


class EqRoutingTests(unittest.TestCase):
    def test_source_snapshot_lists_application_and_only_rodecaster_channels(self):
        sinks = [
            {"index": 9, "name": "rcp_duo_game_in", "description": "Game"},
            {"index": 10, "name": "rcp_duo_music_in", "description": "Music"},
            {"index": 11, "name": "rcp_duo_system_in", "description": "System"},
            {"index": 14, "name": "rcp_duo_chat_in", "description": "Chat"},
            {"index": 12, "name": "alsa_output.headphones", "description": "Headphones"},
            {"index": 13, "name": "easyeffects_sink", "description": "Easy Effects Sink"},
        ]
        inputs = [
            {
                "index": 444,
                "sink": 10,
                "properties": {"application.name": "Spotify", "media.name": "Spotify"},
            },
            {
                "index": 555,
                "sink": 11,
                "properties": {"application.name": "Helium", "media.name": "Video tab"},
            },
            {
                "index": 666,
                "sink": 13,
                "properties": {"application.name": "angelos-sfx", "media.name": "UI sounds"},
            },
        ]

        result = eq_bridge.source_snapshot(sinks, inputs)

        self.assertEqual(result["apps"], [
            {
                "id": "Helium",
                "app": "Helium",
                "streams": [{
                    "id": "555",
                    "name": "Video tab",
                    "sink": "rcp_duo_system_in",
                    "process": "",
                    "serial": "",
                }],
                "sinks": ["rcp_duo_system_in"],
            },
            {
                "id": "Spotify",
                "app": "Spotify",
                "streams": [{
                    "id": "444",
                    "name": "Spotify",
                    "sink": "rcp_duo_music_in",
                    "process": "",
                    "serial": "",
                }],
                "sinks": ["rcp_duo_music_in"],
            },
        ])
        self.assertEqual([item["name"] for item in result["outputs"]], [
            "rcp_duo_game_in", "rcp_duo_system_in", "rcp_duo_chat_in", "rcp_duo_music_in"
        ])

    def test_parse_ee_target_finds_current_stereo_destination(self):
        links = """\
rcp_duo_system_in:playback_FL
  |<- ee_soe_output_level:output_FL
rcp_duo_system_in:playback_FR
  |<- ee_soe_output_level:output_FR
"""

        self.assertEqual(eq_bridge.parse_ee_target(links), "rcp_duo_system_in")

    def test_parse_ee_target_returns_empty_when_pipeline_is_not_connected(self):
        self.assertEqual(
            eq_bridge.parse_ee_target(
                "spotify:output_FL\n  |-> rcp_duo_music_in:playback_FL\n"
            ),
            "",
        )

    def test_saved_stream_identity_rejects_reused_object_serial(self):
        saved = {
            "app": "Spotify",
            "process": "700",
            "serial": "9001",
            "stream": "Spotify",
        }
        current = {
            "properties": {
                "application.name": "Spotify",
                "application.process.id": "700",
                "object.serial": "9002",
                "media.name": "Spotify",
            }
        }

        self.assertFalse(eq_bridge.same_stream_identity(current, saved))

    def test_route_moves_only_selected_app_and_release_restores_both_routes(self):
        class Audio:
            def __init__(self):
                self.sinks = [
                    {"index": 9, "name": "rcp_duo_game_in", "description": "Game"},
                    {"index": 10, "name": "rcp_duo_music_in", "description": "Music"},
                    {"index": 11, "name": "rcp_duo_system_in", "description": "System"},
                    {"index": 13, "name": "easyeffects_sink", "description": "Easy Effects Sink"},
                ]
                self.streams = [
                    {"index": 444, "sink": 10, "properties": {"application.name": "Spotify"}},
                    {"index": 555, "sink": 11, "properties": {"application.name": "Helium"}},
                ]
                self.output = "rcp_duo_system_in"
                self.moves = []

            def run(self, args, **_kwargs):
                if args[:5] == ["pactl", "-f", "json", "list", "sinks"]:
                    return SimpleNamespace(stdout=json.dumps(self.sinks))
                if args[:5] == ["pactl", "-f", "json", "list", "sink-inputs"]:
                    return SimpleNamespace(stdout=json.dumps(self.streams))
                if args[:2] == ["pactl", "move-sink-input"]:
                    stream_id, sink_name = args[2:]
                    stream = next(item for item in self.streams if str(item["index"]) == stream_id)
                    stream["sink"] = next(item["index"] for item in self.sinks if item["name"] == sink_name)
                    self.moves.append((stream_id, sink_name))
                    return SimpleNamespace(stdout="")
                if args == ["pw-link", "-l"]:
                    return SimpleNamespace(stdout=(
                        f"{self.output}:playback_FL\n  |<- ee_soe_output_level:output_FL\n"
                        f"{self.output}:playback_FR\n  |<- ee_soe_output_level:output_FR\n"
                    ))
                if args[:2] == ["pw-link", "-d"]:
                    return SimpleNamespace(stdout="")
                if args[0] == "pw-link":
                    self.output = args[2].split(":", 1)[0]
                    return SimpleNamespace(stdout="")
                raise AssertionError(args)

        audio = Audio()
        with tempfile.TemporaryDirectory() as temp_dir:
            bridge = eq_bridge.EqBridge(
                route_state_path=Path(temp_dir) / "route.json",
                command_runner=audio.run,
            )

            result = bridge.route_application("Spotify", "rcp_duo_music_in")
            self.assertEqual(result, {
                "active": True, "app": "Spotify", "output": "rcp_duo_music_in"
            })
            self.assertEqual(audio.moves, [("444", "easyeffects_sink")])

            audio.streams.append({
                "index": 445,
                "sink": 11,
                "properties": {"application.name": "Spotify"},
            })
            bridge.route_application("Spotify", "rcp_duo_game_in")
            self.assertEqual(audio.moves[-1], ("445", "easyeffects_sink"))

            bridge.release_route()
            self.assertEqual(audio.moves[-2:], [
                ("444", "rcp_duo_music_in"),
                ("445", "rcp_duo_system_in"),
            ])
            self.assertEqual(audio.output, "rcp_duo_system_in")

    def test_route_rejects_reused_stream_id_with_different_application(self):
        class Audio:
            def __init__(self):
                self.moves = []

            def run(self, args, **_kwargs):
                if args[:5] == ["pactl", "-f", "json", "list", "sinks"]:
                    return SimpleNamespace(stdout=json.dumps([
                        {"index": 1, "name": "rcp_duo_music_in", "description": "Music"},
                    ]))
                if args[:5] == ["pactl", "-f", "json", "list", "sink-inputs"]:
                    return SimpleNamespace(stdout=json.dumps([
                        {"index": 444, "sink": 1, "properties": {"application.name": "OtherApp"}},
                    ]))
                self.moves.append(args)
                return SimpleNamespace(stdout="")

        audio = Audio()
        with tempfile.TemporaryDirectory() as temp_dir:
            bridge = eq_bridge.EqBridge(
                route_state_path=Path(temp_dir) / "route.json",
                command_runner=audio.run,
            )
            with self.assertRaisesRegex(ValueError, "уже не воспроизводит"):
                bridge.route_application("Spotify", "rcp_duo_music_in")
        self.assertEqual(audio.moves, [])

    def test_route_refuses_to_capture_an_app_while_another_app_is_in_ee(self):
        class Audio:
            def __init__(self):
                self.moves = []
                self.sinks = [
                    {"index": 10, "name": "rcp_duo_music_in"},
                    {"index": 11, "name": "easyeffects_sink"},
                ]
                self.streams = [
                    {"index": 444, "sink": 10, "properties": {"application.name": "Spotify"}},
                    {"index": 555, "sink": 11, "properties": {"application.name": "Helium"}},
                ]

            def run(self, args, **_kwargs):
                if args[:5] == ["pactl", "-f", "json", "list", "sinks"]:
                    return SimpleNamespace(stdout=json.dumps(self.sinks))
                if args[:5] == ["pactl", "-f", "json", "list", "sink-inputs"]:
                    return SimpleNamespace(stdout=json.dumps(self.streams))
                self.moves.append(args)
                return SimpleNamespace(stdout="")

        audio = Audio()
        with tempfile.TemporaryDirectory() as temp_dir:
            bridge = eq_bridge.EqBridge(
                route_state_path=Path(temp_dir) / "route.json",
                command_runner=audio.run,
            )
            with self.assertRaisesRegex(ValueError, "другое приложение: Helium"):
                bridge.route_application("Spotify", "rcp_duo_music_in")
        self.assertEqual(audio.moves, [])

    def test_direct_action_can_move_an_existing_app_out_of_ee(self):
        class Audio:
            def __init__(self):
                self.sinks = [
                    {"index": 10, "name": "rcp_duo_music_in"},
                    {"index": 11, "name": "easyeffects_sink"},
                ]
                self.streams = [
                    {"index": 444, "sink": 11, "properties": {"application.name": "Helium"}},
                ]
                self.moves = []

            def run(self, args, **_kwargs):
                if args[:5] == ["pactl", "-f", "json", "list", "sinks"]:
                    return SimpleNamespace(stdout=json.dumps(self.sinks))
                if args[:5] == ["pactl", "-f", "json", "list", "sink-inputs"]:
                    return SimpleNamespace(stdout=json.dumps(self.streams))
                if args[:2] == ["pactl", "move-sink-input"]:
                    stream_id, sink_name = args[2:]
                    self.moves.append((stream_id, sink_name))
                    return SimpleNamespace(stdout="")
                raise AssertionError(args)

        audio = Audio()
        with tempfile.TemporaryDirectory() as temp_dir:
            bridge = eq_bridge.EqBridge(
                route_state_path=Path(temp_dir) / "route.json",
                command_runner=audio.run,
            )
            result = bridge.route_application("Helium", "rcp_duo_music_in", direct=True)
        self.assertEqual(result, {
            "active": False, "app": "Helium", "output": "rcp_duo_music_in"
        })
        self.assertEqual(audio.moves, [("444", "rcp_duo_music_in")])


class FakeAudio:
    """pactl and pw-link over a small graph: sinks, streams and where EasyEffects plays."""

    def __init__(self, sinks, streams, output):
        self.sinks = [{"index": i + 1, "name": name} for i, name in enumerate(sinks)]
        self.streams = [
            {"index": index, "sink": self.index_of(sink), "properties": {"application.name": app}}
            for index, app, sink in streams
        ]
        self.output = output
        self.device = "rcp_duo_system_in"  # EasyEffects' own output device
        self.moves = []

    def index_of(self, name):
        return next(item["index"] for item in self.sinks if item["name"] == name)

    def run(self, args, **_kwargs):
        if args[:5] == ["pactl", "-f", "json", "list", "sinks"]:
            return SimpleNamespace(stdout=json.dumps(self.sinks))
        if args[:5] == ["pactl", "-f", "json", "list", "sink-inputs"]:
            return SimpleNamespace(stdout=json.dumps(self.streams))
        if args[:2] == ["pactl", "move-sink-input"]:
            stream = next(item for item in self.streams if str(item["index"]) == args[2])
            stream["sink"] = self.index_of(args[3])
            self.moves.append((args[2], args[3]))
            return SimpleNamespace(stdout="")
        if args == ["pw-link", "-l"]:
            # as the real one: its output is linked only while something plays into it
            if not any(item["sink"] == self.index_of("easyeffects_sink") for item in self.streams):
                self.output = ""
                return SimpleNamespace(stdout="")
            self.output = self.output or self.device
            return SimpleNamespace(stdout=(
                f"{self.output}:playback_FL\n  |<- ee_soe_output_level:output_FL\n"
                f"{self.output}:playback_FR\n  |<- ee_soe_output_level:output_FR\n"
            ))
        if args[:2] == ["pw-link", "-d"]:
            return SimpleNamespace(stdout="")
        if args[0] == "pw-link":
            self.output = args[2].split(":", 1)[0]
            return SimpleNamespace(stdout="")
        raise AssertionError(args)


class EqColdStartTests(unittest.TestCase):
    """Nothing plays into EasyEffects yet, so its output is not linked anywhere."""

    def test_route_waits_for_easyeffects_to_link_and_release_puts_everything_back(self):
        audio = FakeAudio(["rcp_duo_system_in", "rcp_duo_music_in", "easyeffects_sink"],
                          [(7, "Spotify", "rcp_duo_music_in")], "")
        with tempfile.TemporaryDirectory() as temp_dir:
            bridge = eq_bridge.EqBridge(route_state_path=Path(temp_dir) / "route.json",
                                        command_runner=audio.run)
            result = bridge.route_application("Spotify", "rcp_duo_music_in")
            self.assertEqual(result, {"active": True, "app": "Spotify", "output": "rcp_duo_music_in"})
            self.assertEqual(audio.moves, [("7", "easyeffects_sink")])
            self.assertEqual(audio.output, "rcp_duo_music_in")
            bridge.release_route()
        self.assertEqual(audio.moves[-1], ("7", "rcp_duo_music_in"))


class EqOrphanTests(unittest.TestCase):
    """An app PipeWire put back into EasyEffects after a restart, with no saved route."""

    def bridge(self, audio, temp_dir):
        return eq_bridge.EqBridge(route_state_path=Path(temp_dir) / "route.json",
                                  command_runner=audio.run)

    def test_sources_show_an_app_that_already_plays_into_easyeffects(self):
        audio = FakeAudio(["rcp_duo_system_in", "easyeffects_sink"],
                          [(7, "Helium", "easyeffects_sink")], "rcp_duo_system_in")
        with tempfile.TemporaryDirectory() as temp_dir:
            route = self.bridge(audio, temp_dir).sources()["route"]
        self.assertEqual(route, {"active": True, "app": "Helium", "output": "rcp_duo_system_in"})

    def test_route_adopts_it_and_release_returns_it_to_the_chosen_channel(self):
        audio = FakeAudio(["rcp_duo_system_in", "rcp_duo_music_in", "easyeffects_sink"],
                          [(7, "Helium", "easyeffects_sink")], "rcp_duo_system_in")
        with tempfile.TemporaryDirectory() as temp_dir:
            bridge = self.bridge(audio, temp_dir)
            result = bridge.route_application("Helium", "rcp_duo_music_in")
            self.assertEqual(result, {"active": True, "app": "Helium", "output": "rcp_duo_music_in"})
            self.assertEqual(audio.moves, [])
            self.assertEqual(audio.output, "rcp_duo_music_in")
            self.assertTrue(bridge.sources()["route"]["active"])

            # audio the app starts later lands in EasyEffects by itself and leaves with the rest
            audio.streams.append({"index": 8, "sink": audio.index_of("easyeffects_sink"),
                                  "properties": {"application.name": "Helium"}})
            bridge.release_route()
            self.assertEqual(audio.moves, [("7", "rcp_duo_music_in"), ("8", "rcp_duo_music_in")])
            # left empty, EasyEffects is unlinked or back on its own device
            self.assertIn(audio.output, ("", "rcp_duo_system_in"))
            self.assertFalse(bridge.sources()["route"]["active"])

    def test_release_without_a_record_moves_it_to_the_channel_it_is_heard_on(self):
        audio = FakeAudio(["rcp_duo_system_in", "easyeffects_sink"],
                          [(7, "Helium", "easyeffects_sink")], "rcp_duo_system_in")
        with tempfile.TemporaryDirectory() as temp_dir:
            self.bridge(audio, temp_dir).release_route()
        self.assertEqual(audio.moves, [("7", "rcp_duo_system_in")])

    def test_sources_put_the_routed_channel_back_when_easyeffects_relinks(self):
        audio = FakeAudio(["rcp_duo_system_in", "rcp_duo_music_in", "easyeffects_sink"],
                          [(7, "Spotify", "rcp_duo_music_in")], "rcp_duo_system_in")
        with tempfile.TemporaryDirectory() as temp_dir:
            bridge = self.bridge(audio, temp_dir)
            bridge.route_application("Spotify", "rcp_duo_music_in")
            audio.output = "rcp_duo_system_in"  # EasyEffects rebuilt its pipeline
            bridge.sources()
        self.assertEqual(audio.output, "rcp_duo_music_in")


class EqOutputTests(unittest.TestCase):
    def test_without_a_rodecaster_every_other_output_can_be_chosen(self):
        sinks = [
            {"index": 1, "name": "alsa_output.pci.analog-stereo", "description": "Speakers"},
            {"index": 2, "name": "easyeffects_sink", "description": "Easy Effects Sink"},
        ]
        snapshot = eq_bridge.source_snapshot(sinks, [])
        self.assertEqual(snapshot["outputs"],
                         [{"name": "alsa_output.pci.analog-stereo", "label": "Speakers"}])
        self.assertFalse(snapshot["rode"])

    def test_a_recorder_on_the_easyeffects_node_is_not_its_output(self):
        links = (
            "rcp_duo_system_in:playback_FL\n  |<- ee_soe_output_level:output_FL\n"
            "angelos-cava:input_FL\n  |<- ee_soe_output_level:output_FL\n"
        )
        self.assertEqual(eq_bridge.parse_ee_target(links), "rcp_duo_system_in")

    def test_headroom_takes_back_half_of_the_largest_boost(self):
        bridge = eq_bridge.EqBridge(route_state_path="/nonexistent/route.json")
        sent = {}
        bridge.get = lambda name, channel=None: {"band3Gain": "6.0"}.get(name, "-2.0")
        bridge.set = lambda name, value, channel=None: sent.update({name: value})
        bridge._headroom()
        self.assertEqual(sent, {"outputGain": -3.0})


if __name__ == "__main__":
    unittest.main()
