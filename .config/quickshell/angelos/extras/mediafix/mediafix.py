#!/usr/bin/env python3
"""mediafix: prepare video files for DaVinci Resolve by replacing audio with PCM."""
from __future__ import annotations

import argparse
import curses
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

VIDEO_EXTENSIONS = {".mp4", ".mkv", ".mov", ".avi", ".mxf", ".webm", ".ts", ".mts", ".m2ts", ".flv", ".wmv", ".mpg", ".mpeg", ".m4v", ".3gp"}
INSTALL_HINT = "sudo pacman -S ffmpeg"


class DrfixError(Exception):
    pass


@dataclass
class StreamInfo:
    index: int
    codec_type: str
    codec_name: str = ""
    codec_long_name: str = ""
    channels: int | None = None
    sample_rate: int | None = None
    duration: float | None = None
    attached_pic: bool = False
    language: str = ""
    title: str = ""


@dataclass
class ProbeInfo:
    path: Path
    duration: float | None
    streams: list[StreamInfo]
    format_name: str

    @property
    def video(self) -> StreamInfo | None:
        return next((s for s in self.streams if s.codec_type == "video" and not s.attached_pic), None)

    @property
    def audio(self) -> list[StreamInfo]:
        return [s for s in self.streams if s.codec_type == "audio"]

    @property
    def extra_video(self) -> list[StreamInfo]:
        return [s for s in self.streams if s.codec_type == "video" and s is not self.video]

    @property
    def subtitles(self) -> list[StreamInfo]:
        return [s for s in self.streams if s.codec_type == "subtitle"]

    @property
    def attachments(self) -> list[StreamInfo]:
        return [s for s in self.streams if s.codec_type == "attachment"]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(prog="mediafix", description="Подготовка видео для DaVinci Resolve: PCM 24-bit / 48 kHz")
    p.add_argument("files", nargs="*", type=Path, help="видеофайлы для обработки")
    return p.parse_args()


def require_tools() -> None:
    missing = [x for x in ("ffmpeg", "ffprobe") if shutil.which(x) is None]
    if missing:
        print("Не найдены: " + ", ".join(missing))
        print(f"Установите их в Arch Linux / CachyOS: {INSTALL_HINT}")
        raise SystemExit(1)


def run_probe(path: Path) -> ProbeInfo:
    cmd = ["ffprobe", "-v", "error", "-print_format", "json", "-show_format", "-show_streams", str(path)]
    try:
        cp = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    except OSError as e:
        raise DrfixError(f"не удалось запустить ffprobe: {e}") from e
    if cp.returncode != 0:
        detail = cp.stderr.strip() or "ffprobe завершился с ошибкой"
        raise DrfixError(detail)
    try:
        data: dict[str, Any] = json.loads(cp.stdout)
    except json.JSONDecodeError as e:
        raise DrfixError(f"ffprobe вернул некорректные данные: {e}") from e
    streams: list[StreamInfo] = []
    for raw in data.get("streams", []):
        tags = raw.get("tags") or {}
        disposition = raw.get("disposition") or {}
        rate = raw.get("sample_rate")
        streams.append(StreamInfo(
            index=int(raw.get("index", -1)), codec_type=str(raw.get("codec_type", "")),
            codec_name=str(raw.get("codec_name", "")), codec_long_name=str(raw.get("codec_long_name", "")),
            channels=int(raw["channels"]) if raw.get("channels") is not None else None,
            sample_rate=int(rate) if rate and str(rate).isdigit() else None,
            duration=float(raw["duration"]) if raw.get("duration") else None,
            attached_pic=bool(disposition.get("attached_pic", 0)),
            language=str(tags.get("language", "")), title=str(tags.get("title", "")),
        ))
    fmt = data.get("format") or {}
    duration = float(fmt["duration"]) if fmt.get("duration") else None
    return ProbeInfo(path, duration, streams, str(fmt.get("format_name", "")))


def output_folder() -> Path:
    # angelOS passes the folder chosen in its settings (capture.mediafixDir)
    return Path(os.environ.get("MEDIAFIX_DIR") or Path.home() / "Videos" / "MediaFix").expanduser()


def unique_output(source: Path) -> Path:
    folder = output_folder()
    folder.mkdir(parents=True, exist_ok=True)
    stem = source.stem + "_DR"
    candidate = folder / f"{stem}.mov"
    n = 2
    while candidate.exists():
        candidate = folder / f"{stem}_{n}.mov"
        n += 1
    return candidate


def temp_path(final: Path) -> Path:
    return final.with_name(f".{final.stem}.tmp-{os.getpid()}-{int(time.time() * 1000)}.mov")


def format_time(seconds: float | None) -> str:
    if seconds is None or seconds < 0:
        return "--:--"
    seconds = int(seconds)
    return f"{seconds // 3600:02d}:{seconds % 3600 // 60:02d}:{seconds % 60:02d}"


def run_conversion(info: ProbeInfo, final: Path, update, cut: tuple[float, float] | None = None) -> tuple[bool, str]:
    """cut: (start, length) seconds — the video copied from the key frame at or before start"""
    if info.video is None:
        return False, "нет обычного видеопотока (обложка не считается видео)"
    if not info.audio:
        return False, "нет аудиодорожек — файл пропущен"
    tmp = temp_path(final)
    video_index = info.video.index
    span = ["-ss", f"{cut[0]:.3f}", "-t", f"{cut[1]:.3f}"] if cut else ["-copyts"]
    length = cut[1] if cut else info.duration
    cmd = ["ffmpeg", "-hide_banner", "-nostdin", "-y", *span, "-i", str(info.path),
           "-map", f"0:{video_index}"]
    for stream in info.audio:
        cmd += ["-map", f"0:{stream.index}"]
    cmd += ["-map_metadata", "0", "-map_chapters", "0", "-sn", "-dn", "-c:v", "copy",
            "-c:a", "pcm_s24le", "-ar", "48000", "-copyinkf", "-avoid_negative_ts", "disabled",
            "-progress", "pipe:1", "-nostats", "-f", "mov", str(tmp)]
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace", bufsize=1)
    except OSError as e:
        return False, f"не удалось запустить ffmpeg: {e}"
    stderr_lines: list[str] = []
    assert proc.stdout is not None and proc.stderr is not None
    import threading
    def read_err():
        for line in proc.stderr:
            stderr_lines.append(line.rstrip())
    thread = threading.Thread(target=read_err, daemon=True)
    thread.start()
    state: dict[str, str] = {}
    try:
        for line in proc.stdout:
            if "=" in line:
                key, value = line.rstrip().split("=", 1)
                state[key] = value
                if key in {"out_time_ms", "speed", "progress"}:
                    try:
                        out_ms = float(state.get("out_time_ms", "0"))
                    except ValueError:
                        out_ms = 0
                    ratio = min(1.0, max(0.0, (out_ms / 1_000_000) / length)) if length else 0.0
                    update(ratio, state.get("speed", "?"), out_ms / 1_000_000)
        rc = proc.wait()
        thread.join(timeout=2)
    except KeyboardInterrupt:
        proc.send_signal(signal.SIGINT)
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill(); proc.wait()
        tmp.unlink(missing_ok=True)
        raise
    if rc != 0:
        tmp.unlink(missing_ok=True)
        detail = "\n".join(stderr_lines[-12:]).strip()
        return False, detail or f"ffmpeg завершился с кодом {rc}"
    try:
        check = run_probe(tmp)
        audios = check.audio
        if check.video is None or len(audios) != len(info.audio):
            raise DrfixError("после обработки не совпало число видеопотоков/аудиодорожек")
        for a in audios:
            if a.codec_name != "pcm_s24le" or a.sample_rate != 48000:
                raise DrfixError("после обработки аудио не соответствует pcm_s24le / 48000 Гц")
        os.replace(tmp, final)
        return True, ""
    except DrfixError as e:
        tmp.unlink(missing_ok=True)
        return False, f"постпроверка: {e}"
    except OSError as e:
        tmp.unlink(missing_ok=True)
        return False, f"не удалось сохранить результат: {e}"


def human_stream_notes(info: ProbeInfo) -> list[str]:
    notes = []
    if info.extra_video: notes.append(f"дополнительных видеопотоков: {len(info.extra_video)}")
    if info.subtitles: notes.append(f"субтитры не скопированы: {len(info.subtitles)}")
    if info.attachments: notes.append(f"вложений не скопировано: {len(info.attachments)}")
    return notes


def browse() -> list[Path]:
    selected: set[Path] = set()
    result: list[Path] = []
    def ui(stdscr):
        nonlocal result
        curses.curs_set(0); stdscr.keypad(True)
        current = Path.cwd(); cursor = 0; offset = 0
        while True:
            entries = [current / ".."] + sorted([p for p in current.iterdir() if p.is_dir() or p.suffix.lower() in VIDEO_EXTENSIONS], key=lambda p: (not p.is_dir(), p.name.lower()))
            cursor = max(0, min(cursor, len(entries) - 1))
            stdscr.erase(); h, w = stdscr.getmaxyx()
            stdscr.addnstr(0, 0, f"mediafix — выбор видео: {current}", w - 1, curses.A_BOLD)
            visible = max(1, h - 5)
            if cursor < offset: offset = cursor
            if cursor >= offset + visible: offset = cursor - visible + 1
            for row, p in enumerate(entries[offset:offset + visible], 1):
                idx = offset + row - 1; mark = "✓ " if p in selected else "  "; suffix = "/" if p.is_dir() else ""
                attr = curses.A_REVERSE if idx == cursor else curses.A_NORMAL
                stdscr.addnstr(row, 0, mark + p.name + suffix, w - 1, attr)
            help_line = "↑↓ навигация  Enter открыть/начать  Space отметить  Backspace выше  q выход"
            stdscr.addnstr(h - 2, 0, f"Отмечено: {len(selected)}", w - 1)
            stdscr.addnstr(h - 1, 0, help_line, w - 1, curses.A_DIM)
            key = stdscr.getch()
            if key in (ord('q'), ord('Q'), 27): result = []; return
            if key in (curses.KEY_UP, ord('k')): cursor -= 1
            elif key in (curses.KEY_DOWN, ord('j')): cursor += 1
            elif key in (curses.KEY_BACKSPACE, 127, 8): current = current.parent; cursor = 0; offset = 0
            elif key == ord(' '):
                p = entries[cursor]
                if p.is_file(): selected.symmetric_difference_update({p})
            elif key in (10, 13, curses.KEY_ENTER):
                p = entries[cursor]
                if p.is_dir(): current = p.resolve(); cursor = 0; offset = 0
                elif selected: result = sorted(selected); return
        
    curses.wrapper(ui)
    return result


def process(files: list[Path]) -> int:
    folder = output_folder()
    print("mediafix — подготовка видео для DaVinci Resolve")
    print("Оригиналы не изменяются. Готовые MOV сохраняются в:")
    print(f"  {folder}")
    print("Видео копируется без перекодирования, аудио становится PCM 24-bit / 48 kHz.\n")
    print(f"Очередь: {len(files)} файл(ов)\n")
    ok = 0; errors: list[tuple[Path, str]] = []
    for num, raw in enumerate(files, 1):
        path = raw.expanduser().resolve()
        print(f"[{num}/{len(files)}] {path}")
        if not path.is_file():
            errors.append((path, "файл не найден")); print("  Ошибка: файл не найден\n"); continue
        try: info = run_probe(path)
        except DrfixError as e:
            errors.append((path, str(e))); print(f"  Ошибка анализа: {e}\n"); continue
        final = unique_output(path)
        for note in human_stream_notes(info): print(f"  Примечание: {note}")
        def update(ratio, speed, elapsed):
            print(f"\r  Прогресс: {ratio * 100:6.2f}%  время {format_time(elapsed)} / {format_time(info.duration)}  скорость {speed:>8}", end="", flush=True)
        try: success, message = run_conversion(info, final, update)
        except KeyboardInterrupt:
            print("\nПрервано пользователем. Готовые результаты сохранены.")
            raise
        print()
        if success:
            ok += 1; print(f"  Готово: {final}\n")
        else:
            errors.append((path, message)); print(f"  Ошибка: {message}\n")
    print(f"Результаты: успешно {ok} из {len(files)}")
    if ok:
        print(f"Все готовые файлы находятся в:\n  {folder}")
    if errors:
        print("\nОшибки:")
        for path, message in errors: print(f"- {path}\n  {message}")
        return 1
    return 0


def main() -> int:
    try:
        require_tools()
        args = parse_args()
        files = [p for p in args.files] if args.files else browse()
        if not files:
            print("Файлы не выбраны.")
            return 0
        return process(files)
    except KeyboardInterrupt:
        print("\nОстановлено. Незавершённый временный файл удалён.")
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
