#!/usr/bin/env python3
"""ProtonDB's monthly export (github.com/bdefore/protondb-data, ODbL) boiled down to what the
game tuner needs per Steam game: how many say it works, out of the box or not, which Proton
those who say so ran, the launch options they used (harmless ones only, by video card) and
whether anti-cheat got in the way. The export is ~70 MB packed, ~530 MB of JSON: this runs
monthly in GitHub Actions (.github/workflows/protondb-digest.yml) and publishes the digest as a
release asset (~2 MB), which scripts/game-tune.py fetches. Streamed: a few MB of memory.

usage: protondb-digest.py EXPORT.tar.gz OUT.json.gz [--years 2]
"""
import gzip
import json
import sys
import tarfile
import time
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gametune_safe import safe  # noqa: E402

TOP = 4                 # launch options kept per game and video card
MIN_SAME = 2            # an option posted once is someone's own


def records(stream):
    """the objects of a big JSON array, one by one"""
    dec = json.JSONDecoder()
    buf, pos, started = "", 0, False
    while True:
        chunk = stream.read(1 << 20)
        if chunk:
            buf = buf[pos:] + chunk.decode("utf-8", "replace")
            pos = 0
        elif pos >= len(buf.rstrip()):
            return
        while True:
            while pos < len(buf) and buf[pos] in " \t\r\n,":
                pos += 1
            if not started:
                if pos < len(buf) and buf[pos] == "[":
                    pos += 1
                    started = True
                    continue
                break
            if pos < len(buf) and buf[pos] == "]":
                return
            try:
                obj, end = dec.raw_decode(buf, pos)
            except json.JSONDecodeError:
                if not chunk:
                    return
                break
            pos = end
            yield obj


def proton_family(r):
    """official | experimental | ge | cachyos | wineland | em | tkg | gdk | sarek | other"""
    v = str(r.get("variant") or "").lower()
    custom = str(r.get("customProtonVersion") or (r.get("notes") or {}).get("variant") or "").lower()
    if v in ("official", "older"):
        return "official"
    if v in ("experimental", "ge"):
        return v
    text = custom or str(r.get("protonVersion") or "").lower()
    for k in ("cachyos", "wineland", "sarek", "tkg", "gdk"):
        if k in text:
            return k
    if "proton-em" in text or text.startswith("em-") or text.startswith("em "):
        return "em"
    if "ge-proton" in text or text.startswith("ge") or "-ge-" in text:
        return "ge"
    if "experimental" in text or "bleeding" in text:
        return "experimental"
    if text[:1].isdigit() or text in ("default", ""):
        return "official"
    return "other"


def gpu_vendor(info):
    g = str((info or {}).get("gpu") or "").lower() + " " + str((info or {}).get("gpuDriver") or "").lower()
    if "nvidia" in g:
        return "nvidia"
    if "amd" in g or "radeon" in g or "radv" in g:
        return "amd"
    if "intel" in g:
        return "intel"
    return "other"


def build(src, years):
    since = time.time() - years * 365 * 86400
    apps = defaultdict(lambda: {"n": 0, "ok": 0, "oob": 0, "oobn": 0, "ac": 0,
                                "pv": Counter(), "lo": defaultdict(Counter), "t": ""})
    with tarfile.open(src) as tar:
        member = next(m for m in tar if m.isfile() and m.name.endswith(".json"))
        for rec in records(tar.extractfile(member)):
            try:
                if rec.get("timestamp", 0) < since:
                    continue
                appid = str(rec["app"]["steam"]["appId"])
                r = rec.get("responses") or {}
            except (KeyError, TypeError):
                continue
            a = apps[appid]
            a["t"] = str(rec["app"].get("title") or a["t"])[:120]
            a["n"] += 1
            works = r.get("verdict") == "yes"
            if r.get("isImpactedByAntiCheat") == "yes":
                a["ac"] += 1
            if r.get("verdictOob") in ("yes", "no"):
                a["oobn"] += 1
                a["oob"] += r.get("verdictOob") == "yes"
            if not works:
                continue
            a["ok"] += 1
            a["pv"][proton_family(r)] += 1
            lo = safe(str(r.get("launchOptions") or "").strip()) if r.get("launchOptions") else None
            if lo:
                a["lo"][gpu_vendor(rec.get("systemInfo"))][lo] += 1
    out = {}
    for appid, a in apps.items():
        d = {"t": a["t"], "n": a["n"], "ok": a["ok"]}
        if a["oobn"]:
            d["oob"] = round(a["oob"] / a["oobn"], 2)
        if a["ac"]:
            d["ac"] = a["ac"]
        if a["pv"]:
            d["pv"] = dict(a["pv"].most_common())
        lo = {v: [[s, c] for s, c in cnt.most_common(TOP) if c >= MIN_SAME] for v, cnt in a["lo"].items()}
        lo = {v: x for v, x in lo.items() if x}
        if lo:
            d["lo"] = lo
        out[appid] = d
    return out


def main():
    if len(sys.argv) < 3:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    years = float(sys.argv[sys.argv.index("--years") + 1]) if "--years" in sys.argv else 2
    apps = build(sys.argv[1], years)
    doc = {"v": 1, "built": time.strftime("%Y-%m-%d"), "source": "ProtonDB (protondb.com), ODbL 1.0",
           "years": years, "apps": apps}
    with gzip.open(sys.argv[2], "wt", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))
    print(json.dumps({"apps": len(apps), "out": sys.argv[2]}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
