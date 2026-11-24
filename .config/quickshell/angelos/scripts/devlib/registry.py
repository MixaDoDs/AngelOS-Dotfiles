"""Device descriptions: one JSON file a device, data and not code (docs/devices.md).

  <shell>/data/devices/<family>/<vid>-<pid>.json     the ones angelOS ships
  ~/.config/angelos/devices/*.json                   yours (a file of the same id wins)

A description names the device (USB ids), the protocol family that talks to it, the channel
it speaks through and what it can do, within which limits.

check() returns every problem of a file as {"at", "ru", "en"}; a file with problems is listed
with them and never opened as a device.
"""
import json
import os
import re
from pathlib import Path

SCHEMA = 1
KINDS = ("mouse",)
SUPPORT = ("verified", "described", "readonly")
# family -> (the channel it speaks through, the kinds of device it drives)
FAMILIES = {
    "lamzu-aurora": {"via": "hidraw", "kinds": ("mouse",)},
}
# capability -> the fields it must carry
CAPABILITIES = {
    "pollingRate": {"values": list},
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


def check(d):
    """Every problem of a parsed description, [] for a good one."""
    out = []
    if not isinstance(d, dict):
        return [_problem("", "файл должен быть объектом JSON { … }", "the file must be a JSON object { … }")]
    if d.get("schema") != SCHEMA:
        out.append(_problem("schema", "нужно \"schema\": %d — эта версия оболочки понимает только её" % SCHEMA,
                            "\"schema\": %d is required: this shell understands no other" % SCHEMA))
    if not isinstance(d.get("id"), str) or not ID_RE.match(d.get("id", "")):
        out.append(_problem("id", "id — латиница, цифры и дефис, например \"lamzu-maya-x\"",
                            "id is lower-case letters, digits and dashes, like \"lamzu-maya-x\""))
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
        out.append(_problem("usb", "нужен список usb: [{\"vid\": \"373e\", \"pid\": \"001c\"}]",
                            "a list is needed: usb: [{\"vid\": \"373e\", \"pid\": \"001c\"}]"))
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
                "via": {"enum": sorted({f["via"] for f in FAMILIES.values()})}}},
            "support": {"enum": list(SUPPORT)},
            "checked": {"type": "array", "items": {"type": "string"}, "description": "The capabilities checked on real hardware."},
            "firmware": {"type": "object"},
            "notes": {"type": "object", "properties": {"ru": {"type": "string"}, "en": {"type": "string"}}},
            "capabilities": {"type": "object", "additionalProperties": False, "properties": caps},
        },
    }
