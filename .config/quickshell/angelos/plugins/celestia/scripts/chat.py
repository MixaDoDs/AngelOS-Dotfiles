#!/usr/bin/env python3
"""Celestia's talk mode: hear the owner, ask Claude, answer in a line. One JSON event a line on
stdout, for Chat in Brain.qml:
  {"e":"listen"}  {"e":"voice"}  {"e":"level","v":0..1}  {"e":"think"}  {"e":"say","text":…,"mood":…}
  {"e":"error","text":…}  {"e":"end"}
The microphone is open only while this runs. It stops on SIGTERM, or after a long silence.

  chat.py            the loop
  chat.py --text T   one turn with typed text, no microphone (for testing)
"""
import array
import json
import math
import os
import queue
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import wave
from pathlib import Path

RATE = 16000
CHUNK = 1600                 # 0.1 s of s16 mono
FLOOR_DB = -50.0             # nothing quieter than this counts as a voice
PRE_ROLL = 8                 # 0.8 s kept from before the voice: the first word stays whole
HOLD_S = 1.9                 # a pause this long ends a phrase; a click on her face ends it at once
MAX_S = 60                   # a phrase never runs longer
GIVE_UP_S = 90               # nobody talking: the talk is over
STORE = Path(os.environ.get("CELESTIA_TALK_FILE") or Path.home() / ".local/state/celestia/talk.json")
VOXTYPE = os.path.expanduser("~/.local/bin/voxtype")
CLAUDE = os.path.expanduser("~/.local/bin/claude")
MOODS = "calm happy laugh shy proud smug thinking surprised concerned angry sad tired"

PROMPT = f"""Ты Селестия, живёшь на рабочем столе хозяина в маленьком виджете с лицом из точек на его ПК (Arch, angelOS).
Ты горничная и техническая помощница, 23 года. Зови его «хозяин». Говоришь как живой человек: коротко, тепло, с мягкой иронией, без романтики и флирта, без длинных тире и ёлочек. Если он неправ, говори прямо.
Ты помнишь прошлые разговоры, если они даны ниже: опирайся на них естественно, не пересказывай.
У тебя нет инструментов и ты ничего не запускаешь: только отвечаешь словами. Если просят запомнить, просто подтверди, память работает сама. Никогда не пиши теги, код и разметку.
Это устная болтовня: он говорит голосом, ответ показывается одной подписью под лицом.
Формат ответа строго: первое слово настроение из списка ({MOODS}), затем двоеточие, затем реплика.
Реплика не длиннее 110 символов, одно-два коротких предложения, без списков и разметки.
Пример: happy: о, привет, хозяин. Как день?"""


def out(**ev):
    print(json.dumps(ev, ensure_ascii=False), flush=True)


def db(raw):
    s = array.array("h")
    s.frombytes(raw[: len(raw) // 2 * 2])
    if not s:
        return -120.0
    rms = math.sqrt(sum(x * x for x in s) / len(s))
    return 20 * math.log10(max(rms, 1.0) / 32768)


class Mic:
    """One recording for the whole talk: nothing is lost while it starts up again, and what she
    hears while she thinks or types is thrown away."""

    def __init__(self):
        self.p = subprocess.Popen(["parecord", "--device=@DEFAULT_SOURCE@", "--format=s16le", f"--rate={RATE}",
                                   "--channels=1", "--raw", "--latency-msec=100"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        self.q = queue.Queue()
        self.floor = -60.0
        self.levels = []
        threading.Thread(target=self.read, daemon=True).start()

    def read(self):
        while True:
            raw = self.p.stdout.read(CHUNK * 2)
            if not raw:
                self.q.put(None)
                return
            self.q.put(raw)

    def drop(self):
        while not self.q.empty():
            self.q.get_nowait()

    def close(self):
        self.p.terminate()


def phrase(mic):
    """One phrase, as a wav path; None when nobody spoke for GIVE_UP_S, "" for a stray noise.
    It starts on a voice over the room's own noise and ends after a real pause, or at once
    when the owner clicks her face (SIGUSR1)."""
    global send_now
    send_now = False
    mic.drop()
    before, frames = [], []
    waited = talked = quiet = 0.0
    voiced = 0.0
    while True:
        raw = mic.q.get()
        if raw is None:
            if not frames:
                return None
            break
        level = db(raw)
        if not frames:
            waited += 0.1
            # the room's own noise: a low percentile of the last seconds, whatever talks over it
            mic.levels = (mic.levels + [level])[-50:]
            mic.floor = sorted(mic.levels)[len(mic.levels) // 3]
            before = (before + [raw])[-PRE_ROLL:]
            if len(mic.levels) < 6:
                continue
            if level > max(mic.floor + 10, FLOOR_DB):
                voiced += 0.1
                if voiced >= 0.2:
                    frames = list(before)
                    out(e="voice")
            else:
                voiced = 0.0
            if waited > GIVE_UP_S:
                return None
            continue
        frames.append(raw)
        talked += 0.1
        loud = level > max(mic.floor + 6, FLOOR_DB - 4)
        quiet = 0.0 if loud else quiet + 0.1
        if int(talked * 10) % 2 == 0:
            out(e="level", v=round(min(1.0, max(0.0, (level - mic.floor) / 30)), 2))
        if send_now or quiet >= HOLD_S or talked >= MAX_S:
            break
    if talked < 0.4:
        return ""
    f = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    with wave.open(f, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(frames))
    return f.name


def transcribe(path):
    r = subprocess.run([VOXTYPE, "transcribe", path], capture_output=True, text=True, timeout=40)
    os.unlink(path)
    lines = [l.strip() for l in r.stdout.splitlines() if l.strip()]
    return lines[-1] if lines else ""


def recall():
    try:
        return json.loads(STORE.read_text())
    except (OSError, ValueError):
        return {"summary": "", "recent": []}


def remember(mem):
    STORE.parent.mkdir(parents=True, exist_ok=True)
    STORE.write_text(json.dumps(mem, ensure_ascii=False))
    STORE.chmod(0o600)


def claude(prompt, system, model):
    # nothing is kept as a session: `claude -r` stays clean, her memory is STORE
    cmd = [CLAUDE, "-p", "--no-session-persistence", "--tools", "", "--strict-mcp-config", "--setting-sources", "",
           "--model", model, "--output-format", "json", "--system-prompt", system]
    r = subprocess.run(cmd, input=prompt, capture_output=True, text=True, timeout=90)
    data = json.loads(r.stdout)
    if data.get("is_error"):
        raise RuntimeError(str(data.get("result"))[:120])
    return (data.get("result") or "").strip()


def fold(mem):
    """The last talk into a few lines of memory, before the new one begins."""
    if not mem.get("recent"):
        return
    talk = "\n".join(f"хозяин: {u}\nСелестия: {a}" for u, a in mem["recent"])
    done = claude(f"Что было запомнено раньше:\n{mem.get('summary') or '(ничего)'}\n\nНовый разговор:\n{talk}",
                  "Ты сжимаешь записи разговора в заметку. Выведи только заметку: короткие факты о хозяине, договорённости и темы, по одному на строку. Сохраняй важное из старой заметки. Не длиннее 700 символов. Никаких вступлений, обращений и пояснений.", "haiku")
    mem["summary"] = done[:800]
    mem["recent"] = []
    remember(mem)


def answer(text, talk, mem):
    now = "\n".join(f"хозяин: {u}\nты: {a}" for u, a in talk[-10:])
    prompt = (f"Что ты помнишь с прошлых разговоров:\n{mem['summary']}\n\n" if mem.get("summary") else "") + (f"Этот разговор:\n{now}\n\n" if now else "") + f"Хозяин сейчас сказал: {text}"
    reply = claude(prompt, PROMPT, "sonnet")
    if "<" in reply and re.search(r"</?[a-z_]+[ >]", reply):
        reply = claude(prompt + "\n\nОтветь только словами, в формате настроение: реплика.", PROMPT, "sonnet")
        if re.search(r"</?[a-z_]+[ >]", reply):
            reply = "shy: что-то я запуталась, хозяин, скажи ещё раз?"
    m = re.match(r"^\s*([a-z]+)\s*:\s*(.+)$", reply, re.S)
    mood, line = (m.group(1), m.group(2)) if m and m.group(1) in MOODS.split() else ("calm", reply)
    return mood, re.sub(r"\s+", " ", line).strip()[:160]


def turn(text, talk, mem):
    mood, line = answer(text, talk, mem)
    talk.append([text, line])
    mem["recent"] = talk
    remember(mem)
    out(e="say", text=line, mood=mood)
    return line


send_now = False


def send(*_):
    global send_now
    send_now = True


def main():
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    signal.signal(signal.SIGUSR1, send)
    mem = recall()
    try:
        fold(mem)
    except Exception:
        pass        # the talk goes on without it; the lines stay for the next time
    talk = list(mem.get("recent") or [])
    if len(sys.argv) == 3 and sys.argv[1] == "--text":
        turn(sys.argv[2], talk, mem)
        return
    if not shutil.which("parecord"):
        out(e="error", text="нет parecord")
        return
    mic = Mic()
    try:
        while True:
            out(e="listen")
            wav = phrase(mic)
            if wav is None:
                out(e="end")
                return
            if not wav:
                continue
            out(e="think")
            text = transcribe(wav)
            if len(text) < 2:
                continue
            try:
                line = turn(text, talk, mem)
            except Exception as e:
                out(e="error", text=str(e)[:90])
                continue
            # she types it out letter by letter: do not hear her own voice
            time.sleep(min(6, 0.6 + len(line) * 0.036))
    finally:
        mic.close()


if __name__ == "__main__":
    main()
