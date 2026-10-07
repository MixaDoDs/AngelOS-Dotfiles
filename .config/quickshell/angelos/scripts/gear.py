#!/usr/bin/env python3
"""The connected keyboard, mouse and microphone worth showing off: popular models
that cost more than the threshold ($100 by default), from data/premium-gear.json.

  gear.py                  -> {"threshold": 100, "devices": [{"kind", "name", "usd", "via"}]}
  gear.py --kind keyboard  -> "NuPhy Air60 HE (~$120)" for fastfetch's command
                              module; nothing (exit 1) if there is none, so
                              fastfetch leaves the line out
  gear.py --line           -> "NuPhy Air60 HE ~$120 · LAMZU Maya X 8K ~$140 · …": all of
                              them on one line; exit 1 if none
  gear.py --nth N --fmt F  -> the Nth device (keyboards, then mice, then mics; dearest first)
                              in the template F; exit 1 if there are fewer
  gear.py --total --fmt F  -> what they cost together, in F (the receipt's ИТОГО, the angel's
                              word on it); exit 1 if there is nothing unless --zero
  gear.py --threshold N    -> another limit

The prices are the point (people giggle at them): every way of printing shows them.

Templates (angelOS's fastfetch styles, scripts/fastfetch_style.py): {name} {price} ("$499")
{usd} {kind} {word} (клава / мышь / мик, --lang), {total} {count}, {tier} (a superchat
chip's colours by the price), {say} (a word from the angel on the price, --voice angel|demon),
{field:N} pads it to N columns, {#SGR} a colour like fastfetch's own ({#} resets) and {fill}
the dots (--fill-char) that make the line --width columns wide.

Sources (read-only, no root, no daemons asked): USB vendor:product and product
strings from /sys (HID interfaces for keyboards and mice, audio interfaces for
microphones), input device names from /proc/bus/input/devices (Bluetooth ones
too) and sound card names from /proc/asound/cards.
"""
import argparse
import json
import random
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE.parent / "data/premium-gear.json"
HID, AUDIO = "03", "01"


def read(path):
    try:
        return Path(path).read_text(errors="replace").strip()
    except OSError:
        return ""


def usb_devices():
    """[(vid:pid, "manufacturer product", {interface classes})]"""
    out = []
    for dev in Path("/sys/bus/usb/devices").glob("*"):
        vid, pid = read(dev / "idVendor"), read(dev / "idProduct")
        if not vid:
            continue
        classes = {read(i / "bInterfaceClass") for i in dev.glob(dev.name + ":*")}
        out.append((f"{vid}:{pid}".lower(), (read(dev / "manufacturer") + " " + read(dev / "product")).strip(), classes))
    return out


def input_names():
    return re.findall(r'^N: Name="(.*)"$', read("/proc/bus/input/devices"), re.M)


def sound_cards():
    # " 3 [Duo            ]: USB-Audio - RODECaster Duo" and its long name on the next line
    return [l.strip() for l in read("/proc/asound/cards").splitlines() if l.strip()]


def things():
    """every device to look at: (label, usb id or "", kinds it may be)"""
    out = []
    for vp, label, classes in usb_devices():
        kinds = (["keyboard", "mouse"] if HID in classes else []) + (["mic"] if AUDIO in classes else [])
        if kinds:
            out.append((label, vp, kinds))
    out += [(n, "", ["keyboard", "mouse"]) for n in input_names()]
    out += [(n, "", ["mic"]) for n in sound_cards()]
    return out


def detect(threshold):
    data = json.loads(DATA.read_text())
    entries = [dict(e, rx=re.compile(e["match"], re.I)) for e in data["devices"]]
    found = {}
    for label, vp, kinds in things():
        # an exact USB id first, else the first pattern in file order (specific ones come first)
        entry = next((e for e in entries if e["kind"] in kinds and vp and vp in [u.lower() for u in e.get("usb", [])]), None)
        if not entry:
            entry = next((e for e in entries if e["kind"] in kinds and e["rx"].search(label)), None)
        if entry and entry["name"] not in found:
            found[entry["name"]] = {"kind": entry["kind"], "name": entry["name"], "usd": entry["usd"], "via": vp or label}
    order = {"keyboard": 0, "mouse": 1, "mic": 2}
    devices = sorted((d for d in found.values() if d["usd"] > threshold), key=lambda d: (order.get(d["kind"], 9), -d["usd"]))
    return threshold, devices


WORDS = {"keyboard": ("клава", "kbd"), "mouse": ("мышь", "mouse"), "mic": ("мик", "mic")}
# superchat colours by the price: (from $, chip background, chip text)
TIERS = [(400, "#e62117", "#ffffff"), (200, "#e91e63", "#ffffff"), (0, "#f57c00", "#1a0f05")]
# the angel's (and the demon's) word on what the gear cost together: (up to $, ru, en)
SAYS = {
    "angel": [
        (0, ["ни копейки? берегла себя ♡", "ноль долларов. я горжусь тобой ♡"], ["not a cent? saving up ♡", "zero dollars. so proud of you ♡"]),
        (200, ["скромненько, но со вкусом ♡", "ну такое… но мило ♡"], ["modest, but tasteful ♡", "eh… but cute ♡"]),
        (500, ["неплохо так потратился ♡", "кто-то любит свой стол ♡"], ["that's quite a spend ♡", "someone loves their desk ♡"]),
        (1000, ["ого. ты что, миллионер?! ♡", "это же целая зарплата?! ♡", "мама знает, сколько это стоило? ♡"], ["whoa. are you a millionaire?! ♡", "that's a whole paycheck?! ♡", "does your mom know what this cost? ♡"]),
        (None, ["продай почку обратно, пожалуйста ♡", "я молюсь за твой кошелёк ♡"], ["please buy your kidney back ♡", "praying for your wallet ♡"]),
    ],
    "demon": [
        (0, ["пусто. продай душу — купим ⛧", "ноль. жалкое зрелище ⛧"], ["nothing. sell me your soul and we'll shop ⛧", "zero. pathetic ⛧"]),
        (200, ["мелочь. мне скучно ⛧", "и это всё? ⛧"], ["pocket change. i'm bored ⛧", "is that all? ⛧"]),
        (500, ["неплохо. но можно больше ⛧", "жадность — это хорошо ⛧"], ["not bad. but there's room for more ⛧", "greed is good ⛧"]),
        (1000, ["вот это я понимаю — грех ⛧", "кошелёк горит. как приятно ⛧"], ["now that's a sin ⛧", "your wallet is burning. lovely ⛧"]),
        (None, ["четвёртый круг ждёт тебя ⛧", "душа уже в залоге, да? ⛧"], ["the fourth circle awaits you ⛧", "your soul's already pawned, right? ⛧"]),
    ],
}
SGR = re.compile(r"\x1b\[[0-9;]*m")


def rgb(hex_colour):
    h = hex_colour.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def price(usd):
    return "$" + str(round(usd))


def fill_in(template, values, width=0, fill_char="."):
    """the template with its fields, colours and dots (see the module's doc)"""
    def field(m):
        body = m.group(1)
        if body.startswith("#"):
            return "\x1b[0m" if body == "#" else "\x1b[" + body[1:] + "m"
        if body == "fill":
            return "\0"
        name, _, pad = body.partition(":")
        if name not in values:
            return m.group(0)
        text = str(values[name])
        return text.ljust(int(pad)) if pad.isdigit() else text
    out = re.sub(r"\{([^{}]*)\}", field, template)
    if "\0" in out:
        seen = len(SGR.sub("", out.replace("\0", "")))
        out = out.replace("\0", fill_char * max(1, width - seen), 1).replace("\0", "")
    return out + ("\x1b[0m" if "\x1b[" in out else "")


def say(total, voice, lang):
    for top, ru, en in SAYS.get(voice, SAYS["angel"]):
        if top is None or total <= top:
            return random.choice(en if lang == "en" else ru)
    return ""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--kind", choices=["keyboard", "mouse", "mic"])
    parser.add_argument("--line", action="store_true")
    parser.add_argument("--nth", type=int, default=None)
    parser.add_argument("--total", action="store_true")
    parser.add_argument("--zero", action="store_true", help="--total: print $0 too")
    parser.add_argument("--fmt", default="{name} {price}")
    parser.add_argument("--width", type=int, default=0)
    parser.add_argument("--fill-char", default=".")
    parser.add_argument("--lang", choices=["ru", "en"], default="ru")
    parser.add_argument("--voice", choices=["angel", "demon"], default="angel")
    parser.add_argument("--threshold", type=float, default=None)
    args = parser.parse_args()
    data_threshold = json.loads(DATA.read_text()).get("threshold", 100)
    threshold, devices = detect(data_threshold if args.threshold is None else args.threshold)
    if args.line:
        if not devices:
            return 1
        print(" · ".join(f"{d['name']} ~{price(d['usd'])}" for d in devices))
        return 0
    if args.nth is not None:
        if not 0 <= args.nth < len(devices):
            return 1
        d = devices[args.nth]
        bg, ink = next((b, i) for low, b, i in TIERS if d["usd"] >= low)
        tier = "\x1b[1;38;2;%d;%d;%dm\x1b[48;2;%d;%d;%dm" % (*rgb(ink), *rgb(bg))
        print(fill_in(args.fmt, {"name": d["name"], "price": price(d["usd"]), "usd": d["usd"], "kind": d["kind"],
                                 "word": WORDS[d["kind"]][args.lang == "en"], "tier": tier}, args.width, args.fill_char))
        return 0
    if args.total:
        total = sum(d["usd"] for d in devices)
        if not devices and not args.zero:
            return 1
        print(fill_in(args.fmt, {"total": price(total), "count": len(devices), "say": say(total, args.voice, args.lang)},
                      args.width, args.fill_char))
        return 0
    if args.kind:
        mine = [d for d in devices if d["kind"] == args.kind]
        if not mine:
            return 1
        print(", ".join(f"{d['name']} (~${round(d['usd'])})" for d in mine))
        return 0
    print(json.dumps({"threshold": threshold, "devices": devices}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
