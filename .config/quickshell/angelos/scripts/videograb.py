#!/usr/bin/env python3
"""Video for Discord and from a link (services/VideoGrab). Every command prints JSON lines:
{"ev": "progress", "got": n, "total": n, "file": where it goes} about once a second, then
{"ev": "done", "path": …} or {"ev": "error", "text": …, "update": true when a newer yt-dlp may help}.

  videograb.py shrink FILE [--start S] [--end S] [--mb 20]
      FILE (cut to START…END seconds) squeezed under the limit: "<name> (Discord).mp4" beside it.
      The bitrate is worked out from the length, two passes; h264 (NVENC when there is one, else
      libx264) + AAC, mp4 with +faststart; smaller only when the bitrate would fall under ~1 Mbit/s
  videograb.py estimate FILE [--start S] [--end S] [--mb 20]
      what shrink would make, before it runs: {"ev": "estimate", "fits", "size", "height", "mbit"}
      or, too long, {"fits": false, "max": the longest cut that fits, seconds}
  videograb.py edit FILE [--start S] [--end S]
      for editing (DaVinci Resolve): extras/mediafix — the video as it is, the sound PCM 24 bit /
      48 kHz, ~/Videos/MediaFix/<name>_DR.mov; a cut starts at the key frame at or before START
  videograb.py wav FILE [--start S] [--end S]
      the sound alone, PCM 24 bit / 48 kHz: "<name>.wav" beside it
  videograb.py formats
      the conversion ring's formats (modules/convert): {"kinds": {image|video|audio: [ext…]},
      "formats": {image|video|audio: [{id, label}…]}}
  videograb.py convert FORMAT FILE…
      each FILE into FORMAT (a formats id) in «Сконвертировано» beside it, the originals untouched:
      pictures through ImageMagick, video and sound through ffmpeg (NVENC when there is one); a
      video into a sound format keeps its sound alone. Files of another kind are skipped
  videograb.py sizes KIND FILE…
      what each of KIND's formats would make of these files, before it runs: {"ev": "sizes",
      "now": their bytes, "sizes": {id: bytes (an estimate; pictures: the first one made for real
      and scaled by the pixels)}, "same": [ids every file already is]}
  videograb.py grab URL [--audio] [--dir ~/Downloads]
      one link through yt-dlp, never a playlist or a channel: the best video up to 1080p (or the
      sound alone, m4a) into DIR. No browser cookies
  videograb.py update
      a newer yt-dlp from pacman (-Syu, as the app installer does) with the admin password once
  videograb.py --self-test

Encoding runs at nice 10: the game in front keeps the CPU.
"""
import importlib.util
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
YTDLP = os.environ.get("VIDEOGRAB_YTDLP", "yt-dlp")
RU = (os.environ.get("ANGELOS_LANG") or os.environ.get("LANG") or "en").startswith("ru")


def t(ru, en):
    return ru if RU else en


def say(ev, **data):
    print(json.dumps({"ev": ev} | data, ensure_ascii=False), flush=True)


class Fail(Exception):
    pass


RUNNING = []    # the ffmpeg / yt-dlp now: stopped along with this


def child(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    RUNNING[:] = [p]
    return p


def stop(*_):
    for p in RUNNING:
        p.terminate()
    sys.exit(143)


# ---- shrink ----

def probe(path):
    """{duration, height, audio} of a file, Fail when ffprobe can't read it"""
    try:
        out = subprocess.run(["ffprobe", "-v", "error", "-print_format", "json", "-show_format", "-show_streams", str(path)],
                             capture_output=True, text=True, timeout=30)
    except FileNotFoundError:
        raise Fail(t("нет ffprobe (пакет ffmpeg)", "no ffprobe (the ffmpeg package)"))
    try:
        j = json.loads(out.stdout)
    except ValueError:
        j = {}
    video = [s for s in j.get("streams", []) if s.get("codec_type") == "video" and not (s.get("disposition") or {}).get("attached_pic")]
    if not video:
        raise Fail(t("в файле нет видео", "there is no video in the file"))
    dur = float((j.get("format") or {}).get("duration") or video[0].get("duration") or 0)
    if dur <= 0:
        raise Fail(t("не понять длину видео", "the video's length is unknown"))
    return {"duration": dur, "height": int(video[0].get("height") or 0), "bitrate": int((j.get("format") or {}).get("bit_rate") or 0),
            "audio": any(s.get("codec_type") == "audio" for s in j.get("streams", []))}


def plan(duration, limit_bytes, audio, height, source_bps=0):
    """(video bit/s, audio bit/s, new height or 0): the bits the limit leaves for that length (never
    more than the file has: a small one stays small); a little kept back for the container and the
    encoder's misses"""
    budget = limit_bytes * 8 * 0.94 / duration
    a = 0 if not audio else 128_000 if budget >= 1_000_000 else 64_000
    v = budget - a
    if v < MIN_VIDEO:
        raise Fail(t(f"{round(duration)} с не влезут в {limit_bytes / 1e6:g} МБ — обрежь покороче",
                     f"{round(duration)} s won't fit into {limit_bytes / 1e6:g} MB: cut it shorter"))
    if source_bps:
        v = max(MIN_VIDEO, min(v, source_bps - a))
    want = 0 if v >= 1_000_000 else 720 if v >= 600_000 else 480 if v >= 300_000 else 360
    return int(v), a, want if want and height > want else 0


MIN_VIDEO = 60_000


def longest(limit_bytes, audio):
    """the longest cut, seconds, that still fits the limit"""
    return int(limit_bytes * 8 * 0.94 / (MIN_VIDEO + (64_000 if audio else 0)))


def span(info, start, end):
    start = max(0.0, start or 0)
    end = min(info["duration"], end) if end and end > start else info["duration"]
    if end - start <= 0:
        raise Fail(t("пустой отрезок", "an empty cut"))
    return start, end - start


def estimate(src, start, end, mb):
    info = probe(src)
    start, length = span(info, start, end)
    limit = int(mb * 1_000_000)
    try:
        v, a, height = plan(length, limit, info["audio"], info["height"], info["bitrate"])
    except Fail:
        say("estimate", fits=False, max=longest(limit, info["audio"]), length=length)
        return
    say("estimate", fits=True, size=int((v + a) * length / 8), height=height or info["height"], mbit=round(v / 1e6, 1), length=length)


def edit(src, start, end):
    """extras/mediafix's conversion (the same as Strata's and Nautilus's «Prepare for DaVinci Resolve»)"""
    spec = importlib.util.spec_from_file_location("mediafix", HERE.parent / "extras/mediafix/mediafix.py")
    mf = sys.modules["mediafix"] = importlib.util.module_from_spec(spec)   # its dataclasses look themselves up there
    spec.loader.exec_module(mf)
    src = Path(src).resolve()
    info = mf.run_probe(src)
    cut = None
    if start or end:
        start, length = span({"duration": info.duration or 0}, start, end)
        cut = (start, length)
    # the folder from Settings → Screenshots and recording (capture.mediafixDir), as Strata's item gets it
    try:
        folder = (json.loads((Path.home() / ".config/angelos/settings.json").read_text()).get("capture") or {}).get("mediafixDir")
    except (OSError, ValueError, AttributeError):
        folder = ""
    if folder:
        os.environ["MEDIAFIX_DIR"] = folder
    final = mf.unique_output(src)
    last = [0]

    def update(ratio, speed, done):
        if time.time() - last[0] >= 1:
            last[0] = time.time()
            say("progress", got=round(ratio * 1000), total=1000, file=str(final))
    ok, why = mf.run_conversion(info, final, update, cut)
    if not ok:
        raise Fail("mediafix: " + why)
    say("done", path=str(final), size=final.stat().st_size)


def wav(src, start, end):
    src = Path(src).resolve()
    info = probe(src)
    if not info["audio"]:
        raise Fail(t("в видео нет звука", "the video has no sound"))
    start, length = span(info, start, end)
    out = free_name(src.with_suffix(".wav") if os.access(src.parent, os.W_OK) else Path.home() / "Music" / (src.stem + ".wav"))
    tmp = out.with_name("." + out.name + ".part")
    try:
        ffmpeg(["-ss", f"{start:.3f}", "-t", f"{length:.3f}", "-i", str(src), "-map", "0:a:0", "-vn", "-c:a", "pcm_s24le", "-ar", "48000", "-f", "wav", str(tmp)],
               length, {"file": str(out), "total": 1000}, 0, 1)
        os.replace(tmp, out)
    finally:
        Path(tmp).unlink(missing_ok=True)
    say("done", path=str(out), size=out.stat().st_size)


# ---- convert ----

KINDS = {
    "image": ["png", "jpg", "jpeg", "webp", "avif", "gif", "bmp", "tif", "tiff", "heic", "heif", "ico", "jxl", "tga"],
    "video": ["mp4", "mkv", "webm", "mov", "m4v", "avi", "flv", "ts", "mts", "m2ts", "wmv", "mpg", "mpeg", "3gp", "ogv"],
    "audio": ["mp3", "wav", "flac", "ogg", "opus", "m4a", "aac", "wma", "aiff", "aif", "alac", "mka"],
}
# per kind: (id, label); the id is the extension but for gifv (a video's GIF); a video goes into the
# sound ones too
FORMATS = {
    "image": [("png", "PNG"), ("jpg", "JPG"), ("webp", "WebP"), ("avif", "AVIF"), ("gif", "GIF"), ("ico", "ICO")],
    "video": [("mp4", "MP4"), ("webm", "WebM"), ("mkv", "MKV"), ("gifv", "GIF"), ("discord", "Discord"), ("edit", None)],
    "audio": [("mp3", "MP3"), ("wav", "WAV"), ("flac", "FLAC"), ("ogg", "OGG"), ("m4a", "M4A")],
}


SAME = {"jpeg": "jpg", "tif": "tiff", "oga": "ogg", "opus": "ogg"}


def ext_of(path):
    e = Path(path).suffix.lower().lstrip(".")
    return SAME.get(e, e)


def target_ext(fmt):
    return "gif" if fmt == "gifv" else fmt


def kind_of(path):
    ext = Path(path).suffix.lower().lstrip(".")
    return next((k for k, exts in KINDS.items() if ext in exts), "")


def formats():
    say("formats", kinds=KINDS, formats={k: [{"id": i, "label": l or t("Монтаж", "Editing")} for i, l in v] for k, v in FORMATS.items()})


def converted(src, ext):
    """«Сконвертировано»/<name>.<ext> beside src (the home's Converted when it's read-only)"""
    folder = src.parent / t("Сконвертировано", "Converted")
    try:
        folder.mkdir(exist_ok=True)
    except OSError:
        folder = Path.home() / t("Сконвертировано", "Converted")
        folder.mkdir(exist_ok=True)
    return free_name(folder / f"{src.stem}.{ext}")


def has_audio(src):
    try:
        return probe(src)["audio"]
    except Fail:
        # a sound file: no video stream, probe() refuses it
        return True


def convert_one(kind, fmt, src, show, part, parts):
    """one file into fmt; the made file's path"""
    if kind == "image":
        out = converted(src, fmt)
        frame = "" if fmt in ("gif", "webp") or src.suffix.lower() != ".gif" else "[0]"
        extra = {"jpg": ["-background", "white", "-alpha", "remove", "-quality", "92"],
                 "ico": ["-background", "none", "-resize", "256x256>", "-define", "icon:auto-resize=256,128,64,48,32,16"],
                 "webp": ["-quality", "90"], "avif": ["-quality", "70"]}.get(fmt, [])
        r = subprocess.run(["magick", str(src) + frame] + extra + [str(out)], capture_output=True, text=True)
        if r.returncode:
            out.unlink(missing_ok=True)
            raise Fail("ImageMagick: " + ((r.stderr.strip().splitlines() or ["?"])[-1]))
        return out
    length = probe_length(src)
    if fmt in dict(FORMATS["audio"]):
        if not has_audio(src):
            raise Fail(t(f"в {src.name} нет звука", f"{src.name} has no sound"))
        out = converted(src, fmt)
        codec = {"mp3": ["-c:a", "libmp3lame", "-q:a", "2"], "wav": ["-c:a", "pcm_s16le"], "flac": ["-c:a", "flac"],
                 "ogg": ["-c:a", "libopus", "-b:a", "160k"], "m4a": ["-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart"]}[fmt]
        ffmpeg(["-i", str(src), "-map", "0:a:0", "-vn"] + codec + [str(out)], length, show, part, parts)
        return out
    out = converted(src, "gif" if fmt == "gifv" else fmt)
    sound = ["-map", "0:a?"]
    if fmt == "mkv":
        args = ["-map", "0:v", "-map", "0:a?", "-map", "0:s?", "-c", "copy"]
    elif fmt == "gifv":
        args = ["-map", "0:v:0", "-vf", "fps=15,scale='min(480,iw)':-2:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse", "-loop", "0"]
    elif fmt == "webm":
        v = ["-c:v", "av1_nvenc", "-preset", "p5", "-cq", "32"] if nvenc("av1_nvenc") else \
            ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-row-mt", "1", "-deadline", "good", "-cpu-used", "4"]
        args = ["-map", "0:v:0"] + sound + v + ["-c:a", "libopus", "-b:a", "128k"]
    else:   # mp4
        v = ["-c:v", "h264_nvenc", "-preset", "p5", "-cq", "23"] if nvenc() else ["-c:v", "libx264", "-preset", "medium", "-crf", "20"]
        args = ["-map", "0:v:0"] + sound + v + ["-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"]
    ffmpeg(["-i", str(src)] + args + [str(out)], length, show, part, parts)
    return out


def media(src):
    """{duration, width, height, fps, vbps, audio, channels, rate} for the size estimates"""
    r = subprocess.run(["ffprobe", "-v", "error", "-print_format", "json", "-show_format", "-show_streams", str(src)], capture_output=True, text=True)
    try:
        j = json.loads(r.stdout)
    except ValueError:
        j = {}
    fmt = j.get("format") or {}
    d = {"duration": float(fmt.get("duration") or 0), "width": 0, "height": 0, "fps": 30.0, "vbps": 0, "audio": False, "channels": 2, "rate": 48000}
    total = int(fmt.get("bit_rate") or 0)
    abps = 0
    for st in j.get("streams") or []:
        if st.get("codec_type") == "video" and not (st.get("disposition") or {}).get("attached_pic") and not d["width"]:
            d["width"], d["height"] = int(st.get("width") or 0), int(st.get("height") or 0)
            num, _, den = str(st.get("avg_frame_rate") or "30/1").partition("/")
            try:
                d["fps"] = min(240.0, float(num) / float(den or 1)) or 30.0
            except (ValueError, ZeroDivisionError):
                pass
            d["vbps"] = int(st.get("bit_rate") or 0)
        elif st.get("codec_type") == "audio" and not d["audio"]:
            d["audio"] = True
            d["channels"] = int(st.get("channels") or 2)
            d["rate"] = int(st.get("sample_rate") or 48000)
            abps = int(st.get("bit_rate") or 0)
    if not d["vbps"] and d["width"]:
        d["vbps"] = max(0, total - abps)
    return d


def estimate_one(kind, fmt, src):
    """the bytes fmt would make of src: rules of thumb from the length, the size and the bitrates"""
    size = src.stat().st_size
    m = media(src)
    dur = m["duration"]
    if fmt in dict(FORMATS["audio"]):
        if not m["audio"]:
            return 0
        pcm = m["rate"] * m["channels"] * 2 * dur
        return int({"mp3": 190_000 * dur / 8, "wav": pcm, "flac": pcm * 0.55, "ogg": 160_000 * dur / 8, "m4a": 256_000 * dur / 8}[fmt])
    px = m["width"] * m["height"] * m["fps"]
    sound = (192_000 if m["audio"] else 0) * dur / 8
    if fmt == "mkv":
        return size
    if fmt == "discord":
        return int(min(size, float(os.environ.get("VIDEOGRAB_MB") or 20) * 1_000_000 * 0.94))
    if fmt == "edit":
        return int(m["vbps"] * dur / 8 + 48000 * 3 * m["channels"] * dur)
    if fmt == "gifv":
        w = min(480, m["width"] or 480)
        h = (m["height"] or 270) * w / max(1, m["width"] or 480)
        return int(w * h * 15 * dur * 0.15)
    # h264 at cq 23 ~0.07 bits a pixel, AV1 at cq 32 about half; never much over the source
    bpp = 0.035 if fmt == "webm" else 0.07
    v = px * bpp
    if m["vbps"]:
        v = min(v, m["vbps"] * (0.8 if fmt == "webm" else 1.1))
    return int(v * dur / 8 + sound * (128 / 192 if fmt == "webm" else 1))


def pixels(src):
    r = subprocess.run(["magick", "identify", "-format", "%w %h\n", str(src)], capture_output=True, text=True)
    try:
        w, h = r.stdout.split()[:2]
        return int(w) * int(h)
    except ValueError:
        return 0


def sizes(kind, files):
    takes = {"image": ("image",), "video": ("video",), "audio": ("audio", "video")}[kind]
    todo = [Path(f).resolve() for f in files if kind_of(f) in takes and Path(f).is_file()]
    now = sum(f.stat().st_size for f in todo)
    same = [i for i, _ in FORMATS[kind] if todo and i not in ("discord", "edit") and all(ext_of(f) == target_ext(i) for f in todo)]
    est = {}
    if kind == "image" and todo:
        # the first picture made for real in every format, scaled by everyone's pixels
        first = todo[0]
        scale = sum(pixels(f) for f in todo) / max(1, pixels(first))
        tmp = Path(tempfile.mkdtemp(prefix="angelos-sizes-"))
        try:
            for i, _ in FORMATS["image"]:
                try:
                    shutil.copy(first, tmp / first.name)
                    out = convert_one("image", i, tmp / first.name, None, 0, 1)
                    est[i] = int(out.stat().st_size * scale)
                except (Fail, OSError):
                    pass
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    else:
        for i, _ in FORMATS[kind]:
            est[i] = sum(estimate_one(kind_of(f), i, f) for f in todo)
    say("sizes", now=now, sizes=est, same=same)


def probe_length(src):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(src)], capture_output=True, text=True)
    try:
        return max(0.1, float(r.stdout.strip()))
    except ValueError:
        return 1.0


def convert(fmt, files):
    """FORMAT for each file it fits: a picture format for pictures, a video one for videos, a
    sound one for sounds and videos; a JSON «done» per file made, one «error» per file failed"""
    kind = next((k for k, v in FORMATS.items() if fmt in dict(v)), "")
    if not kind:
        raise Fail(t(f"нет формата {fmt}", f"no format {fmt}"))
    takes = {"image": ("image",), "video": ("video",), "audio": ("audio", "video")}[kind]
    todo = [Path(f).resolve() for f in files if kind_of(f) in takes and Path(f).is_file()]
    if fmt not in ("discord", "edit"):
        todo = [f for f in todo if ext_of(f) != target_ext(fmt)]     # already that: nothing to do
    if not todo:
        raise Fail(t("подходящих файлов нет (или они уже в этом формате)", "no files of that kind (or they are that format already)"))
    failed = []
    for i, src in enumerate(todo):
        show = {"file": str(src.parent / t("Сконвертировано", "Converted") / f"{src.stem}.{'gif' if fmt == 'gifv' else fmt}"), "total": 1000 * len(todo)}
        say("progress", got=1000 * i, total=show["total"], file=show["file"])
        try:
            if fmt == "discord":
                shrink(src, 0, 0, float(os.environ.get("VIDEOGRAB_MB") or 20))
                continue
            if fmt == "edit":
                edit(src, 0, 0)
                continue
            out = convert_one(kind_of(src) if kind != "audio" else "audio", fmt, src, show, i, len(todo))
            say("done", path=str(out), size=out.stat().st_size)
        except Fail as e:
            failed.append(f"{src.name}: {e.args[0]}")
    if failed:
        raise Fail("\n".join(failed))


def nvenc(codec="h264_nvenc"):
    """h264_nvenc that really opens (listed is not enough: no NVIDIA card, no driver)"""
    if os.environ.get("VIDEOGRAB_NVENC") == "0":
        return False
    try:
        return subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=s=256x256:d=0.1", "-c:v", codec, "-f", "null", "-"],
                              capture_output=True, timeout=20).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def ffmpeg(args, length, show, part, parts):
    """one ffmpeg run, its progress as part of parts; Fail with its last words"""
    p = child(["ffmpeg", "-v", "error", "-y", "-nostats", "-progress", "pipe:1"] + args)
    last = 0
    for line in p.stdout:
        if line.startswith("out_time_us=") and line[12:].strip().isdigit() and time.time() - last >= 1:
            last = time.time()
            f = (part + min(1, int(line[12:]) / 1e6 / length)) / parts
            say("progress", got=round(f * show["total"]), total=show["total"], file=show["file"])
    err = p.stderr.read()
    if p.wait():
        raise Fail("ffmpeg: " + (err.strip().splitlines() or ["?"])[-1])


def free_name(path):
    """path, or «name (2).ext» beside it when that is taken"""
    path = Path(path)
    n = 2
    while path.exists():
        path = path.with_name(re.sub(r"( \(\d+\))?(\.[^.]*)$", f" ({n})\\2", path.name))
        n += 1
    return path


def shrink(src, start, end, mb):
    src = Path(src).resolve()
    info = probe(src)
    start, length = span(info, start, end)
    limit = int(mb * 1_000_000)
    v, a, height = plan(length, limit, info["audio"], info["height"], info["bitrate"])
    out = src.with_name(src.stem + " (Discord).mp4")
    if out == src or not os.access(src.parent, os.W_OK):
        out = Path(os.environ.get("XDG_VIDEOS_DIR") or Path.home() / "Videos") / out.name
    out = free_name(out)
    show = {"file": str(out), "total": limit}
    gpu = nvenc()
    tmp = Path(tempfile.mkdtemp(prefix="angelos-videograb-"))
    try:
        cut = ["-ss", f"{start:.3f}", "-t", f"{length:.3f}", "-i", str(src)]
        vf = ["-vf", f"scale=-2:{height}"] if height else []
        sound = ["-map", "0:a:0", "-c:a", "aac", "-b:a", str(a), "-ac", "2"] if a else ["-an"]
        tail = ["-pix_fmt", "yuv420p", "-movflags", "+faststart", str(tmp / "out.mp4")]
        for _ in range(3):
            if gpu:
                # NVENC's two passes go in one run (multipass)
                ffmpeg(cut + ["-map", "0:v:0"] + vf + ["-c:v", "h264_nvenc", "-preset", "p5", "-tune", "hq", "-rc", "vbr", "-multipass", "fullres",
                              "-b:v", str(v), "-maxrate", str(int(v * 1.5)), "-bufsize", str(v * 2)] + sound + tail, length, show, 0, 1)
            else:
                x264 = ["-map", "0:v:0"] + vf + ["-c:v", "libx264", "-preset", "medium", "-b:v", str(v), "-passlogfile", str(tmp / "pass")]
                ffmpeg(cut + x264 + ["-pass", "1", "-an", "-f", "null", os.devnull], length, show, 0, 2)
                ffmpeg(cut + x264 + ["-pass", "2", "-maxrate", str(int(v * 1.5)), "-bufsize", str(v * 2)] + sound + tail, length, show, 1, 2)
            size = (tmp / "out.mp4").stat().st_size
            if size <= limit:
                break
            # the encoder overshot: the next try a little under
            v = int(v * limit / size * 0.92)
        else:
            raise Fail(t(f"не вышло ужать до {mb:g} МБ", f"could not squeeze it under {mb:g} MB"))
        shutil.move(str(tmp / "out.mp4"), out)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    say("done", path=str(out), size=out.stat().st_size, nvenc=gpu)


# ---- grab ----

PROGRESS = "download:[vg] %(progress.downloaded_bytes)s %(progress.total_bytes)s %(progress.total_bytes_estimate)s %(info.title)s"


class Progress:
    """yt-dlp's lines → bytes so far of all its parts (a video and its sound come one after the other)"""

    def __init__(self):
        self.base = 0       # the parts done
        self.got = 0
        self.total = 0

    def line(self, line):
        """(got, total, title) of a progress line, None for any other"""
        if not line.startswith("[vg] "):
            return None
        bits = line[5:].rstrip("\n").split(" ", 3)
        if len(bits) < 3:
            return None
        num = lambda s: int(float(s)) if re.fullmatch(r"[\d.]+", s) else 0
        got, total = num(bits[0]), num(bits[1]) or num(bits[2])
        if got < self.got:
            self.base += max(self.total, self.got)
        self.got, self.total = got, total
        return self.base + got, self.base + max(total, got), bits[3] if len(bits) > 3 else ""


def grab(url, audio, dest):
    if not re.match(r"https?://", url):
        raise Fail(t("это не ссылка", "that is not a link"))
    if not shutil.which(YTDLP):
        raise Fail(t("нет yt-dlp (его ставит установщик: packages/tools.txt)", "no yt-dlp (the installer puts it in: packages/tools.txt)"))
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    # a hidden folder beside: services/Downloads sees only the finished file come in
    tmp = Path(tempfile.mkdtemp(prefix=".angelos-grab-", dir=dest))
    ext = "m4a" if audio else "mp4"
    how = ["-f", "ba[ext=m4a]/ba", "-x", "--audio-format", "m4a"] if audio else \
          ["-f", "bv*+ba/b", "-S", "res:1080,vcodec:h264,acodec:aac,ext:mp4:m4a", "--merge-output-format", "mp4"]
    cmd = [YTDLP, "--no-playlist", "--newline", "--quiet", "--progress", "--no-mtime", "--progress-template", PROGRESS,
           "--print", "after_move:[vg-file] %(filepath)s", "--no-simulate", "-P", str(tmp), "-o", "%(title).150B [%(id)s].%(ext)s"] + how + ["--", url]
    try:
        p = child(cmd)
        prog, got, last = Progress(), None, 0
        for line in p.stdout:
            if line.startswith("[vg-file] "):
                got = line[10:].strip()
                continue
            r = prog.line(line)
            if r and (time.time() - last >= 1 or r[0] >= r[1] > 0):
                last = time.time()
                say("progress", got=r[0], total=r[1], file=str(dest / f"{(r[2] or 'video').replace('/', '_')}.{ext}"))
        err = p.stderr.read()
        if p.wait():
            lines = [l[7:] if l.startswith("ERROR: ") else l for l in err.strip().splitlines() if l.startswith("ERROR")]
            raise Fail("yt-dlp: " + ("\n".join(lines) or (err.strip().splitlines() or ["?"])[-1]), True)
        files = [Path(got)] if got and Path(got).is_file() else sorted((f for f in tmp.iterdir() if f.is_file()), key=lambda f: f.stat().st_size)[-1:]
        if not files:
            raise Fail(t("yt-dlp ничего не скачал", "yt-dlp downloaded nothing"))
        out = free_name(dest / files[0].name)
        shutil.move(str(files[0]), out)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    say("done", path=str(out), size=out.stat().st_size)


def update():
    """pacman's yt-dlp through the app installer's admin helper (scripts/apps-install.py)"""
    spec = importlib.util.spec_from_file_location("apps_install", HERE / "apps-install.py")
    ai = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ai)
    helper, why = ai.start_root()
    if why:
        raise Fail(why)
    try:
        r = subprocess.run(ai.root("pacman", "-Syu", "--needed", "--noconfirm", "yt-dlp"), capture_output=True, text=True)
    finally:
        ai.stop_root(helper)
    if r.returncode:
        raise Fail("pacman: " + ((r.stderr or r.stdout).strip().splitlines() or ["?"])[-1])
    v = subprocess.run([YTDLP, "--version"], capture_output=True, text=True).stdout.strip()
    say("done", version=v)


def self_test():
    v, a, h = plan(30, 20_000_000, True, 1080)
    assert a == 128_000 and 4_800_000 < v < 5_000_000 and h == 0, (v, a, h)
    v, a, h = plan(300, 20_000_000, True, 1080)       # 5 min: ~500 kbit/s → 480p
    assert a == 64_000 and h == 480, (v, a, h)
    v, a, h = plan(300, 20_000_000, True, 360)        # already small: kept
    assert h == 0
    v, a, h = plan(10, 20_000_000, True, 1080, 3_000_000)   # a 3 Mbit/s clip isn't blown up
    assert v == 3_000_000 - 128_000, v
    assert longest(20_000_000, True) == 1212
    try:
        plan(3600, 20_000_000, True, 1080)
        raise AssertionError("an hour fits")
    except Fail:
        pass
    p = Progress()
    assert p.line("[vg] 10 100 NA Clip") == (10, 100, "Clip")
    assert p.line("[vg] 100 100 NA Clip")[:2] == (100, 100)
    assert p.line("[vg] 5 NA 20.5 Clip")[:2] == (105, 120)   # the sound after the video
    assert p.line("[download] other") is None
    assert ext_of("x.JPEG") == "jpg" and target_ext("gifv") == "gif"
    assert kind_of("/a/B.MP4") == "video" and kind_of("x.heic") == "image" and kind_of("x.opus") == "audio" and kind_of("x.txt") == ""
    assert free_name(Path(__file__)).name == Path(__file__).stem + " (2).py"
    print("ok")


def main(argv):
    # a stopped job (the shell's restart) cleans up after itself
    signal.signal(signal.SIGTERM, stop)
    if argv[:1] == ["--self-test"]:
        return self_test()
    cmd, args = (argv[0], argv[1:]) if argv else ("", [])
    opt = lambda name, default=None: args[args.index(name) + 1] if name in args[:-1] else default
    pos = [x for i, x in enumerate(args) if not x.startswith("--") and (i == 0 or args[i - 1] not in ("--start", "--end", "--mb", "--dir"))]
    try:
        if cmd == "shrink" and pos:
            os.nice(10)
            shrink(pos[0], float(opt("--start", 0)), float(opt("--end", 0)), float(opt("--mb", 20)))
        elif cmd == "estimate" and pos:
            estimate(pos[0], float(opt("--start", 0)), float(opt("--end", 0)), float(opt("--mb", 20)))
        elif cmd in ("edit", "wav") and pos:
            os.nice(10)
            (edit if cmd == "edit" else wav)(pos[0], float(opt("--start", 0)), float(opt("--end", 0)))
        elif cmd == "formats":
            formats()
        elif cmd == "sizes" and len(pos) >= 2 and pos[0] in FORMATS:
            sizes(pos[0], pos[1:])
        elif cmd == "convert" and len(pos) >= 2:
            os.nice(10)
            convert(pos[0], pos[1:])
        elif cmd == "grab" and pos:
            grab(pos[0], "--audio" in args, opt("--dir", str(Path.home() / "Downloads")))
        elif cmd == "update":
            update()
        else:
            print(__doc__, file=sys.stderr)
            return 2
    except Fail as e:
        say("error", text=str(e.args[0]), update=len(e.args) > 1)
        return 1
    except (OSError, ValueError) as e:
        say("error", text=str(e))
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]) or 0)
