#!/usr/bin/env python3
"""Stand-ins for the equalizer test (tests/eq/run.sh): pactl, pw-link and EasyEffects' socket.

  audio.py pactl …      sinks, streams and move-sink-input over $FAKE_EQ_DIR/audio.json
  audio.py pw-link …    where "EasyEffects" plays, from the same file
  audio.py server SOCK  get_property / set_property of an output equalizer; every value
                        that was set is kept in $FAKE_EQ_DIR/ee.json
"""
import json
import os
from pathlib import Path
import socket
import sys

DIR = Path(os.environ["FAKE_EQ_DIR"])
AUDIO = DIR / "audio.json"
FREQUENCIES = (31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000)


def load():
    return json.loads(AUDIO.read_text())


def save(state):
    tmp = AUDIO.with_suffix(".tmp")
    tmp.write_text(json.dumps(state))
    tmp.replace(AUDIO)


def pactl(args):
    state = load()
    index = {name: i + 1 for i, name in enumerate(state["sinks"])}
    if args == ["-f", "json", "list", "sinks"]:
        print(json.dumps([{"index": i, "name": name, "description": name} for name, i in index.items()]))
    elif args == ["-f", "json", "list", "sink-inputs"]:
        print(json.dumps([
            {"index": s["index"], "sink": index[s["sink"]], "properties": {"application.name": s["app"]}}
            for s in state["streams"]
        ]))
    elif args[:1] == ["move-sink-input"]:
        for s in state["streams"]:
            if str(s["index"]) == args[1]:
                s["sink"] = args[2]
        save(state)
    else:
        sys.exit("fake pactl: " + " ".join(args))


def pw_link(args):
    state = load()
    if args == ["-l"]:
        # as the real one: its output is linked only while something plays into it
        if not any(s["sink"] == "easyeffects_sink" for s in state["streams"]):
            return
        for channel in ("FL", "FR"):
            print(f"{state['output']}:playback_{channel}\n  |<- ee_soe_output_level:output_{channel}")
    elif args[:1] == ["-d"]:
        pass
    else:
        state["output"] = args[1].split(":", 1)[0]
        save(state)


def server(path):
    values = {"numBands": "10", "bypass": "false", "outputGain": "0"}
    for i, freq in enumerate(FREQUENCIES):
        for channel in ("left", "right"):
            values[f"{channel}:band{i}Gain"] = "0"
            values[f"{channel}:band{i}Frequency"] = str(freq)
    listener = socket.socket(socket.AF_UNIX)
    listener.bind(path)
    listener.listen(16)
    while True:
        connection, _ = listener.accept()
        with connection:
            line = connection.makefile().readline().strip()
            verb, _, rest = line.partition(":output:equalizer:0:")
            if verb == "get_property":
                connection.sendall((values.get(rest, "error_property_not_found") + "\n").encode())
            elif verb == "set_property":
                name, _, value = rest.rpartition(":")
                values[name] = value
                (DIR / "ee.json").write_text(json.dumps(values))


if __name__ == "__main__":
    {"pactl": pactl, "pw-link": pw_link, "server": lambda a: server(a[0])}[sys.argv[1]](sys.argv[2:])
