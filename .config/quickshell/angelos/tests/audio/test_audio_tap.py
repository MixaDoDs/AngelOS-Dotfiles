#!/usr/bin/env python3
"""scripts/audio-tap.py never hangs (B4: the cava widget froze). Offline: stand-ins for
cava, pw-record, pactl and pw-dump on PATH, no PipeWire, no sound.

  python3 tests/audio/test_audio_tap.py      exit 0 = all good

  frames       the pipeline runs: the recorder's samples reach cava through the FIFO
  early-death  cava dies before opening the FIFO: the tap exits instead of waiting forever
  stuck-cava   cava stops reading: the tap gives up within seconds instead of blocking
  stuck-rec    the recorder goes silent and ignores SIGTERM: a new one is started
  no-orphans   the tap killed: cava and the recorder go with it
"""
import json
import os
import pathlib
import signal
import subprocess
import sys
import tempfile
import time

TAP = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "audio-tap.py"

FAKE_CAVA = r'''#!/usr/bin/env python3
# stand-in cava: reads the FIFO named in the config, prints a frame per 20 ms of audio
import os, sys, time, re
conf = open(sys.argv[sys.argv.index("-p") + 1]).read()
fifo = re.search(r"source = (.*)", conf).group(1).strip()
mode = os.environ.get("FAKE_CAVA", "")
log = os.environ["FAKE_LOG"]
if mode == "die":
    sys.exit(1)
fd = os.open(fifo, os.O_RDONLY)
open(log, "a").write("cava-open\n")
got = 0
while True:
    if mode == "stuck" and got > 4000:
        time.sleep(3600)          # alive, but reads nothing any more
    b = os.read(fd, 4096)
    if not b:
        time.sleep(0.01)
        continue
    got += len(b)
    print("0;" * 4, flush=True)
    open(log, "a").write("cava-bytes %d\n" % len(b))
'''

FAKE_REC = r'''#!/usr/bin/env python3
# stand-in pw-record: zeros at 22 kHz stereo s16; FAKE_REC=stall: a little, then nothing,
# and SIGTERM is ignored (a recorder hung after sleep)
import os, signal, sys, time
mode = os.environ.get("FAKE_REC", "")
log = os.environ["FAKE_LOG"]
open(log, "a").write("rec-start %d\n" % os.getpid())
if mode == "stall":
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
n = 0
while True:
    if mode == "stall" and n > 10:
        time.sleep(3600)
    sys.stdout.buffer.write(b"\0" * 1764)
    sys.stdout.buffer.flush()
    n += 1
    time.sleep(0.02)
'''

PW_DUMP = [{
    "id": 50, "type": "PipeWire:Interface:Node",
    "info": {"props": {"node.name": "test-sink", "media.class": "Audio/Sink", "audio.position": "FL,FR",
                       "node.description": "Test sink"}, "params": {}}
}]


def stand(tmp, env_extra):
    bin_ = tmp / "bin"
    bin_.mkdir(exist_ok=True)
    for name, body in {"cava": FAKE_CAVA, "pw-record": FAKE_REC}.items():
        (bin_ / name).write_text(body)
        (bin_ / name).chmod(0o755)
    (bin_ / "pactl").write_text("#!/bin/sh\necho test-sink\n")
    (bin_ / "pw-dump").write_text("#!/bin/sh\ncat <<'EOF'\n" + json.dumps(PW_DUMP) + "\nEOF\n")
    for n in ("pactl", "pw-dump"):
        (bin_ / n).chmod(0o755)
    fifo = tmp / "t.fifo"
    conf = tmp / "t.conf"
    conf.write_text("[input]\nmethod = fifo\nsource = %s\n" % fifo)
    log = tmp / "log"
    log.write_text("")
    env = dict(os.environ, PATH=str(bin_) + os.pathsep + os.environ.get("PATH", ""), FAKE_LOG=str(log), **env_extra)
    p = subprocess.Popen([sys.executable, str(TAP), "run", "--conf", str(conf), "--fifo", str(fifo), "monitor:test-sink"],
                         env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    return p, log


def lines(log, word):
    return [l for l in log.read_text().splitlines() if l.startswith(word)]


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    try:
        return "Z" not in open("/proc/%d/stat" % pid).read().split(")")[1].split()[0]
    except OSError:
        return False


def children_of(pid):
    kids = []
    for d in os.listdir("/proc"):
        if d.isdigit():
            try:
                stat = open("/proc/%s/stat" % d).read()
            except OSError:
                continue
            if int(stat.rsplit(")", 1)[1].split()[1]) == pid:
                kids.append(int(d))
    return kids


failures = 0


def check(name, ok, detail=""):
    global failures
    if not ok:
        failures += 1
    print("  %s %s %s" % ("✓" if ok else "✕", name, detail))


def main():
    print("» audio-tap: no hangs (B4)")
    with tempfile.TemporaryDirectory() as d:
        tmp = pathlib.Path(d)

        (tmp / "a").mkdir()
        p, log = stand(tmp / "a", {})
        time.sleep(1.5)
        n = len(lines(log, "cava-bytes"))
        kids = children_of(p.pid)
        check("frames", n > 5 and p.poll() is None, "%d reads by cava in 1.5 s" % n)
        p.kill()
        p.wait()
        time.sleep(0.5)
        left = [k for k in kids if alive(k)]
        check("no-orphans", not left, "children left after the tap was killed: %s" % left if left else "cava and the recorder went with the tap")
        for k in left:
            os.kill(k, signal.SIGKILL)

        (tmp / "b").mkdir()
        t0 = time.monotonic()
        p, log = stand(tmp / "b", {"FAKE_CAVA": "die"})
        try:
            code = p.wait(15)
        except subprocess.TimeoutExpired:
            code = None
            p.kill()
        check("early-death", code not in (None, 0), "cava died first → the tap exited %s in %.1f s" % (code, time.monotonic() - t0))

        (tmp / "c").mkdir()
        t0 = time.monotonic()
        p, log = stand(tmp / "c", {"FAKE_CAVA": "stuck"})
        try:
            code = p.wait(20)
        except subprocess.TimeoutExpired:
            code = None
            p.kill()
        check("stuck-cava", code not in (None, 0), "cava stopped reading → the tap exited %s in %.1f s" % (code, time.monotonic() - t0))

        (tmp / "d").mkdir()
        p, log = stand(tmp / "d", {"FAKE_REC": "stall"})
        # the second recorder comes in ~10 s; on a busy machine (the checks run side by side) later
        t0 = time.monotonic()
        while time.monotonic() - t0 < 30 and len(lines(log, "rec-start")) < 2:
            time.sleep(0.5)
        starts = len(lines(log, "rec-start"))
        check("stuck-rec", starts >= 2 and p.poll() is None, "%d recorders started in %.0f s (the first went silent and ignored SIGTERM)" % (starts, time.monotonic() - t0))
        kids = children_of(p.pid)
        p.kill()
        p.wait()
        time.sleep(0.5)
        for k in kids:
            if alive(k):
                os.kill(k, signal.SIGKILL)
    if failures:
        print("» audio-tap tests FAILED")
        sys.exit(1)
    print("» audio-tap tests passed")


if __name__ == "__main__":
    main()
