"""Device descriptions: one JSON file a device, data and not code (docs/devices.md).

  <shell>/data/devices/<family>/<vid>-<pid>.json     the ones angelOS ships
  ~/.config/angelos/devices/*.json                   yours (a file of the same id wins)

A description names the device (USB ids), the protocol family that talks to it, the channel
(which interface, which endpoints), what it can do and within which limits, and its keys:
where each one sits on the picture and which slot of the protocol's key matrix it is.

check() returns every problem of a file as {"at", "ru", "en"}; a file with problems is listed
with them and never opened as a device.
"""
import json
import os
import re
from pathlib import Path

SCHEMA = 1
KINDS = ("keyboard", "mouse")
SUPPORT = ("verified", "described", "readonly")
# family -> (the channel it speaks through, the kinds of device it drives)
FAMILIES = {
    "nuphy-io": {"via": "usbfs", "kinds": ("keyboard",)},
    "lamzu-aurora": {"via": "hidraw", "kinds": ("mouse",)},
}
# capability -> the fields it must carry
CAPABILITIES = {
    "liveTravel": {},
    "actuation": {"min": float, "max": float, "step": float},
    "rapidTrigger": {"min": float, "max": float, "steps": list},
    "deadZones": {"max": float},
    "socd": {"modes": list},
    "dks": {}, "modTap": {}, "toggle": {}, "remap": {}, "layers": {}, "macros": {}, "lighting": {},
    "pollingRate": {"values": list}, "calibration": {}, "profiles": {},
    "dpi": {"min": float, "max": float, "step": float, "stages": float},
    "lod": {"values": list}, "debounce": {"min": float, "max": float}, "motionSync": {},
    "sleep": {"values": list}, "battery": {}, "angleSnap": {}, "rippleControl": {},
}
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,62}$")
HEX4_RE = re.compile(r"^[0-9a-fA-F]{4}$")


def shell_dir():
    return Path(__file__).resolve().parent.parent.parent


def builtin_dir():
    return Path(os.environ.get("ANGELOS_DEVICES_BUILTIN") or shell_dir() / "data/devices")


def user_dir():
    custom = os.environ.get("ANGELOS_DEVICES_DIR")
    if custom:
        return Path(custom)
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "angelos/devices"


def _problem(at, ru, en):
    return {"at": at, "ru": ru, "en": en}


def _num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _ep(v):
    """An endpoint address: 0x82, "0x82" or 130."""
    try:
        n = int(v, 0) if isinstance(v, str) else int(v)
    except (TypeError, ValueError):
        return None
    return n if 0 < n <= 0xFF else None


def check(d):
    """Every problem of a parsed description, [] for a good one."""
    out = []
    if not isinstance(d, dict):
        return [_problem("", "файл должен быть объектом JSON { … }", "the file must be a JSON object { … }")]
    if d.get("schema") != SCHEMA:
        out.append(_problem("schema", "нужно \"schema\": %d — эта версия оболочки понимает только её" % SCHEMA,
                            "\"schema\": %d is required: this shell understands no other" % SCHEMA))
    if not isinstance(d.get("id"), str) or not ID_RE.match(d.get("id", "")):
        out.append(_problem("id", "id — латиница, цифры и дефис, например \"nuphy-air60-he\"",
                            "id is lower-case letters, digits and dashes, like \"nuphy-air60-he\""))
    if not isinstance(d.get("name"), str) or not d.get("name", "").strip():
        out.append(_problem("name", "нет названия устройства", "the device has no name"))
    kind = d.get("kind")
    if kind not in KINDS:
        out.append(_problem("kind", "kind — одно из: " + ", ".join(KINDS), "kind is one of: " + ", ".join(KINDS)))
    family = d.get("family")
    if family not in FAMILIES:
        out.append(_problem("family", "неизвестное семейство протокола «%s»; есть: %s" % (family, ", ".join(sorted(FAMILIES))),
                            "unknown protocol family \"%s\"; there are: %s" % (family, ", ".join(sorted(FAMILIES)))))
    elif kind in KINDS and kind not in FAMILIES[family]["kinds"]:
        out.append(_problem("family", "семейство %s не работает с устройствами вида %s" % (family, kind),
                            "the family %s does not drive a %s" % (family, kind)))
    if d.get("support") not in SUPPORT:
        out.append(_problem("support", "support — одно из: verified (проверено на железе), described (по описанию), readonly (только чтение)",
                            "support is one of: verified (checked on hardware), described (by the description), readonly"))

    usb = d.get("usb")
    if not isinstance(usb, list) or not usb:
        out.append(_problem("usb", "нужен список usb: [{\"vid\": \"19f5\", \"pid\": \"fee0\"}]",
                            "a list is needed: usb: [{\"vid\": \"19f5\", \"pid\": \"fee0\"}]"))
    else:
        for n, u in enumerate(usb):
            if not isinstance(u, dict) or not HEX4_RE.match(str(u.get("vid", ""))) or not HEX4_RE.match(str(u.get("pid", ""))):
                out.append(_problem("usb[%d]" % n, "vid и pid — по четыре шестнадцатеричные цифры в кавычках",
                                    "vid and pid are four hex digits each, in quotes"))

    ch = d.get("channel")
    if not isinstance(ch, dict):
        out.append(_problem("channel", "нет описания служебного канала (channel)", "the service channel (channel) is not described"))
    else:
        via = FAMILIES.get(family, {}).get("via")
        if via and ch.get("via") != via:
            out.append(_problem("channel.via", "семейство %s говорит через «%s»" % (family, via),
                                "the family %s speaks through \"%s\"" % (family, via)))
        if ch.get("via") == "usbfs" and (not isinstance(ch.get("interface"), int) or isinstance(ch.get("interface"), bool) or not 0 <= ch["interface"] <= 31):
            out.append(_problem("channel.interface", "interface — номер USB-интерфейса служебного канала (число)",
                                "interface is the number of the service channel's USB interface"))
        if ch.get("via") == "usbfs":
            i, o = _ep(ch.get("in")), _ep(ch.get("out"))
            if i is None or not i & 0x80:
                out.append(_problem("channel.in", "in — адрес входящей конечной точки, например \"0x82\"",
                                    "in is the IN endpoint's address, like \"0x82\""))
            if o is None or o & 0x80:
                out.append(_problem("channel.out", "out — адрес исходящей конечной точки, например \"0x02\"",
                                    "out is the OUT endpoint's address, like \"0x02\""))

    caps = d.get("capabilities")
    if not isinstance(caps, dict):
        out.append(_problem("capabilities", "нет списка возможностей (capabilities)", "the capabilities are not listed"))
    else:
        for name, value in caps.items():
            at = "capabilities." + name
            if name not in CAPABILITIES:
                out.append(_problem(at, "неизвестная возможность; есть: " + ", ".join(sorted(CAPABILITIES)),
                                    "unknown capability; there are: " + ", ".join(sorted(CAPABILITIES))))
                continue
            if value is False:
                continue
            fields = CAPABILITIES[name]
            if value is True and not fields:
                continue
            if not isinstance(value, dict):
                out.append(_problem(at, "нужен объект с пределами: " + ", ".join(fields) if fields else "true или объект",
                                    "an object with its limits is needed: " + ", ".join(fields) if fields else "true or an object"))
                continue
            for f, t in fields.items():
                v = value.get(f)
                good = _num(v) if t is float else isinstance(v, list) and len(v) > 0
                if not good:
                    out.append(_problem(at + "." + f, "нужно %s" % ("число" if t is float else "непустой список"),
                                        "%s is needed" % ("a number" if t is float else "a list that is not empty")))
            if _num(value.get("min")) and _num(value.get("max")) and value["min"] > value["max"]:
                out.append(_problem(at, "min больше max", "min is above max"))

    if kind == "keyboard":
        out += _check_layout(d.get("layout"))
    sw = d.get("switches")
    if sw is not None:
        if not isinstance(sw, list):
            out.append(_problem("switches", "switches — список", "switches is a list"))
        else:
            for n, s in enumerate(sw):
                if not isinstance(s, dict) or not isinstance(s.get("id"), int) or not _num(s.get("travel")) or not s.get("name"):
                    out.append(_problem("switches[%d]" % n, "переключателю нужны id (число), name и travel (ход в мм)",
                                        "a switch needs id (a number), name and travel (mm)"))
    return out


def _check_layout(layout):
    out = []
    keys = layout.get("keys") if isinstance(layout, dict) else None
    if not isinstance(keys, list) or not keys:
        return [_problem("layout.keys", "клавиатуре нужна раскладка: layout.keys — список клавиш",
                         "a keyboard needs its layout: layout.keys is the list of keys")]
    seen = {}
    for n, k in enumerate(keys):
        at = "layout.keys[%d]" % n
        if not isinstance(k, dict):
            out.append(_problem(at, "клавиша — объект { \"m\": …, \"x\": …, \"y\": … }", "a key is an object { \"m\": …, \"x\": …, \"y\": … }"))
            continue
        m = k.get("m")
        if not isinstance(m, int) or isinstance(m, bool) or not 0 <= m <= 255:
            out.append(_problem(at + ".m", "m — номер клавиши в протоколе, 0…255", "m is the key's number in the protocol, 0…255"))
        elif m in seen:
            out.append(_problem(at + ".m", "номер %d уже занят клавишей %d" % (m, seen[m]), "number %d is taken by key %d already" % (m, seen[m])))
        else:
            seen[m] = n
        for f in ("x", "y"):
            if not _num(k.get(f)) or k[f] < 0 or k[f] > 40:
                out.append(_problem(at + "." + f, "%s — положение в ширинах клавиши, 0…40" % f, "%s is the position in key widths, 0…40" % f))
        for f in ("w", "h"):
            if f in k and (not _num(k[f]) or not 0.25 <= k[f] <= 12):
                out.append(_problem(at + "." + f, "%s — размер в ширинах клавиши, 0.25…12" % f, "%s is the size in key widths, 0.25…12" % f))
        if "default" in k and not (isinstance(k["default"], list) and len(k["default"]) == 3 and all(isinstance(b, int) and 0 <= b <= 255 for b in k["default"])):
            out.append(_problem(at + ".default", "default — три байта заводского действия клавиши", "default is the three bytes of the key's factory action"))
        if len(out) > 40:
            break
    return out


def load_file(path):
    """(description or None, problems). A description gets "file" and "origin" added."""
    path = Path(path)
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as e:
        return None, [_problem("", "файл не читается: %s" % e.strerror, "the file cannot be read: %s" % e.strerror)]
    if len(text) > 2_000_000:
        return None, [_problem("", "файл больше 2 МБ — это не описание устройства", "the file is over 2 MB: not a device description")]
    try:
        d = json.loads(text)
    except ValueError as e:
        line = getattr(e, "lineno", 0)
        return None, [_problem("", "это не JSON: строка %d, %s" % (line, getattr(e, "msg", e)),
                               "not JSON: line %d, %s" % (line, getattr(e, "msg", e)))]
    problems = check(d)
    if problems:
        return None, problems
    d["file"] = str(path)
    return d, []


def load_all():
    """(descriptions, broken) from both folders; the user's file of an id replaces the shipped one.
    broken: [{"file", "problems"}]."""
    found, broken = {}, []
    for origin, root, pattern in (("builtin", builtin_dir(), "*/*.json"), ("user", user_dir(), "*.json")):
        try:
            files = sorted(root.glob(pattern))
        except OSError:
            continue
        for f in files:
            if f.name == "schema.json":
                continue
            d, problems = load_file(f)
            if d is None:
                broken.append({"file": str(f), "origin": origin, "problems": problems})
                continue
            d["origin"] = origin
            found[d["id"]] = d
    return list(found.values()), broken


def stamp():
    """Changes whenever a description is added, removed or edited: what a running helper
    watches to pick new files up without a restart."""
    out = []
    for root, pattern in ((builtin_dir(), "*/*.json"), (user_dir(), "*.json")):
        try:
            for f in root.glob(pattern):
                st = f.stat()
                out.append((str(f), st.st_mtime_ns, st.st_size))
        except OSError:
            continue
    return tuple(sorted(out))


def endpoint(value):
    return _ep(value)


def schema():
    """The same rules as check(), as a JSON Schema for editors (data/devices/schema.json is
    this, written by `angelos devices schema`)."""
    num = {"type": "number"}
    caps = {}
    for name, fields in CAPABILITIES.items():
        if not fields:
            caps[name] = {"type": ["boolean", "object"]}
        else:
            props = {f: (num if t is float else {"type": "array", "minItems": 1}) for f, t in fields.items()}
            caps[name] = {"anyOf": [{"const": False}, {"type": "object", "required": list(fields), "properties": props}]}
    hex4 = {"type": "string", "pattern": "^[0-9a-fA-F]{4}$"}
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "angelOS device description",
        "description": "One device of the devices' driver (docs/devices.md). `angelos devices check FILE` is the checker the shell itself uses; this schema is the same rules for editors.",
        "type": "object",
        "required": ["schema", "id", "name", "kind", "family", "usb", "channel", "support", "capabilities"],
        "properties": {
            "schema": {"const": SCHEMA},
            "id": {"type": "string", "pattern": "^[a-z0-9][a-z0-9-]{1,62}$"},
            "name": {"type": "string", "minLength": 1},
            "maker": {"type": "string"},
            "kind": {"enum": list(KINDS)},
            "family": {"enum": sorted(FAMILIES)},
            "usb": {"type": "array", "minItems": 1, "items": {"type": "object", "required": ["vid", "pid"], "properties": {"vid": hex4, "pid": hex4}}},
            "channel": {"type": "object", "required": ["via"], "properties": {
                "via": {"enum": sorted({f["via"] for f in FAMILIES.values()})},
                "interface": {"type": "integer", "minimum": 0, "maximum": 31},
                "in": {"type": ["string", "integer"]}, "out": {"type": ["string", "integer"]}}},
            "support": {"enum": list(SUPPORT)},
            "checked": {"type": "array", "items": {"type": "string"}, "description": "The capabilities checked on real hardware."},
            "firmware": {"type": "object"},
            "notes": {"type": "object", "properties": {"ru": {"type": "string"}, "en": {"type": "string"}}},
            "capabilities": {"type": "object", "additionalProperties": False, "properties": caps},
            "switches": {"type": "array", "items": {"type": "object", "required": ["id", "name", "travel"], "properties": {"id": {"type": "integer"}, "name": {"type": "string"}, "travel": num}}},
            "layout": {"type": "object", "required": ["keys"], "properties": {"keys": {"type": "array", "minItems": 1, "items": {"type": "object", "required": ["m", "x", "y"], "properties": {
                "m": {"type": "integer", "minimum": 0, "maximum": 255, "description": "The key's number in the protocol (its slot of the key matrix)."},
                "x": {"type": "number", "minimum": 0, "maximum": 40}, "y": {"type": "number", "minimum": 0, "maximum": 40},
                "w": {"type": "number", "minimum": 0.25, "maximum": 12}, "h": {"type": "number", "minimum": 0.25, "maximum": 12},
                "label": {"type": "string"},
                "default": {"type": "array", "minItems": 3, "maxItems": 3, "items": {"type": "integer", "minimum": 0, "maximum": 255}, "description": "The three bytes of the key's factory action."}}}}}},
        },
    }
