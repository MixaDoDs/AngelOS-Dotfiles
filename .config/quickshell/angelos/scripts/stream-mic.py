#!/usr/bin/env python3
"""The streamer's voice for the angel on stream (services/StreamAngel.qml).

  stream-mic.py [--port 4455] [--password PW] [--mic auto|obs:<input>|pw:<source>] [--always] [--with-obs]

OBS first (obs-websocket 5, the same socket as scripts/obs-watch.py): the level of the
mic input as OBS itself hears it — after its volume slider, nothing while it is muted in
OBS. The mic is the input picked in Settings, or found by its name and device ("Mic/Aux",
"rec", a USB microphone, a RØDECaster's fader 1 — never the desktop audio, a whole stream
mix, a game or chat). Without OBS, or with no mic input in it: the PipeWire source itself
(pw-record), the picked one or the likeliest microphone.

Prints one JSON object per line:
  {"obs": true|false, "live": true|false}       OBS connected / streaming
  {"inputs": [{"name", "kind", "device", "score"}], "using": "obs:Mic/Aux"}
  {"level": 0.0…1.0, "db": -38.5}               the voice, up to 25 times a second, while
                                                live (or always, with --always; while OBS
                                                runs, with --with-obs)
  {"error": "..."}
The level maps -55 dBFS → 0 and -12 dBFS → 1; QML decides what is talking.
"""
import argparse
import importlib.util
import json
import math
import os
import re
import select
import shutil
import struct
import subprocess
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("obs_watch", os.path.join(HERE, "obs-watch.py"))
obs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(obs)

OUTPUTS = 1 << 6
INPUTS = 1 << 3
METERS = 1 << 16
LOW_DB, HIGH_DB = -55.0, -12.0
AUDIO_IN = ("pulse_input_capture", "pipewire_audio_input_capture", "pipewire-audio-capture-input",
            "alsa_input_capture", "jack_input_client", "wasapi_input_capture", "coreaudio_input_capture",
            "sndio_input_capture", "oss_input_capture")

GOOD = re.compile(r"mic|микро|мик\b|voice|голос|vocal|вокал|\brec\b|запис|headset|гарнитур|fader1(?!\d)|"
                  r"microphone|yeti|shure|fifine|hyperx|blue|rode.?(nt|pod|wireless)|volt|focusrite|scarlett|xlr", re.I)
BAD = re.compile(r"monitor|desktop|system|звук рабоч|stream|стрим|chat|чат|discord|game|игр|music|музык|"
                 r"spotify|browser|браузер|vfader|mix\b|микс|output|sink|loopback|easyeffects_sink|liv\b", re.I)


_out = threading.Lock()


def say(obj):
    with _out:
        sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
        sys.stdout.flush()


def score(name, device, special=False):
    s = 0
    s += 3 if GOOD.search(name or "") else 0
    s += 2 if GOOD.search(device or "") else 0
    s -= 4 if BAD.search(name or "") else 0
    s -= 3 if BAD.search(device or "") else 0
    s += 1 if special else 0
    return s


def norm(db):
    return max(0.0, min(1.0, (db - LOW_DB) / (HIGH_DB - LOW_DB)))


class Level:
    """Fast up, a little slower down, printed only when it moves."""

    def __init__(self):
        self.value = 0.0
        self.sent = -1.0
        self.at = 0.0

    def feed(self, db):
        v = norm(db)
        self.value = v if v > self.value else self.value * 0.55 + v * 0.45
        now = time.monotonic()
        if (abs(self.value - self.sent) >= 0.03 or (self.value == 0 and self.sent != 0)) and now - self.at >= 0.04:
            self.sent, self.at = round(self.value, 3), now
            say({"level": self.sent, "db": round(db, 1)})


# ---------------------------------------------------------------- OBS
def request(ws, kind, data=None, rid=None):
    ws.send({"op": 6, "d": {"requestType": kind, "requestId": rid or kind, "requestData": data or {}}})


def obs_session(args, password, pw):
    ws = obs.Socket(args.port)
    hello = ws.recv()
    subs = OUTPUTS | INPUTS
    ident = {"rpcVersion": 1, "eventSubscriptions": subs}
    auth = (hello.get("d") or {}).get("authentication")
    if auth:
        if not password:
            say({"error": "obs-auth"})
            return
        import base64
        import hashlib
        secret = base64.b64encode(hashlib.sha256((password + auth["salt"]).encode()).digest())
        ident["authentication"] = base64.b64encode(hashlib.sha256(secret + auth["challenge"].encode()).digest()).decode()
    ws.send({"op": 1, "d": ident})
    say({"obs": True, "live": False})
    request(ws, "GetStreamStatus")
    request(ws, "GetSpecialInputs")
    request(ws, "GetInputList")
    specials, inputs, devices, muted = set(), [], {}, set()
    pending_settings = 0
    chosen = None
    metering = False
    level = Level()
    live = False

    def pick():
        nonlocal chosen, picked
        rows = []
        for i in inputs:
            name = i["inputName"]
            rows.append({"name": name, "kind": i.get("unversionedInputKind") or i.get("inputKind"),
                         "device": devices.get(name, ""), "score": score(name, devices.get(name, ""), name in specials)})
        want = args.mic[4:] if args.mic.startswith("obs:") else ""
        found = next((r for r in rows if r["name"] == want), None) if want else None
        if not found and not args.mic.startswith("pw:"):
            good = sorted((r for r in rows if r["score"] > 0), key=lambda r: -r["score"])
            found = good[0] if good else None
        chosen = found["name"] if found else None
        picked = True
        if chosen:
            say({"inputs": rows, "using": "obs:" + chosen})
        else:
            pw.rows_obs = rows

    def meter(on):
        nonlocal metering
        if on != metering:
            metering = on
            ws.send({"op": 3, "d": {"eventSubscriptions": subs | (METERS if on else 0)}})
            if not on:
                level.feed(-100)

    picked = False
    while True:
        hear = live or args.always or args.with_obs
        meter(bool(chosen) and hear)
        # no mic among OBS's inputs (or a PipeWire source picked): the source itself
        pw.want(picked and not chosen and hear)
        if not ws.pending(30):
            continue
        msg = ws.recv()
        op, d = msg.get("op"), msg.get("d") or {}
        if op == 7:
            rid, data = d.get("requestId", ""), d.get("responseData") or {}
            if rid == "GetStreamStatus":
                live = bool(data.get("outputActive"))
                say({"obs": True, "live": live})
            elif rid == "GetSpecialInputs":
                specials = {v for k, v in data.items() if k.startswith("mic") and v}
            elif rid == "GetInputList":
                inputs = [i for i in data.get("inputs", []) if (i.get("unversionedInputKind") or i.get("inputKind") or "") in AUDIO_IN]
                pending_settings = len(inputs)
                for i in inputs:
                    request(ws, "GetInputSettings", {"inputName": i["inputName"]}, "set:" + i["inputName"])
                    request(ws, "GetInputMute", {"inputName": i["inputName"]}, "mute:" + i["inputName"])
                if not inputs:
                    pick()
            elif rid.startswith("set:"):
                s = data.get("inputSettings") or {}
                devices[rid[4:]] = str(s.get("device_id") or s.get("TargetId") or s.get("device") or "")
                pending_settings -= 1
                if pending_settings <= 0:
                    pick()
            elif rid.startswith("mute:"):
                (muted.add if data.get("inputMuted") else muted.discard)(rid[5:])
        elif op == 5:
            kind, data = d.get("eventType"), d.get("eventData") or {}
            if kind == "StreamStateChanged":
                now_live = bool(data.get("outputActive"))
                if now_live != live:
                    live = now_live
                    say({"obs": True, "live": live})
            elif kind == "InputMuteStateChanged":
                (muted.add if data.get("inputMuted") else muted.discard)(data.get("inputName"))
            elif kind in ("InputCreated", "InputRemoved", "InputNameChanged", "InputSettingsChanged"):
                devices.clear()
                request(ws, "GetInputList")
            elif kind == "InputVolumeMeters" and chosen:
                db = -100.0
                if chosen not in muted:
                    for i in data.get("inputs", []):
                        if i.get("inputName") == chosen:
                            # per channel [magnitude, peak, input peak] as multipliers, after the slider
                            peaks = [c[1] for c in i.get("inputLevelsMul") or [] if len(c) > 1]
                            m = max(peaks) if peaks else 0
                            db = 20 * math.log10(m) if m > 0 else -100.0
                level.feed(db)


# ---------------------------------------------------------------- PipeWire
def pw_sources():
    try:
        out = subprocess.run(["pactl", "-f", "json", "list", "sources"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=4).stdout
        rows = json.loads(out or "[]")
    except (OSError, ValueError, subprocess.SubprocessError):
        return []
    res = []
    for r in rows:
        name = r.get("name", "")
        if name.endswith(".monitor") or (r.get("monitor_source") and name.endswith("monitor")):
            continue
        desc = r.get("description", "")
        res.append({"name": name, "kind": "pipewire", "device": desc, "score": score(desc, name)})
    return res


class PwMeter:
    """pw-record on the mic source, in a thread, while wanted."""

    def __init__(self, args):
        self.args = args
        self.proc = None
        self.thread = None
        self.on = False
        self.rows_obs = []

    def want(self, on):
        if on and not self.on:
            self.on = True
            self.thread = threading.Thread(target=self.run, daemon=True)
            self.thread.start()
        elif not on and self.on:
            self.on = False
            if self.proc:
                self.proc.kill()

    def run(self):
        while self.on:
            if not self.capture():
                for _ in range(20):
                    if not self.on:
                        return
                    time.sleep(0.5)

    def capture(self):
        rows = pw_sources()
        want = self.args.mic[3:] if self.args.mic.startswith("pw:") else ""
        found = next((r for r in rows if r["name"] == want), None) if want else None
        if not found:
            good = sorted((r for r in rows if r["score"] > 0), key=lambda r: -r["score"])
            found = good[0] if good else None
        if not found:
            try:
                default = subprocess.run(["pactl", "get-default-source"], capture_output=True, text=True, timeout=3).stdout.strip()
            except (OSError, subprocess.SubprocessError):
                default = ""
            found = next((r for r in rows if r["name"] == default), None)
        say({"inputs": self.rows_obs + rows, "using": ("pw:" + found["name"]) if found else ""})
        if not found or not shutil.which("pw-record"):
            say({"error": "no-mic" if not found else "pw-record missing"})
            return False
        rate, block = 16000, 640  # 40 ms
        props = '{ node.name = angelos_stream_mic node.description = "angelOS angel on stream" node.dont-reconnect = true }'
        self.proc = proc = subprocess.Popen(["pw-record", "--raw", "--target", found["name"], "--channels", "1", "--format", "f32",
                                             "--rate", str(rate), "--latency", "40ms", "-P", props, "-"],
                                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
        level = Level()
        buf = b""
        try:
            while self.on:
                if not select.select([proc.stdout], [], [], 2)[0]:
                    if proc.poll() is not None:
                        break
                    level.feed(-100)
                    continue
                chunk = proc.stdout.read(block * 4)
                if not chunk:
                    break
                buf += chunk
                while len(buf) >= block * 4:
                    samples = struct.unpack("<%df" % block, buf[:block * 4])
                    buf = buf[block * 4:]
                    rms = math.sqrt(sum(x * x for x in samples) / block)
                    # rms runs ~3 dB under a peak meter: bring it level with OBS's numbers
                    level.feed(20 * math.log10(rms) + 3 if rms > 0 else -100.0)
        finally:
            proc.kill()
            proc.wait()
            level.feed(-100)
        return self.on


def main():
    try:  # go away together with the shell
        import ctypes
        import signal
        ctypes.CDLL(None).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except (OSError, AttributeError):
        pass
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=4455)
    ap.add_argument("--password", default=None)
    ap.add_argument("--mic", default="auto")
    ap.add_argument("--always", action="store_true", help="meter while not live too (the preview)")
    ap.add_argument("--with-obs", action="store_true", help="meter while OBS runs, live or not (her window for OBS)")
    args = ap.parse_args()
    pw = PwMeter(args)
    while True:
        password = args.password if args.password is not None else obs.config_password()
        try:
            obs_session(args, password, pw)
        except (OSError, ConnectionError, ValueError):
            pass
        say({"obs": False, "live": False})
        # no OBS: the preview still hears the mic itself
        pw.rows_obs = []
        pw.want(args.always)
        time.sleep(10)

if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
