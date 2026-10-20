#!/usr/bin/env python3
"""The day's timelapse (services/Timelapse, Settings → Screenshots and recording): gpu-screen-recorder
writes the main screen at a frame a second all day (small, into FRAMES/<date>/<HHMMSS>.mkv — mkv
survives being cut off), and the day is glued into a short video: a frame every STEP seconds, the
time of day in a corner, stretches where the screen didn't change dropped.

  timelapse.py build FRAMES DATE OUTDIR [--keep] [--step S]   OUTDIR/Таймлапс DATE.mp4; the day's
                                                               recordings removed after (--keep: today's)
  timelapse.py tidy FRAMES OUTDIR                              build every finished day left behind
  timelapse.py --self-test

Each command prints JSON lines: {"path": …, "frames": n} or {"error": …}.
"""
import datetime
import json
import os
import shutil
import subprocess
import sys
import tempfile

FPS = 24
STEP = 30
HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "..", "data", "fonts", "DepartureMono-Regular.otf")


def say(**kw):
    print(json.dumps(kw, ensure_ascii=False), flush=True)


def ff(args):
    r = subprocess.run(["nice", "-n", "10", "ffmpeg", "-nostdin", "-loglevel", "error", "-y"] + args,
                       capture_output=True, text=True)
    return r.returncode == 0, (r.stderr.strip().splitlines() or [""])[-1]


def build(frames, date, outdir, keep=False, step=STEP):
    d = os.path.join(frames, date)
    parts = sorted(f for f in os.listdir(d) if f.endswith(".mkv")) if os.path.isdir(d) else []
    if not parts:
        return say(error="none")
    day = datetime.datetime.strptime(date, "%Y-%m-%d")
    font = os.path.abspath(FONT)
    tmp = tempfile.mkdtemp(dir=d)
    pieces = []
    # each recording on its own: a frame every STEP s, the time it was taken in the corner (its
    # start from the file's name + the frame's own time), what didn't change dropped
    for i, f in enumerate(parts):
        start = day.replace(hour=int(f[:2]), minute=int(f[2:4]), second=int(f[4:6]))
        clock = ("drawtext=fontfile='%s':text='%%{pts\\:localtime\\:%d\\:%%H\\\\\\:%%M}':x=w-tw-h/40:y=h-th-h/40:"
                 "fontsize=h/12:fontcolor=white:box=1:boxcolor=black@0.45:boxborderw=h/90," % (font, int(start.timestamp()))
                 ) if os.path.isfile(font) else ""
        piece = os.path.join(tmp, "%03d.mkv" % i)
        # by time, not by count: gpu-screen-recorder writes a frame only when the screen changes
        ok, err = ff(["-i", os.path.join(d, f), "-an", "-vf",
                      "select='isnan(prev_selected_t)+gte(t-prev_selected_t\\,%d)',mpdecimate=hi=64*24:lo=64*6:frac=0.5,%s"
                      "setpts=N/%d/TB,scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p" % (step, clock, FPS),
                      "-fps_mode", "passthrough", "-c:v", "libx264", "-preset", "veryfast", "-crf", "22", piece])
        # a recording cut off at its very start has nothing in it: left out, the rest goes on
        if ok and os.path.getsize(piece) > 0:
            pieces.append(piece)
    if not pieces:
        shutil.rmtree(tmp, ignore_errors=True)
        return say(error="ffmpeg: " + err)
    lst = os.path.join(tmp, "list.txt")
    with open(lst, "w") as fh:
        fh.writelines("file '%s'\n" % p for p in pieces)
    os.makedirs(outdir, exist_ok=True)
    out = os.path.join(outdir, "Таймлапс %s.mp4" % date)
    part = os.path.join(tmp, "out.mp4")
    ok, err = ff(["-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", "-movflags", "+faststart", part])
    if not ok:
        shutil.rmtree(tmp, ignore_errors=True)
        return say(error="ffmpeg: " + err)
    shutil.move(part, out)
    n = subprocess.run(["ffprobe", "-v", "error", "-count_packets", "-select_streams", "v", "-show_entries",
                        "stream=nb_read_packets", "-of", "csv=p=0", out], capture_output=True, text=True).stdout.strip()
    shutil.rmtree(tmp, ignore_errors=True)
    if not keep:
        shutil.rmtree(d, ignore_errors=True)
    say(path=out, frames=int(n or 0))


def tidy(frames, outdir, today=None):
    today = today or datetime.date.today().isoformat()
    if not os.path.isdir(frames):
        return
    for date in sorted(os.listdir(frames)):
        if date < today and len(date) == 10 and os.path.isdir(os.path.join(frames, date)):
            build(frames, date, outdir)


def self_test():
    t = tempfile.mkdtemp()
    frames, out = os.path.join(t, "frames"), os.path.join(t, "out")
    d = os.path.join(frames, "2026-10-18")
    os.makedirs(d)
    # two recordings of a frame a second: 5 min of a picture that changes, then 5 min of a still one
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=size=320x180:rate=1:duration=300",
                    "-c:v", "libx264", os.path.join(d, "090000.mkv")], check=True)
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=0x223344:size=320x180:rate=1:duration=300",
                    "-c:v", "libx264", os.path.join(d, "100000.mkv")], check=True)
    open(os.path.join(d, "110000.mkv"), "w").close()       # cut off before its first frame
    lines = []
    real = sys.stdout.write
    sys.stdout.write = lambda s: lines.append(s) or len(s)
    try:
        tidy(frames, out, today="2026-10-20")
        tidy(frames, out, today="2026-10-20")              # nothing left to build
    finally:
        sys.stdout.write = real
    res = [json.loads(x) for x in "".join(lines).splitlines() if x.strip()]
    video = os.path.join(out, "Таймлапс 2026-10-18.mp4")
    assert len(res) == 1 and res[0]["path"] == video, res
    # 300 s / 30 s = 10 changing frames + the still stretch pressed to one or two
    assert 10 <= res[0]["frames"] <= 13, res
    assert not os.path.exists(d), "the built day's recordings are gone"
    shutil.rmtree(t)
    print("timelapse ok (%d frames from 10 min)" % res[0]["frames"])


def main():
    a = sys.argv[1:]
    if a[:1] == ["--self-test"]:
        return self_test()
    if a[:1] == ["build"] and len(a) >= 4:
        step = int(a[a.index("--step") + 1]) if "--step" in a else STEP
        return build(os.path.expanduser(a[1]), a[2], os.path.expanduser(a[3]), keep="--keep" in a, step=step)
    if a[:1] == ["tidy"] and len(a) == 3:
        return tidy(os.path.expanduser(a[1]), os.path.expanduser(a[2]))
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
