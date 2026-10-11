#!/usr/bin/env python3
"""Summarise a qmlprofiler trace (.qtd) of angelOS: where the QML engine spends its time.

usage: perf-trace.py TRACE.qtd [--top N] [--json]

Prints, for the recorded span: frames rendered a second (all windows together), and the
signal handlers, bindings and JavaScript functions that took the most time, each with its
file:line and how often it ran a second. `angelos perf --profile` records the trace
(scripts/perf.py) from a shell started with a QML debug port (ANGELOS_QML_DEBUG=port).
"""
import json
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

# QQmlProfilerDefinitions::SceneGraphFrameType
SG = {0: "renderer", 1: "adaptation", 2: "context", 3: "renderLoop", 4: "texturePrepare",
      5: "textureDeletion", 6: "polishAndSync", 7: "windowsRenderLoop", 8: "windowsAnimations",
      9: "polishFrame"}
TIMED = ("HandlingSignal", "Binding", "Javascript", "Creating", "Compiling")


def where(ev):
    f = ev.get("filename", "")
    if "/angelos/" in f:
        f = f.split("/angelos/", 1)[1]
    elif f.startswith("file://"):
        f = f.rsplit("/", 1)[-1]
    elif f.startswith("qrc:") or not f:
        f = f or "?"
    return "%s:%s" % (f, ev.get("line", "?"))


def summarise(path, top=25):
    events = {}
    starts, ends = [], []
    stats = defaultdict(lambda: [0, 0])          # index → [count, total ns]
    sg = defaultdict(int)
    anim_frames = 0
    anim_ranges = 0
    for _, el in ET.iterparse(path, events=("end",)):
        tag = el.tag
        if tag == "event" and el.get("index") is not None and el.find("type") is not None:
            ev = {c.tag: (c.text or "") for c in el}
            events[int(el.get("index"))] = ev
            el.clear()
        elif tag == "range":
            st = int(el.get("startTime", 0))
            idx = int(el.get("eventIndex", -1))
            dur = int(el.get("duration", 0) or 0)
            starts.append(st)
            ends.append(st + dur)
            ev = events.get(idx, {})
            t = ev.get("type")
            if t in TIMED:
                s = stats[idx]
                s[0] += 1
                s[1] += dur
            elif t == "SceneGraph":
                sg[SG.get(int(ev.get("sgEventType", -1) or -1), ev.get("sgEventType"))] += 1
            elif t == "Event" and el.get("framerate") is not None:
                anim_ranges += 1
                anim_frames += 1
            el.clear()
    span = (max(ends) - min(starts)) / 1e9 if starts else 0.0
    span = max(span, 1e-6)
    rows = defaultdict(list)
    for idx, (n, ns) in stats.items():
        ev = events[idx]
        rows[ev["type"]].append({
            "at": where(ev), "what": (ev.get("details") or ev.get("displayname") or "")[:80],
            "perSec": round(n / span, 1), "msPerSec": round(ns / 1e6 / span, 2), "count": n})
    out = {"seconds": round(span, 1),
           "frames": {k: round(v / span, 1) for k, v in sorted(sg.items())},
           "animationFrames": round(anim_frames / span, 1)}
    for t in TIMED:
        out[t] = sorted(rows.get(t, []), key=lambda r: -r["msPerSec"])[:top]
    # the busiest by how often they run (a cheap handler 200 times a second still wakes the shell)
    out["mostOften"] = sorted([r for t in ("HandlingSignal", "Binding") for r in rows.get(t, [])],
                              key=lambda r: -r["perSec"])[:top]
    return out


def show(r):
    print("Записано %.1f с" % r["seconds"])
    if r["frames"]:
        print("Кадры (все окна вместе), в секунду: " + ", ".join("%s %.1f" % kv for kv in r["frames"].items()))
    if r.get("animationFrames"):
        print("Кадры анимаций в секунду: %.1f" % r["animationFrames"])
    names = {"HandlingSignal": "Обработчики сигналов", "Binding": "Привязки", "Javascript": "JS-функции",
             "Creating": "Создание объектов", "mostOften": "Чаще всего (раз в секунду)"}
    for t in ("HandlingSignal", "Binding", "Javascript", "Creating", "mostOften"):
        rows = r.get(t) or []
        if not rows:
            continue
        print("\n%s:" % names[t])
        print("  %8s %8s  %s" % ("мс/с", "раз/с", "где"))
        for x in rows:
            print("  %8.2f %8.1f  %s  %s" % (x["msPerSec"], x["perSec"], x["at"], x["what"][:50]))


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    top = int(args[args.index("--top") + 1]) if "--top" in args else 25
    r = summarise(args[0], top)
    if "--json" in args:
        print(json.dumps(r, ensure_ascii=False))
    else:
        show(r)
