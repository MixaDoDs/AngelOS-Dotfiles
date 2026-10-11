#!/usr/bin/env python3
"""Find live Claude Code sessions without hooks (angelOS claude-companion).

Looks at transcripts in ~/.claude/projects/*/*.jsonl touched in the last
WINDOW minutes, infers each session's state from its last user/assistant record,
and sums token usage incrementally (same cache as hooks/pulse.py).
Prints one JSON array: [{id, state, model, in, out, cc, cr, cwd, age}].
Only reports anything while a `claude` process is running.

  scan.py               one look, one line
  scan.py --watch SEC   looks every SEC seconds and prints a line when something other than the
                        ages changed (a minute at the most between lines): one Python for the
                        shell's whole life instead of one every few seconds
"""
import glob
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from pulse import _accumulate  # incremental token sums
except Exception:  # noqa: BLE001
    _accumulate = None

WINDOW = 30 * 60
TAIL = 96 * 1024


def claude_running():
    for d in os.listdir("/proc"):
        if not d.isdigit():
            continue
        try:
            with open(f"/proc/{d}/comm") as f:
                if f.read().strip() == "claude":
                    return True
        except OSError:
            pass
    return False


def last_state(path):
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        f.seek(max(0, size - TAIL))
        lines = f.read().decode("utf-8", "replace").splitlines()
    model, cwd = "", ""
    for raw in reversed(lines):
        try:
            d = json.loads(raw)
        except ValueError:
            continue
        cwd = cwd or d.get("cwd") or ""
        kind = d.get("type")
        if kind not in ("user", "assistant"):
            continue
        m = d.get("message") or {}
        content = m.get("content")
        parts = [c.get("type") for c in content] if isinstance(content, list) else ["text"]
        if kind == "assistant":
            model = m.get("model") or model
            if "tool_use" in parts:
                return "tool_start", model, cwd
            if m.get("stop_reason") in ("end_turn", "stop_sequence", "max_tokens"):
                return "turn_end", model, cwd
            return "text", model, cwd
        # user: a tool result means the model is thinking again; a prompt starts a turn
        return "turn_start", model, cwd
    return "idle", model, cwd


def scan():
    if not claude_running():
        return []
    now = time.time()
    out = []
    for path in glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl")):
        try:
            age = now - os.path.getmtime(path)
        except OSError:
            continue
        if age > WINDOW:
            continue
        sid = os.path.basename(path)[:-6]
        short = sid.split("-")[0]
        try:
            state, model, cwd = last_state(path)
        except OSError:
            continue
        if state == "turn_end" and age > 5 * 60:
            state = "idle"
        elif state in ("turn_start", "text") and age > 3 * 60:
            state = "idle"   # interrupted / abandoned turn
        tok = {"in": 0, "out": 0, "cc": 0, "cr": 0, "model": ""}
        if _accumulate:
            try:
                tok = _accumulate(path, short)
            except Exception:  # noqa: BLE001
                pass
        model = (model or tok.get("model") or "?").replace("claude-", "")
        out.append({"id": short, "state": state, "model": model, "in": tok["in"], "out": tok["out"],
                    "cc": tok["cc"], "cr": tok["cr"], "cwd": os.path.basename(cwd) if cwd else "", "age": int(age)})
    return out


def watch(every):
    last, said = None, 0.0
    while True:
        out = scan()
        key = json.dumps([{k: v for k, v in s.items() if k != "age"} for s in out], sort_keys=True)
        if key != last or time.time() - said >= 60:
            print(json.dumps(out), flush=True)
            last, said = key, time.time()
        time.sleep(every)


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--watch":
        try:
            watch(max(0.5, float(sys.argv[2])))
        except (KeyboardInterrupt, BrokenPipeError):
            pass
        return
    print(json.dumps(scan()))


if __name__ == "__main__":
    main()
