#!/usr/bin/env python3
"""fastfetch's picture, moving for a moment (Settings → System → fastfetch → Animation).

  fastfetch --pipe false | fastfetch_anim.py SPEC
      prints what fastfetch printed, then moves its picture in place for the spec's seconds
      and leaves it exactly as it was: the same half-block pixels, only alive — wings flap, the
      halo bobs, a glint runs over it, sparkles come and go, the heart beats, she talks and
      blinks; in hell flames flicker and embers rise. The receipt first comes out of the
      till line by line. Any key stops it (the key stays for the shell); nothing moves where
      the terminal can't show all of it at once.
  fastfetch_anim.py --patches SPEC
      the frames for Settings' preview, as JSON: [{"ms", "lines": [[line, col, runs], …]}, …]
      — only the lines that differ from the still picture (runs as fastfetch_style's preview)

The spec is written by scripts/fastfetch_style.py next to the config (angelos-anim.json; in
hell terminal-hell.py's fastfetch-anim.json): {"seconds", "print", "layers": [{"rows", "pal",
"line", "col", "k" (the scale), "bg", "fx", "frames"}], "texts": [{"line", "col", "every",
"on", "off"}]}. The fish function in ~/.config/fish/conf.d/angelos-fastfetch.fish pipes
fastfetch through this when it greets a new terminal.
"""
import json
import math
import os
from pathlib import Path
import random
import select
import signal
import sys
import time

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fastfetch_style as fs  # noqa: E402

FPS = 15
WHITE = "#ffffff"


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    ra, rb = fs.rgb(a), fs.rgb(b)
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(ra, rb))


def heartbeat(t):
    """lub-dub every 1.1 s: 0 … 1"""
    p = t % 1.1
    return max(math.exp(-((p - 0.05) / 0.06) ** 2), 0.7 * math.exp(-((p - 0.27) / 0.06) ** 2))


class Layer:
    def __init__(self, d, seconds, seed):
        self.line, self.col, self.k = d["line"], d["col"], d.get("k", 1)
        self.bg, self.pal, self.fx = d.get("bg"), d["pal"], d.get("fx") or {}
        self.rows = {"up": d["rows"], **(d.get("frames") or {})}
        self.keys = {n: fs.scaled([r.ljust(max(map(len, rows)), ".") for r in rows], self.k) for n, rows in self.rows.items()}
        self.base = self.paint("up")
        self.h, self.w = len(self.base), len(self.base[0]) if self.base else 0
        rnd = random.Random(seed)

        def empty(x, y):
            return 0 <= y < self.h and 0 <= x < self.w and self.base[y][x] in (None, self.bg)
        # sparkles: in empty space (a free 3 × 3); embers: rising from the picture's lower half
        spots = [(x, y) for y in range(1, self.h - 1) for x in range(1, self.w - 1)
                 if all(empty(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1))]
        self.sparks, self.embers = [], []
        n = self.fx.get("sparkles", 0)
        if n and spots:
            t = rnd.uniform(0.05, 0.3)
            while t < seconds - 0.5:
                self.sparks.append((t, *rnd.choice(spots)))
                t += rnd.uniform(0.5, 0.9) / n
        n = self.fx.get("embers", 0)
        cols = [x for x in range(self.w) if any(self.base[y][x] not in (None, self.bg) for y in range(self.h))]
        if n and cols:
            t = rnd.uniform(0.0, 0.2)
            while t < seconds - 0.6:
                x = rnd.choice(cols)
                ys = [y for y in range(self.h) if self.base[y][x] not in (None, self.bg)]
                self.embers.append((t, x, ys[-1] if ys and rnd.random() < 0.5 else rnd.randrange(self.h // 2, self.h)))
                t += rnd.uniform(0.35, 0.7) / n

    def paint(self, frame):
        return [[self.bg if ch in ". " else self.pal.get(ch, self.bg) for ch in r] for r in self.keys[frame]]

    def scaled_box(self, box):
        x0, x1, y0, y1 = box
        k = self.k
        return x0 * k, (x1 + 1) * k - 1, y0 * k, (y1 + 1) * k - 1

    def shift(self, g, box, dy):
        """move the pixels in the box dy pixels down (up when negative)"""
        x0, x1, y0, y1 = self.scaled_box(box)
        if not dy:
            return
        part = [[g[y][x] for x in range(x0, x1 + 1)] for y in range(y0, y1 + 1)]
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                g[y][x] = self.bg
        for i, row in enumerate(part):
            y = y0 + i + dy
            if 0 <= y < self.h:
                for j, c in enumerate(row):
                    if c not in (None, self.bg):
                        g[y][x0 + j] = c

    def frame_name(self, t):
        if "talk" not in self.rows:
            return "up"
        # she says hi, flaps twice, blinks
        p = t % 2.6
        if p < 0.9:
            return "talk" if int(p / 0.15) % 2 == 0 else "up"
        if p < 1.8:
            return "down" if int((p - 0.9) / 0.15) % 2 == 0 else "up"
        if 2.1 <= p < 2.25:
            return "blink"
        return "up"

    def grid(self, t):
        if t is None:
            return [row[:] for row in self.base]
        fx, bg = self.fx, self.bg
        name = self.frame_name(t)
        keys = self.keys[name]
        g = self.paint(name)
        filled = lambda c: c not in (None, bg)  # noqa: E731
        tick = int(t * 10)
        for y in range(self.h):
            for x in range(self.w):
                ch = keys[y][x]
                if ch in fx.get("pulse", ()):
                    g[y][x] = mix(g[y][x], WHITE, 0.45 * heartbeat(t))
                elif ch in fx.get("cycle", ()):
                    cyc = fx["cycle"]
                    g[y][x] = self.pal.get(cyc[(cyc.index(ch) + int(t / 0.12)) % len(cyc)], g[y][x])
                elif ch in fx.get("flicker", ()):
                    n = ((x // self.k) * 73856093 ^ (y // self.k) * 19349663 ^ tick * 83492791) % 1000 / 1000
                    g[y][x] = mix(g[y][x], WHITE if n > 0.5 else "#000000", abs(n - 0.5) * 0.7)
                elif ch in fx.get("twinkle", ()):
                    if math.sin(t * 2 * math.pi / 0.9 + (x // 6) * 1.7 + (y // 6) * 2.3) < -0.35:
                        g[y][x] = bg
        for box in fx.get("flap", ()):
            self.shift(g, box, -1 if t % 0.4 < 0.2 else 0)
        if fx.get("halo"):
            self.shift(g, fx["halo"], 1 if math.sin(t * 2 * math.pi / 1.2) > 0.3 else 0)
        if fx.get("glint"):
            # a diagonal band of light every 2.4 s
            p = t % 2.4 - 0.3
            if 0 <= p < 0.7:
                pos = p / 0.7 * (self.w + self.h + 8) - 6
                for y in range(self.h):
                    for x in range(self.w):
                        if filled(g[y][x]) and 0 <= x + y - pos < 4:
                            g[y][x] = mix(g[y][x], WHITE, 0.6)
        arm, core = (fx.get("spark") or ["#c9b6ff", WHITE])[:2]
        for t0, x, y in self.sparks:
            s = (t - t0) / 0.6
            if 0 <= s < 1:
                if 0.3 <= s < 0.7:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        g[y + dy][x + dx] = arm
                    g[y][x] = core
                else:
                    g[y][x] = mix(arm, core, 0.3)
        hot, cold = (fx.get("ember") or ["#ffb347", "#a01818"])[:2]
        for t0, x, y0 in self.embers:
            s = (t - t0) / 0.9
            y = y0 - int((t - t0) / 0.07)
            if 0 <= s < 1 and 0 <= y < self.h and not filled(g[y][x]):
                g[y][x] = mix(hot, cold, s)
        return g

    def lines(self, t):
        """[(line, col, text)] of the picture at t (None: as fastfetch printed it)"""
        out, _ = fs.blocks(self.grid(t), self.bg)
        return [(self.line + i, self.col, text) for i, text in enumerate(out)]


class Anim:
    def __init__(self, spec):
        self.seconds = float(spec.get("seconds", 0))
        self.layers = [Layer(d, self.seconds, i * 31 + 7) for i, d in enumerate(spec.get("layers", []))]
        self.texts = spec.get("texts", [])

    def at(self, t):
        out = []
        for layer in self.layers:
            out += layer.lines(t)
        for d in self.texts:
            out.append((d["line"], d["col"], d["on"] if t is None or int(t / d.get("every", 0.5)) % 2 == 0 else d["off"]))
        return out

    def extent(self):
        """(last line, last column) the moving parts reach"""
        lines = self.at(None)
        return (max((l for l, _, _ in lines), default=0),
                max((c + len(fs.CSI.sub("", text)) for _, c, text in lines), default=0))


def patches(spec, fps=10, seconds=3.0):
    anim = Anim(dict(spec, seconds=seconds))
    still = {(l, c): text for l, c, text in anim.at(None)}
    out = []

    def runs(text):
        # the whole width: blank cells at the end too (they cover what the still picture has there)
        r = (fs.terminal(text)["lines"] or [[]])[0]
        gap = len(fs.CSI.sub("", text)) - sum(len(x[0]) for x in r)
        return r + [[" " * gap, None, None, False]] if gap > 0 else r
    for i in range(int(seconds * fps)):
        diff = [[l, c, runs(text)] for l, c, text in anim.at(i / fps) if still.get((l, c)) != text]
        out.append({"ms": round(1000 / fps), "lines": diff})
    return out


def play(spec, data):
    out = sys.stdout.buffer

    def put(s):
        out.write(s.encode())
        out.flush()
    tty = None
    try:
        tty = os.open("/dev/tty", os.O_RDWR | os.O_NOCTTY)
    except OSError:
        pass
    anim = Anim(spec) if spec else None
    try:
        size = os.get_terminal_size(out.fileno())
    except OSError:
        size = None
    n = data.count("\n")
    ok = bool(anim and anim.seconds > 0 and size and tty is not None and os.isatty(out.fileno()))
    if ok:
        last_line, last_col = anim.extent()
        ok = n < size.lines and last_line <= n and last_col < size.columns and fs.terminal(data)["cols"] <= size.columns
    if not ok:
        put(data)
        return
    import termios
    old = termios.tcgetattr(tty)
    new = termios.tcgetattr(tty)
    new[3] &= ~(termios.ECHO | termios.ICANON)
    new[6][termios.VMIN], new[6][termios.VTIME] = 0, 0
    stop = {"now": False}

    def quit_(*_):
        raise KeyboardInterrupt
    signal.signal(signal.SIGWINCH, lambda *_: stop.update(now=True))
    for sig in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, quit_)

    def key():
        # a key pressed: stop (it isn't read, so the shell gets it)
        return stop["now"] or bool(select.select([tty], [], [], 0)[0])
    try:
        termios.tcsetattr(tty, termios.TCSANOW, new)
        if spec.get("print"):
            for i, line in enumerate(data.splitlines(True)):
                put(line)
                if not key():
                    time.sleep(0.03 if i < n - 1 else 0)
        else:
            put(data)
        put("\x1b[?25l\x1b7")
        shown = {(l, c): text for l, c, text in anim.at(None)}

        def draw(lines):
            buf = ""
            for l, c, text in lines:
                if shown.get((l, c)) != text:
                    shown[(l, c)] = text
                    buf += "\x1b8" + ("\x1b[%dA" % (n - l) if n - l else "") + "\r" + ("\x1b[%dC" % c if c else "") + text
            if buf:
                put(buf + "\x1b8")
        start = time.monotonic()
        while not key():
            t = time.monotonic() - start
            if t >= anim.seconds:
                break
            draw(anim.at(t))
            time.sleep(max(0.0, 1 / FPS - (time.monotonic() - start - t)))
        if not stop["now"]:
            draw(anim.at(None))
    except KeyboardInterrupt:
        if not stop["now"]:
            try:
                draw(anim.at(None))
            except Exception:
                pass
    finally:
        put("\x1b8\x1b[?25h")
        termios.tcsetattr(tty, termios.TCSANOW, old)
        os.close(tty)


def main():
    args = sys.argv[1:]
    if args[:1] == ["--patches"]:
        spec = json.loads(Path(args[1]).read_text())
        print(json.dumps(patches(spec), ensure_ascii=False))
        return 0
    data = sys.stdin.buffer.read().decode("utf-8", "replace")
    try:
        spec = json.loads(Path(args[0]).read_text()) if args else None
    except (OSError, ValueError):
        spec = None
    play(spec, data)
    return 0


if __name__ == "__main__":
    sys.exit(main())
