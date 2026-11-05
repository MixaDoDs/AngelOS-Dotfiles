#!/usr/bin/env python3
"""The day's timelapse (services/Timelapse, Settings → Screenshots and recording): gpu-screen-recorder
writes the main screen at a frame a second all day (small, into FRAMES/<date>/<HHMMSS>.mkv — mkv
survives being cut off), and the day is glued into a short video: a frame every STEP seconds, the
time of day in a corner, stretches where the screen didn't change dropped.

The day's moments: a replay buffer (20 s, with sound) is saved whenever you talk, shout, laugh
(`listen` on the mic) or the stream's chat bursts; the best few of each day are kept in
FRAMES/<date>/moments/<HHMMSS>-<score>.mp4 (HHMMSS: when saved = the clip's end). The video is
then the timelapse squeezed to an intro of INTRO s and the day's best TOP moments after it, in
the day's order, with their sound and time. A clip's first sound track goes into the video, the
second (the mic alone) is what the night's ears hear, when there are any (environment):
  ANGELOS_MOMENTS_EAR="<python> <worker> <model dir>"  an AudioSet tagger speaking JSONL
                         ({"wav", "windows"} → {"probs"}): laughter and shouting count
  ANGELOS_MOMENTS_WHISPER="<whisper-cli> <model>"      the words: reactions («ахаха», «ору», «вау»…) count
Both on the CPU, niced: at midnight a game or the stream may hold the card.

  timelapse.py build FRAMES DATE OUTDIR [--keep] [--step S]   OUTDIR/Таймлапс DATE.mp4; the day's
                                                               recordings removed after (--keep: today's)
  timelapse.py tidy FRAMES OUTDIR                              build every finished day left behind
  timelapse.py listen [SOURCE]                                 the mic (default one without SOURCE):
                                                               {"voice": score} when a moment's heard
  timelapse.py moment FILE SCORE FRAMES                        a saved clip into today's moments
  timelapse.py --self-test

Each command prints JSON lines: {"path": …, "frames": n} or {"error": …}.
"""
import array
import collections
import datetime
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile

FPS = 24
STEP = 30
INTRO = 15          # s of timelapse before the moments
TOP = 5             # moments in the video
KEEP = 20           # moments kept on disk a day: the night's ears pick TOP of them
SIZE = "1280:720"
HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "..", "data", "fonts", "DepartureMono-Regular.otf")


def say(**kw):
    print(json.dumps(kw, ensure_ascii=False), flush=True)


def ff(args):
    r = subprocess.run(["nice", "-n", "10", "ffmpeg", "-nostdin", "-loglevel", "error", "-y"] + args,
                       capture_output=True, text=True)
    return r.returncode == 0, (r.stderr.strip().splitlines() or [""])[-1]


def clock(start):
    """the time of day in a corner: start (a datetime) + the frame's own time"""
    font = os.path.abspath(FONT)
    return ("drawtext=fontfile='%s':text='%%{pts\\:localtime\\:%d\\:%%H\\\\\\:%%M}':x=w-tw-h/40:y=h-th-h/40:"
            "fontsize=h/12:fontcolor=white:box=1:boxcolor=black@0.45:boxborderw=h/90," % (font, int(start.timestamp()))
            ) if os.path.isfile(font) else ""


def probe(path):
    """(duration s, sound tracks)"""
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=codec_type",
                        "-of", "json", path], capture_output=True, text=True)
    try:
        j = json.loads(r.stdout)
        return float(j["format"]["duration"]), sum(x.get("codec_type") == "audio" for x in j.get("streams", []))
    except (ValueError, KeyError):
        return 0.0, 0


def score_of(name):
    try:
        return float(name[7:-4])
    except ValueError:
        return 0.0


REACT = re.compile(r"а{3,}|(?:ха|хa|ah|ha){2,}|(?:ах){2,}|\bору\b|охуе|ебать|ни ?ху[яй]? себе|\bвау\b|\bwow\b|\bwtf\b|"
                   r"oh my god|holy|какого хуя|\bсмотри\b|\bвидел[иа]?\b|\bчат\b", re.I)
LAUGH = ("Laughter", "Belly laugh", "Giggle", "Snicker", "Chuckle, chortle")
SHOUT = ("Shout", "Yell", "Screaming", "Bellow", "Battle cry")


def words(text):
    """the reactions in what was said: 2 each, at most 10"""
    return min(10, 2 * len(REACT.findall(text or "")))


class Ears:
    """the night's ears on a clip's mic track: {file: (bonus, why)}; none set up — nothing"""

    def __init__(self, env=os.environ):
        self.ear = (env.get("ANGELOS_MOMENTS_EAR") or "").split()
        self.whisper = (env.get("ANGELOS_MOMENTS_WHISPER") or "").split()
        self.proc = None
        self.labels = {}

    def tag(self, wav, dur):
        if len(self.ear) != 3:
            return 0.0, ""
        if self.proc is None:
            try:
                names = json.load(open(os.path.join(self.ear[2], "config.json")))["id2label"]
                self.labels = {v: int(k) for k, v in names.items()}
                self.proc = subprocess.Popen(["nice", "-n", "10"] + self.ear, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                             text=True, env=dict(os.environ, MAID_EAR_DEVICE="cpu", MAID_EAR_IDLE="120"))
                json.loads(self.proc.stdout.readline())          # {"ready": …}
            except (OSError, ValueError, KeyError):
                self.ear, self.proc = [], None
                return 0.0, ""
        self.proc.stdin.write(json.dumps({"wav": wav, "windows": [[t, 2.0] for t in range(0, int(dur), 2)][:16]}) + "\n")
        self.proc.stdin.flush()
        try:
            probs = json.loads(self.proc.stdout.readline())["probs"]
        except (ValueError, KeyError):
            return 0.0, ""
        top = lambda names: max((row[self.labels[n]] for row in probs for n in names if n in self.labels), default=0.0)
        laugh, shout = top(LAUGH), top(SHOUT)
        why = " ".join(w for w, p in (("смех", laugh), ("крик", shout)) if p >= 0.3)
        return 15 * laugh + 10 * shout, why

    def hear(self, wav):
        if len(self.whisper) != 2:
            return ""
        out = wav[:-4]
        r = subprocess.run(["nice", "-n", "10", self.whisper[0], "-m", self.whisper[1], "-f", wav, "-l", "auto", "-t", "4",
                            "-ng", "-otxt", "-of", out, "-np", "-nt"], capture_output=True, timeout=300)
        try:
            return open(out + ".txt", errors="replace").read() if r.returncode == 0 else ""
        except OSError:
            return ""

    def judge(self, clips, tmp):
        res = {}
        if len(self.ear) != 3 and len(self.whisper) != 2:
            return res
        for f, dur, tracks in clips:
            if not tracks:
                continue
            wav = os.path.join(tmp, os.path.basename(f)[:-4] + ".wav")
            ok, _ = ff(["-i", f, "-map", "0:a:%d" % (1 if tracks > 1 else 0), "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", wav])
            if not ok:
                continue
            bonus, why = self.tag(wav, dur)
            w = words(self.hear(wav))
            res[f] = (bonus + w, (why + (" слова" if w else "")).strip())
        if self.proc:
            self.proc.stdin.close()
            self.proc.wait()
        return res


def pick(mdir, top=TOP, tmp=None):
    """the day's best moments, in the day's order: [(file, duration, sound tracks)]. The voice's or
    the chat's score, nudged by how much the picture moves (bytes a second against the others'),
    plus what the night's ears heard on it"""
    names = [f for f in os.listdir(mdir) if f.endswith(".mp4") and len(f) > 11] if os.path.isdir(mdir) else []
    clips = []
    for f in names:
        p = os.path.join(mdir, f)
        dur, sound = probe(p)
        if dur >= 1:
            clips.append([f, dur, sound, os.path.getsize(p) / dur])
    if not clips:
        return []
    rates = sorted(c[3] for c in clips)
    mid = rates[len(rates) // 2] or 1
    heard = Ears().judge([(os.path.join(mdir, c[0]), c[1], c[2]) for c in clips], tmp or mdir)
    for c in clips:
        c.append(score_of(c[0]) * min(1.5, max(0.75, 0.75 + 0.25 * c[3] / mid)) + heard.get(os.path.join(mdir, c[0]), (0,))[0])
    if heard:
        say(heard={os.path.basename(k): v for k, v in heard.items()})
    best = sorted(clips, key=lambda c: c[4], reverse=True)[:top]
    return [(os.path.join(mdir, c[0]), c[1], c[2]) for c in sorted(best)]


def build(frames, date, outdir, keep=False, step=STEP):
    d = os.path.join(frames, date)
    parts = sorted(f for f in os.listdir(d) if f.endswith(".mkv")) if os.path.isdir(d) else []
    if not parts and not os.path.isdir(os.path.join(d, "moments")):
        return say(error="none")
    day = datetime.datetime.strptime(date, "%Y-%m-%d")
    tmp = tempfile.mkdtemp(dir=d)
    moments = pick(os.path.join(d, "moments"), tmp=tmp)
    if not parts and not moments:
        shutil.rmtree(tmp, ignore_errors=True)
        return say(error="none")
    pieces = []
    err = ""
    # each recording on its own: a frame every STEP s, the time it was taken in the corner (its
    # start from the file's name + the frame's own time), what didn't change dropped
    for i, f in enumerate(parts):
        start = day.replace(hour=int(f[:2]), minute=int(f[2:4]), second=int(f[4:6]))
        piece = os.path.join(tmp, "%03d.mkv" % i)
        # by time, not by count: gpu-screen-recorder writes a frame only when the screen changes
        ok, err = ff(["-i", os.path.join(d, f), "-an", "-vf",
                      "select='isnan(prev_selected_t)+gte(t-prev_selected_t\\,%d)',mpdecimate=hi=64*24:lo=64*6:frac=0.5,%s"
                      "setpts=N/%d/TB,scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p" % (step, clock(start), FPS),
                      "-fps_mode", "passthrough", "-c:v", "libx264", "-preset", "veryfast", "-crf", "22", piece])
        # a recording cut off at its very start has nothing in it: left out, the rest goes on
        if ok and os.path.getsize(piece) > 0:
            pieces.append(piece)
    if not pieces and not moments:
        shutil.rmtree(tmp, ignore_errors=True)
        return say(error="ffmpeg: " + err)
    os.makedirs(outdir, exist_ok=True)
    out = os.path.join(outdir, "Таймлапс %s.mp4" % date)
    part = os.path.join(tmp, "out.mp4")
    if pieces:
        lst = os.path.join(tmp, "list.txt")
        with open(lst, "w") as fh:
            fh.writelines("file '%s'\n" % p for p in pieces)
        tl = os.path.join(tmp, "tl.mp4")
        ok, err = ff(["-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", "-movflags", "+faststart", tl if moments else part])
        if not ok:
            shutil.rmtree(tmp, ignore_errors=True)
            return say(error="ffmpeg: " + err)
    if moments:
        # the timelapse squeezed to INTRO s, silent, then each moment with its sound and time
        ins, chains, n = [], [], 0
        fit = "scale=%s:force_original_aspect_ratio=decrease,pad=%s:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30," % (SIZE, SIZE)
        if pieces:
            dur, _ = probe(tl)
            k = min(1.0, INTRO / dur) if dur else 1.0
            ins += ["-i", tl]
            chains.append("[0:v]setpts=PTS*%f,%sformat=yuv420p[v0];anullsrc=r=48000:cl=stereo,atrim=duration=%f[a0]" % (k, fit, dur * k))
            n = 1
        for p, dur, sound in moments:
            name = os.path.basename(p)
            end = day.replace(hour=int(name[:2]), minute=int(name[2:4]), second=int(name[4:6]))
            ins += ["-i", p]
            chains.append("[%d:v]setpts=PTS-STARTPTS,%s%sformat=yuv420p[v%d]" % (n, fit, clock(end - datetime.timedelta(seconds=dur)), n))
            chains.append(("[%d:a:0]asetpts=PTS-STARTPTS,aresample=48000,aformat=channel_layouts=stereo[a%d]" % (n, n)) if sound
                          else "anullsrc=r=48000:cl=stereo,atrim=duration=%f[a%d]" % (dur, n))
            n += 1
        graph = ";".join(chains) + ";" + "".join("[v%d][a%d]" % (i, i) for i in range(n)) + "concat=n=%d:v=1:a=1[v][a]" % n
        ok, err = ff(ins + ["-filter_complex", graph, "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-preset", "veryfast",
                            "-crf", "22", "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", part])
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


def moment(path, score, frames, keep=KEEP):
    """a clip the buffer saved → today's moments; only the best KEEP stay"""
    now = datetime.datetime.now()
    d = os.path.join(frames, now.strftime("%Y-%m-%d"), "moments")
    os.makedirs(d, mode=0o700, exist_ok=True)
    shutil.move(path, os.path.join(d, "%s-%.1f.mp4" % (now.strftime("%H%M%S"), score)))
    for f in sorted(os.listdir(d), key=score_of, reverse=True)[keep:]:
        os.remove(os.path.join(d, f))


class Voice:
    """The mic's level, 10 blocks a second (dBFS) → a moment's score when you go off: louder than
    you usually talk, not just talking (a streamer talks all the time). The room's floor: the 10th
    percentile of the last 2 minutes; talking: over floor + TALK; how you usually talk: the median
    of the last USUAL talking blocks (nothing's scored before BASE of them). The score: how far over
    that the last WIN s went, on average — talking as usual ~1, a shout or laughter many. Over MIN
    it's followed to its peak and told HOLD blocks after it (the buffer then holds the loudest
    WIN s); at most one moment a COOL; the day's best are picked later."""
    TALK = 15.0
    MIN = 4.0
    USUAL = 3000
    BASE = 300
    WIN = 150
    COOL = 300
    HOLD = 20

    def __init__(self):
        self.hist = collections.deque(maxlen=1200)
        self.talk = collections.deque(maxlen=self.USUAL)
        self.usual = None
        self.win = collections.deque(maxlen=self.WIN)
        self.floor = None
        self.n = 0
        self.quiet = 0
        self.best = None
        self.held = 0

    def feed(self, db):
        self.hist.append(db)
        self.n += 1
        if self.floor is None or self.n % 10 == 0:
            self.floor = sorted(self.hist)[len(self.hist) // 10]
            if len(self.talk) >= self.BASE:
                self.usual = sorted(self.talk)[len(self.talk) // 2]
        talking = db > self.floor + self.TALK
        if talking:
            self.talk.append(db)
        self.win.append(max(0.0, db - self.usual) if talking and self.usual is not None else 0.0)
        self.quiet -= 1
        if self.quiet > 0 or len(self.win) < self.WIN:
            return None
        score = sum(self.win) / self.WIN
        if self.best is None and score < self.MIN:
            return None
        if self.best is None or score > self.best + 0.5:
            self.best, self.held = max(score, self.best or 0), 0
            return None
        self.held += 1
        if self.held < self.HOLD:
            return None
        out, self.best, self.quiet = round(self.best, 1), None, self.COOL
        return out


def listen(source=""):
    cmd = ["pw-record", "--raw", "--channels", "1", "--format", "s16", "--rate", "16000", "--latency", "100ms",
           "-P", "{ node.name = angelos-moments node.description = \"angelOS moments\" node.passive = true }"]
    p = subprocess.Popen(cmd + (["--target", source] if source else []) + ["-"], stdout=subprocess.PIPE)
    v = Voice()
    while True:
        b = p.stdout.read(3200)
        if len(b) < 3200:
            say(error="the mic's capture ended")
            return 2
        a = array.array("h", b)
        rms = math.sqrt(sum(x * x for x in a) / len(a))
        s = v.feed(20 * math.log10(max(rms, 1) / 32768))
        if s is not None:
            say(voice=s)


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
    n = res[0]["frames"]
    # a day with moments: the intro + two clips with sound, the third (worst) one left out
    d = os.path.join(frames, "2026-10-19")
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=size=320x180:rate=1:duration=600",
                    "-c:v", "libx264", os.path.join(d + "-src.mkv")], check=True)
    os.makedirs(d)
    shutil.move(d + "-src.mkv", os.path.join(d, "090000.mkv"))
    clips = os.path.join(t, "in")
    os.makedirs(clips)
    for i, (sec, sc) in enumerate([(5, 9.0), (4, 2.0), (6, 7.5)]):
        c = os.path.join(clips, "%d.mp4" % i)
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=size=640x360:rate=30:duration=%d" % sec,
                        "-f", "lavfi", "-i", "sine=duration=%d" % sec, "-c:v", "libx264", "-c:a", "aac", "-shortest", c], check=True)
        moment(c, sc, frames, keep=2)
    mdir = os.path.join(frames, datetime.date.today().isoformat(), "moments")
    assert sorted(score_of(f) for f in os.listdir(mdir)) == [7.5, 9.0], os.listdir(mdir)
    shutil.move(mdir, os.path.join(d, "moments"))
    for f in os.listdir(os.path.join(d, "moments")):    # one an hour apart, so the order is by time
        os.rename(os.path.join(d, "moments", f), os.path.join(d, "moments", ("1%d0000" % (score_of(f) > 8)) + f[6:]))
    lines.clear()
    sys.stdout.write = lambda s: lines.append(s) or len(s)
    try:
        build(frames, "2026-10-19", out)
    finally:
        sys.stdout.write = real
    video = os.path.join(out, "Таймлапс 2026-10-19.mp4")
    dur, sound = probe(video)
    # 600 s / 30 s = 20 frames at 24 fps ≈ 0.8 s intro (shorter than INTRO, kept) + 5 s + 6 s
    assert sound and 11 <= dur <= 13.5, (dur, sound, lines)
    # the voice: a quiet room, 5 minutes of talking as usual (nothing), then a shout — one moment
    v = Voice()
    got = [v.feed(-60.0) for _ in range(1200)]
    got += [v.feed((-30.0 + (i * 37 % 7) - 3) if i % 10 < 6 else -58.0) for i in range(3000)]
    assert not any(got), [g for g in got if g]
    got = [v.feed(-17.0 if i % 10 < 7 else -58.0) for i in range(400)]
    hits = [g for g in got if g]
    assert len(hits) == 1 and hits[0] > 6, hits
    assert words("ахахаха ору, смотри чат") == 8 and words("ну короче да") == 0
    shutil.rmtree(t)
    print("timelapse ok (%d frames from 10 min; moments %.1f s with sound)" % (n, dur))


def main():
    a = sys.argv[1:]
    if a[:1] == ["--self-test"]:
        return self_test()
    if a[:1] == ["build"] and len(a) >= 4:
        step = int(a[a.index("--step") + 1]) if "--step" in a else STEP
        return build(os.path.expanduser(a[1]), a[2], os.path.expanduser(a[3]), keep="--keep" in a, step=step)
    if a[:1] == ["listen"]:
        return listen(a[1] if len(a) > 1 else "")
    if a[:1] == ["moment"] and len(a) == 4:
        return moment(a[1], float(a[2]), os.path.expanduser(a[3]))
    if a[:1] == ["tidy"] and len(a) == 3:
        return tidy(os.path.expanduser(a[1]), os.path.expanduser(a[2]))
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
