#!/usr/bin/env python3
"""Read a selected screen region (or an image file) with local GLM-OCR."""

import base64
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.error
import urllib.request


def notify(title, body):
    try:
        subprocess.run(["notify-send", "-a", "OCR", title, body], check=False)
    except OSError:
        pass


def show_card(text):
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime:
        return False
    folder = Path(runtime) / "ocr-small"
    try:
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "ocr.json").write_text(json.dumps({"text": text}, ensure_ascii=False), encoding="utf-8")
        result = subprocess.run(["qs", "-c", "angelos", "ipc", "call", "ocrSmall", "openCard"],
                                capture_output=True, text=True, timeout=10)
        return result.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def recognize(image):
    payload = {
        "model": "glm-ocr",
        "stream": False,
        "messages": [{"role": "user", "content": "Text Recognition:",
                      "images": [base64.b64encode(image).decode("ascii")]}],
        "options": {"temperature": 0},
        "keep_alive": "30m",
    }
    request = urllib.request.Request(
        "http://127.0.0.1:11434/api/chat", json.dumps(payload).encode(),
        {"Content-Type": "application/json"},
    )
    try:
        # Never send screenshots through proxy settings inherited from the session.
        with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(request, timeout=300) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        try:
            detail = json.load(error).get("error", str(error))
        except (ValueError, OSError):
            detail = str(error)
        raise RuntimeError(f"Ollama: {detail}") from error
    except (urllib.error.URLError, TimeoutError) as error:
        raise RuntimeError(f"Ollama недоступна или не отвечает: {error}") from error
    if not result.get("done") or result.get("done_reason") == "length":
        raise RuntimeError("Ollama вернула неполный текст")
    text = result.get("message", {}).get("content", "").strip()
    if not text:
        raise RuntimeError("Текст не найден")
    return text


def main():
    if len(sys.argv) > 2 or (len(sys.argv) == 2 and sys.argv[1].startswith("-")):
        print("Использование: ocr-region-local [изображение]", file=sys.stderr)
        return 2
    try:
        if len(sys.argv) == 2:
            print(recognize(Path(sys.argv[1]).read_bytes()))
            return 0

        runtime = os.environ.get("XDG_RUNTIME_DIR")
        if not runtime:
            raise RuntimeError("Не задан XDG_RUNTIME_DIR")
        with open(Path(runtime) / "ocr-region-local.lock", "w") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                notify("OCR", "Распознавание уже выполняется")
                return 1
            selected = subprocess.run(["slurp"], capture_output=True, text=True)
            if selected.returncode != 0 or not selected.stdout.strip():
                return 0  # selection cancelled
            captured = subprocess.run(["grim", "-g", selected.stdout.strip(), "-"], capture_output=True)
            if captured.returncode != 0 or not captured.stdout:
                raise RuntimeError("Не удалось снять выбранную область")
            notify("OCR", "Распознаю выбранную область…")
            text = recognize(captured.stdout)
            subprocess.run(["wl-copy", "--type", "text/plain;charset=utf-8"],
                           input=text.encode("utf-8"), check=True)
            if not show_card(text):
                notify("OCR → буфер", "Текст скопирован")
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"OCR: {error}", file=sys.stderr)
        if len(sys.argv) == 1:
            notify("Ошибка OCR", str(error)[:300])
        return 1


if __name__ == "__main__":
    sys.exit(main())
