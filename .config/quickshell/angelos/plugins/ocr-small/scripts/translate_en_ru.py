#!/usr/bin/env python3
"""Translate English text to Russian with a local CT2 MarianMT model."""
import re
import sys
from functools import lru_cache
from pathlib import Path

import ctranslate2
import sentencepiece


ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = Path(__import__("os").environ.get("OCR_TRANSLATE_MODEL", ROOT / "ct2-en-ru"))


@lru_cache(maxsize=1)
def translator():
    return ctranslate2.Translator(str(MODEL_DIR), device="cpu", inter_threads=1,
                                  intra_threads=4, compute_type="int8")


@lru_cache(maxsize=1)
def processors():
    return (sentencepiece.SentencePieceProcessor(model_file=str(MODEL_DIR / "source.spm")),
            sentencepiece.SentencePieceProcessor(model_file=str(MODEL_DIR / "target.spm")))


def chunks(text):
    for line in text.splitlines():
        line = line.strip()
        if not line:
            yield ""
            continue
        for part in re.split(r"(?<=[.!?])\s+", line):
            part = part.strip()
            for i in range(0, len(part), 220):
                piece = part[i:i + 220].strip()
                if piece:
                    yield piece


def translate_one(text):
    src, tgt = processors()
    tokens = src.encode(text, out_type=str) + ["</s>"]
    result = translator().translate_batch([tokens], beam_size=1,
                                           max_decoding_length=128)[0]
    return tgt.decode(result.hypotheses[0]) if result.hypotheses else ""


def translate(text):
    return "\n".join(translate_one(piece) for piece in chunks(text))


def selftest():
    assert "буфер обмена" in translate("The clipboard is ready."), "EN->RU failed"
    assert "Привет" in translate("Hello world!"), "EN->RU failed"
    print("OK")


def main(argv):
    if len(argv) == 2 and argv[1] == "--selftest":
        selftest()
        return 0
    text = Path(argv[1]).read_text(encoding="utf-8") if len(argv) == 2 else sys.stdin.read()
    text = text.strip()
    if not text:
        print("Пустой текст", file=sys.stderr)
        return 1
    print(translate(text))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
