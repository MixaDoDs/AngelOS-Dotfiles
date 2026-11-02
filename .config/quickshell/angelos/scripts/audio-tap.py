#!/usr/bin/env python3
"""angelOS audio tap: what the cava widget listens to.

  audio-tap.py list
      JSON with every output (sink monitor) and input, their channels and
      labelled channel pairs (multichannel interfaces such as the RØDECaster).
  audio-tap.py run --conf CONF --fifo FIFO [--rate HZ] [SPEC]
      Keeps `pw-record → (channel mix) → FIFO → cava -p CONF` running; cava's
      output goes to our stdout. CONF must use `method = fifo`, `source = FIFO`
      and `sample_rate` = HZ (22050 by default; 44100 to hear above 11 kHz).

SPEC
  "" | auto                 everything the computer plays: the default output; when
                            that is a virtual sink feeding a multichannel interface,
                            all channels of the interface are summed instead
  monitor:<sink>            what plays on an output
  all:<node>                every channel of a node summed to stereo
  pair:<node>:<CH>,<CH>     one channel pair, e.g. pair:<rode>:AUX4,AUX5
  input:<source>            a recording device (microphone!)
  <node name>               older settings: an output's monitor

Read-only: it only records. Outputs are captured with stream.capture.sink, and the
stream never falls back to another node (so a vanished output can't turn into the
microphone, which is what cava's own `source = <sink>` did).
"""
import errno
import json
import os
import select
import shutil
import signal
import stat
import subprocess
import sys
import time

RATE = 22050
try:
    import numpy as np
except ImportError:  # plain array fallback, fine at 22 kHz
    np = None
    from array import array


def pw_dump():
    try:
        out = subprocess.run(["pw-dump"], capture_output=True, text=True, timeout=5).stdout
        return json.loads(out or "[]")
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return []


def positions(props, info):
    pos = props.get("audio.position")
    if isinstance(pos, str):
        pos = [p.strip() for p in pos.strip("[] ").replace(",", " ").split() if p.strip()]
    if not pos:
        for p in (info.get("params") or {}).get("EnumFormat") or []:
            if isinstance(p, dict) and p.get("position"):
                pos = p["position"]
                break
    if not pos:
        n = int(props.get("audio.channels") or 2)
        pos = ["FL", "FR"] if n == 2 else ["MONO"] if n == 1 else ["AUX%d" % i for i in range(n)]
    return list(pos)


def graph():
    """nodes by name + the default output name"""
    nodes, links, default_sink = {}, [], ""
    for o in pw_dump():
        t = o.get("type", "")
        if t == "PipeWire:Interface:Node":
            info = o.get("info") or {}
            props = info.get("props") or {}
            name = props.get("node.name")
            if not name:
                continue
            nodes[name] = {
                "name": name,
                "description": props.get("node.description") or props.get("node.nick") or name,
                "class": props.get("media.class", ""),
                "positions": positions(props, info),
                "target": str(props.get("target.object") or ""),
                "group": props.get("node.link-group") or "",
                "serial": str(props.get("object.serial") or ""),
                "virtual": bool(props.get("node.virtual")),
            }
        elif t == "PipeWire:Interface:Metadata" and (o.get("props") or {}).get("metadata.name") == "default":
            for m in o.get("metadata") or []:
                if m.get("key") == "default.audio.sink":
                    v = m.get("value")
                    default_sink = v.get("name", "") if isinstance(v, dict) else str(v or "")
    return nodes, default_sink


def by_target(nodes, name):
    serial = nodes[name]["serial"] if name in nodes else ""
    return [n for n in nodes.values() if n["target"] and n["target"] in (name, serial)]


def pair_label(nodes, node, pair, stream_class):
    # loopbacks (parzival's rcp_duo_* and friends) name the channel pairs they use
    for s in by_target(nodes, node["name"]):
        if s["class"] == stream_class and s["positions"] == pair:
            return s["description"]
    return ""


def listing():
    nodes, default_sink = graph()
    out = []
    for n in sorted(nodes.values(), key=lambda n: (n["class"], n["description"].lower())):
        if n["class"] not in ("Audio/Sink", "Audio/Source", "Audio/Source/Virtual", "Audio/Duplex"):
            continue
        sink = n["class"] == "Audio/Sink"
        pos = n["positions"]
        pairs = []
        if len(pos) > 2:
            for i in range(0, len(pos) - 1, 2):
                pair = pos[i:i + 2]
                pairs.append({
                    "channels": pair,
                    "label": pair_label(nodes, n, pair, "Stream/Output/Audio" if sink else "Stream/Input/Audio"),
                })
        out.append({
            "name": n["name"],
            "description": n["description"],
            "kind": "output" if sink else "input",
            "channels": pos,
            "pairs": pairs,
            "virtual": n["virtual"],
        })
    auto = resolve("", nodes, default_sink)
    return {"default": default_sink, "auto": auto_text(auto, nodes), "nodes": out}


def resolve(spec, nodes=None, default_sink=None):
    """spec → (target node, capture a sink?, channel map, left idx, right idx) or None"""
    if nodes is None:
        nodes, default_sink = graph()
    spec = spec or "auto"
    if spec == "auto":
        n = nodes.get(default_sink)
        if not n:
            return None
        # a virtual output that loops into a multichannel interface: listen to the
        # whole interface, so music/games routed to its other pairs show up too
        if n["virtual"] and n["group"]:
            for s in nodes.values():
                if s["group"] == n["group"] and s["class"] == "Stream/Output/Audio":
                    hw = nodes.get(s["target"]) or next((x for x in nodes.values() if x["serial"] == s["target"]), None)
                    if hw and hw["class"] == "Audio/Sink" and len(hw["positions"]) > 2:
                        return mix(hw["name"], True, hw["positions"])
        return mix(n["name"], True, n["positions"])
    kind, _, rest = spec.partition(":")
    if kind == "monitor":
        n = nodes.get(rest)
        return mix(rest, True, n["positions"] if n else ["FL", "FR"])
    if kind == "all":
        n = nodes.get(rest)
        return mix(rest, bool(n) and n["class"] == "Audio/Sink", n["positions"] if n else ["FL", "FR"])
    if kind == "pair":
        name, _, chans = rest.rpartition(":")
        n = nodes.get(name)
        pair = [c for c in chans.split(",") if c][:2] or ["FL", "FR"]
        return mix(name, bool(n) and n["class"] == "Audio/Sink", pair)
    if kind == "input":
        n = nodes.get(rest)
        return mix(rest, False, n["positions"] if n else ["FL", "FR"])
    n = nodes.get(spec)  # older setting: a bare node name
    if n:
        return mix(spec, n["class"] == "Audio/Sink", n["positions"])
    return None


def mix(target, sink, pos):
    pos = list(pos) or ["FL", "FR"]
    if len(pos) == 1:
        return (target, sink, pos, [0], [0])
    even, odd = list(range(0, len(pos), 2)), list(range(1, len(pos), 2))
    if any(p.startswith("AUX") for p in pos):  # unpositioned: pairs are (0,1), (2,3), …
        return (target, sink, pos, even, odd)
    both = [i for i, p in enumerate(pos) if not p.endswith(("L", "R"))]  # FC, LFE, MONO…
    left = [i for i, p in enumerate(pos) if p.endswith("L")]
    right = [i for i, p in enumerate(pos) if p.endswith("R")]
    if not left or not right:
        return (target, sink, pos, even, odd)
    return (target, sink, pos, sorted(left + both), sorted(right + both))


def auto_text(r, nodes):
    if not r:
        return ""
    n = nodes.get(r[0])
    d = n["description"] if n else r[0]
    return d + (" (%d ch)" % len(r[2]) if len(r[2]) > 2 else "")


# ---------------------------------------------------------------- run
children = []


def die_with_parent():
    # children never outlive the tap (a crashed shell must not leave cava behind)
    try:
        import ctypes
        ctypes.CDLL(None).prctl(1, signal.SIGKILL)  # PR_SET_PDEATHSIG
    except (OSError, AttributeError):
        pass


def reap():
    # cava waits for a new writer when the FIFO closes and ignores SIGTERM while
    # it is blocked there, so it gets a short grace period and then SIGKILL
    for p in children:
        if p.poll() is None:
            p.terminate()
    deadline = time.monotonic() + 0.5
    for p in children:
        try:
            p.wait(max(0.01, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            p.kill()


def stop(*_):
    reap()
    sys.exit(0)


# Nothing here may wait forever (B4: the widget froze): cava that died before opening its
# end of the FIFO, a recorder that ignores SIGTERM after sleep, cava that stopped reading.
def end(p, grace=2.0):
    if p.poll() is None:
        p.terminate()
    try:
        p.wait(grace)
    except subprocess.TimeoutExpired:
        p.kill()
        try:
            p.wait(1)
        except subprocess.TimeoutExpired:
            pass


def open_writer(fifo, cava, timeout=10.0):
    """the FIFO's writing end once cava has opened the other one; None if cava died or
    never came (a plain blocking open would wait for it forever)"""
    deadline = time.monotonic() + timeout
    while True:
        try:
            return os.open(fifo, os.O_WRONLY | os.O_NONBLOCK)
        except OSError as e:
            if e.errno != errno.ENXIO:
                raise
        if cava.poll() is not None or time.monotonic() > deadline:
            return None
        time.sleep(0.05)


def write_all(fd, data, timeout=3.0):
    """write to the FIFO; TimeoutError when cava hasn't read for `timeout` seconds"""
    view = memoryview(data)
    deadline = time.monotonic() + timeout
    while view:
        try:
            view = view[os.write(fd, view):]
        except BlockingIOError:
            left = deadline - time.monotonic()
            if left <= 0:
                raise TimeoutError
            select.select([], [fd], [], left)


def record(route):
    target, sink, pos, _, _ = route
    props = ("{ node.name = angelos-cava node.description = \"angelOS visualizer\" media.role = Music "
             "node.always-process = true node.dont-fallback = true node.dont-reconnect = true node.dont-move = true "
             + ("stream.capture.sink = true " if sink else "") + "}")
    cmd = ["pw-record", "--target", target, "-P", props, "--rate", str(RATE), "--channels", str(len(pos)),
           "--channel-map", ",".join(pos), "--format", "s16", "--latency", "20ms", "--raw", "-"]
    return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL,
                            preexec_fn=die_with_parent)


def mixer(route):
    _, _, pos, left, right = route
    n = len(pos)
    if n == 2 and left == [0] and right == [1]:
        return None  # already stereo in order: pass through
    if np is not None:
        def f(buf):
            a = np.frombuffer(buf, "<i2").reshape(-1, n).astype(np.int32)
            out = np.empty((a.shape[0], 2), np.int32)
            out[:, 0] = a[:, left].sum(1)
            out[:, 1] = a[:, right].sum(1)
            return np.clip(out, -32768, 32767).astype("<i2").tobytes()
        return f

    def g(buf):
        a = array("h", buf)
        ls = [a[i::n] for i in left]
        rs = [a[i::n] for i in right]
        out = array("h", bytes(len(ls[0]) * 4))
        out[0::2] = array("h", [max(-32768, min(32767, v)) for v in map(sum, zip(*ls))]) if len(ls) > 1 else ls[0]
        out[1::2] = array("h", [max(-32768, min(32767, v)) for v in map(sum, zip(*rs))]) if len(rs) > 1 else rs[0]
        return out.tobytes()
    return g


def default_sink_name():
    try:
        return subprocess.run(["pactl", "get-default-sink"], capture_output=True, text=True, timeout=3).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def run(conf, fifo, spec):
    if not shutil.which("cava"):
        sys.exit(127)
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        if not stat.S_ISFIFO(os.stat(fifo).st_mode):
            os.unlink(fifo)
            raise FileNotFoundError
    except FileNotFoundError:
        os.mkfifo(fifo, 0o600)
    cava = subprocess.Popen(["cava", "-p", conf], stdin=subprocess.DEVNULL, preexec_fn=die_with_parent)
    children.append(cava)
    out = open_writer(fifo, cava)
    if out is None:
        print("audio-tap: cava exited before reading (code %s)" % cava.poll(), file=sys.stderr)
        reap()
        sys.exit(3)
    auto = (spec or "auto") == "auto"
    code = 0
    route, rec, fn, rest, frame = None, None, None, b"", 2
    restart, last_check, last_default, last_data = True, 0.0, None, time.monotonic()
    try:
        while cava.poll() is None:
            now = time.monotonic()
            if auto and now - last_check > 2:
                last_check = now
                d = default_sink_name()
                if d != last_default:
                    last_default = d
                    new = resolve(spec)
                    if new != route:
                        route, restart = new, True
            # (re)start the recorder: first run, new default output, recorder died,
            # or the node went silent-dead (USB replug, PipeWire restart)
            dead = rec is not None and (rec.poll() is not None or now - last_data > 5)
            if restart or rec is None or dead:
                if rec is not None:
                    end(rec)
                    children.remove(rec)
                    rec = None
                    if dead:
                        time.sleep(1)
                if not auto or route is None:
                    route = resolve(spec)
                restart = False
                if not route:
                    time.sleep(2)
                    continue
                rec = record(route)
                children.append(rec)
                fn = mixer(route)
                frame = 2 * len(route[2])
                rest, last_data = b"", time.monotonic()
            ready, _, _ = select.select([rec.stdout], [], [], 1.0)
            if not ready:
                continue
            chunk = os.read(rec.stdout.fileno(), frame * 441)
            if not chunk:
                end(rec, 1.0)
                continue
            last_data = time.monotonic()
            chunk = rest + chunk
            cut = len(chunk) - len(chunk) % frame
            rest = chunk[cut:]
            if cut:
                write_all(out, fn(chunk[:cut]) if fn else chunk[:cut])
    except TimeoutError:
        print("audio-tap: cava stopped reading; starting over", file=sys.stderr)
        code = 4
    except OSError:  # cava closed the FIFO
        pass
    finally:
        reap()
        try:
            os.unlink(fifo)
        except OSError:
            pass
    if code:
        sys.exit(code)


def main():
    global RATE
    args = sys.argv[1:]
    if not args or args[0] == "list":
        print(json.dumps(listing(), ensure_ascii=False))
        return
    if args[0] == "resolve":
        print(json.dumps(resolve(args[1] if len(args) > 1 else "")))
        return
    if args[0] == "run":
        conf = fifo = None
        spec = ""
        i = 1
        while i < len(args):
            if args[i] == "--conf":
                conf, i = args[i + 1], i + 2
            elif args[i] == "--fifo":
                fifo, i = args[i + 1], i + 2
            elif args[i] == "--rate":
                RATE, i = int(args[i + 1]), i + 2
            else:
                spec, i = args[i], i + 1
        if not conf or not fifo:
            sys.exit("usage: audio-tap.py run --conf CONF --fifo FIFO [--rate HZ] [SPEC]")
        run(conf, fifo, spec)
        return
    sys.exit(__doc__)


if __name__ == "__main__":
    main()
