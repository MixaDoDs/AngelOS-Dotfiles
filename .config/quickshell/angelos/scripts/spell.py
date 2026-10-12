#!/usr/bin/env python3
"""Spelling for the shell's own text fields (services/Spell, widgets/PxSpell, Settings → Devices →
Spelling, `angelos spell`): which words are misspelt, what they could have been, and the
dictionaries themselves — downloaded per language into the user's own folder, no root.

  spell.py langs                 JSON {"engine": bool, "installed": [{code, ru, en, source, script}],
                                 "catalog": [{code, ru, en, installed, top}]}
  spell.py install CODE          download a dictionary of data/spell-langs.json; JSON {"ok", "error"}
  spell.py remove CODE           delete a downloaded one
  spell.py check [--off A,B]     the text on stdin → JSON {"errors": [{s, l, w}]}: start and
                                 length in UTF-16 units (QML's string indices), the word
  spell.py suggest WORD          JSON {"suggest": [word…]}
  spell.py add WORD | forget WORD   the user's own words (~/.config/angelos/spell-words.txt)
  spell.py serve                 the same over stdin/stdout, one JSON object a line, dictionaries
                                 kept loaded: {"id", "op": "check", "text", "off": [code…]} →
                                 {"id", "errors"}; "suggest"/"add"/"forget" with "word"; "reload"

The engine is libhunspell (the hunspell package), loaded with ctypes. Dictionaries: the user's
(~/.local/share/angelos/spell/CODE.aff + .dic) and the system's (/usr/share/hunspell,
/usr/share/myspell/dicts). A word is checked only against dictionaries of its own script:
with only a Russian dictionary installed, English words are left alone, not underlined.
"""
import ctypes
import ctypes.util
import glob
import json
import os
import re
import sys
import unicodedata
import urllib.error
import urllib.request
from pathlib import Path

RU = os.environ.get("ANGELOS_LANG", "ru") != "en"
HERE = Path(__file__).resolve().parent
CATALOG = HERE.parent / "data" / "spell-langs.json"
USER_DIR = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "angelos" / "spell"
WORDS = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "angelos" / "spell-words.txt"
SYSTEM_DIRS = [Path(p) for p in os.environ.get("ANGELOS_SPELL_SYSTEM", "/usr/share/hunspell:/usr/share/myspell/dicts").split(":") if p]
CODE_RE = re.compile(r"[A-Za-z]{2,3}(?:[-_][A-Za-z0-9]{2,8})*\Z")
MAX_TEXT = 20000
MAX_ERRORS = 200
MAX_FILE = 80 * 1024 * 1024

WORD_RE = re.compile(r"[^\W\d_]+(?:['’\-][^\W\d_]+)*")
# not prose: links, mail, paths, @names and #tags, `code`
SKIP_RE = re.compile(r"\b[a-zA-Z][\w+.\-]*://\S+|\bwww\.\S+|\S+@\S+\.\S+|(?:^|(?<=\s))[~.]{0,2}/\S+|[@#]\w+|`[^`\n]*`")


def t(ru, en):
    return ru if RU else en


def out(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def catalog():
    try:
        return json.loads(CATALOG.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {"langs": [], "top": [], "source": "", "ref": ""}


def script_of(ch):
    """LATIN, CYRILLIC, GREEK… of a letter ("" for anything else)."""
    if not ch.isalpha():
        return ""
    try:
        return unicodedata.name(ch).split(" ", 1)[0]
    except ValueError:
        return ""


def dictionaries():
    """[{code, aff, dic, source}]: the user's first, then the system's."""
    found, seen = [], set()
    for source, folder in [("user", USER_DIR)] + [("system", d) for d in SYSTEM_DIRS]:
        for dic in sorted(glob.glob(str(folder / "*.dic"))):
            code = Path(dic).stem
            aff = dic[:-4] + ".aff"
            if code.startswith("hyph_") or not os.path.isfile(aff) or os.path.realpath(dic) in seen:
                continue
            seen.add(os.path.realpath(dic))
            found.append({"code": code, "aff": aff, "dic": dic, "source": source})
    return found


def names(code, cat):
    """a dictionary's name in both languages: the catalog's, or the code itself"""
    by = {l["code"].lower(): l for l in cat.get("langs", [])}
    key = code.replace("_", "-").lower()
    hit = by.get(key) or by.get(key.split("-")[0])
    if hit and key not in by and "-" in key:
        region = code.replace("_", "-").split("-", 1)[1]
        return hit["ru"].split(" (")[0] + " (" + region + ")", hit["en"].split(" (")[0] + " (" + region + ")"
    return (hit["ru"], hit["en"]) if hit else (code, code)


# ---- the engine ----
_lib = None


def lib():
    global _lib
    if _lib is None:
        name = ctypes.util.find_library("hunspell") or next(iter(sorted(glob.glob("/usr/lib*/libhunspell*.so*"))), None)
        if not name:
            _lib = False
            return _lib
        try:
            h = ctypes.CDLL(name)
        except OSError:
            _lib = False
            return _lib
        h.Hunspell_create.restype = ctypes.c_void_p
        h.Hunspell_create.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
        h.Hunspell_destroy.argtypes = [ctypes.c_void_p]
        h.Hunspell_spell.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        h.Hunspell_get_dic_encoding.restype = ctypes.c_char_p
        h.Hunspell_get_dic_encoding.argtypes = [ctypes.c_void_p]
        h.Hunspell_suggest.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.POINTER(ctypes.c_char_p)), ctypes.c_char_p]
        h.Hunspell_free_list.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.POINTER(ctypes.c_char_p)), ctypes.c_int]
        _lib = h
    return _lib


def dic_script(dic):
    """the script most of a dictionary's words are written in"""
    count = {}
    try:
        with open(dic, "rb") as f:
            head = f.read(40000)
    except OSError:
        return ""
    for enc in ("utf-8", "koi8-r", "latin-1"):
        try:
            text = head.decode(enc)
            break
        except UnicodeDecodeError:
            continue
    for line in text.splitlines()[1:600]:
        for ch in line.split("/")[0]:
            s = script_of(ch)
            if s:
                count[s] = count.get(s, 0) + 1
    return max(count, key=count.get) if count else ""


class Dict:
    def __init__(self, info):
        self.code = info["code"]
        self.h = lib().Hunspell_create(info["aff"].encode(), info["dic"].encode())
        self.enc = (lib().Hunspell_get_dic_encoding(self.h) or b"utf-8").decode("ascii", "replace")
        try:
            "a".encode(self.enc)
        except LookupError:
            self.enc = "utf-8"
        self.script = dic_script(info["dic"])

    def ok(self, word):
        try:
            return lib().Hunspell_spell(self.h, word.encode(self.enc)) != 0
        except UnicodeEncodeError:
            return False

    def suggest(self, word):
        try:
            raw = word.encode(self.enc)
        except UnicodeEncodeError:
            return []
        lst = ctypes.POINTER(ctypes.c_char_p)()
        n = lib().Hunspell_suggest(self.h, ctypes.byref(lst), raw)
        res = [lst[i].decode(self.enc, "replace") for i in range(n)]
        if n:
            lib().Hunspell_free_list(self.h, ctypes.byref(lst), n)
        return res

    def close(self):
        if self.h:
            lib().Hunspell_destroy(self.h)
            self.h = None


class Speller:
    def __init__(self):
        self.dicts = None
        self.words = None

    def load(self):
        if self.dicts is None:
            self.dicts = [Dict(d) for d in dictionaries()] if lib() else []
        if self.words is None:
            try:
                self.words = {w.strip().lower() for w in WORDS.read_text(encoding="utf-8").splitlines() if w.strip()}
            except OSError:
                self.words = set()

    def reload(self):
        for d in self.dicts or []:
            d.close()
        self.dicts = None
        self.words = None

    def for_word(self, word, off):
        scripts = {script_of(c) for c in word} - {""}
        return [d for d in self.dicts if d.code not in off and d.script in scripts]

    def good(self, word, off):
        """True when some dictionary of the word's script takes it — or none is there to ask."""
        if word.lower() in self.words:
            return True
        plain = word.replace("’", "'")
        mine = self.for_word(plain, off)
        if not mine:
            return True
        forms = [plain] + ([plain.replace("ё", "е").replace("Ё", "Е")] if "ё" in plain.lower() else [])
        return any(d.ok(f) for d in mine for f in forms)

    def check(self, text, off=()):
        self.load()
        text = text[:MAX_TEXT]
        if not self.dicts:
            return []
        off = set(off)
        skip = [m.span() for m in SKIP_RE.finditer(text)]
        errors = []
        for m in WORD_RE.finditer(text):
            word, start = m.group(), m.start()
            if len(word) < 2 or any(a <= start < b for a, b in skip):
                continue
            # a number's or an identifier's part (h264, my_var), an ACRONYM, camelCase
            before, after = text[start - 1:start], text[m.end():m.end() + 1]
            if before.isdigit() or before == "_" or after.isdigit() or after == "_":
                continue
            if word.isupper() or any(c.isupper() for c in word[1:]):
                continue
            if self.good(word, off):
                continue
            # a compound the dictionary doesn't know whole: only its bad halves
            parts = [(p.group(), start + p.start()) for p in re.finditer(r"[^\-]+", word)] if "-" in word else [(word, start)]
            for part, at in parts:
                if len(parts) > 1 and (len(part) < 2 or self.good(part, off)):
                    continue
                errors.append((at, len(part), part))
                if len(errors) >= MAX_ERRORS:
                    break
            if len(errors) >= MAX_ERRORS:
                break
        return utf16(text, errors)

    def suggest(self, word, off=()):
        self.load()
        seen, res = set(), []
        for d in self.for_word(word, set(off)):
            for s in d.suggest(word):
                if s.lower() not in seen:
                    seen.add(s.lower())
                    res.append(s)
        return res[:6]

    def add(self, word, keep=True):
        self.load()
        word = word.strip()
        if not word or len(word) > 80 or "\n" in word:
            return False
        if keep:
            self.words.add(word.lower())
        else:
            self.words.discard(word.lower())
        WORDS.parent.mkdir(parents=True, exist_ok=True)
        tmp = WORDS.with_suffix(".tmp")
        tmp.write_text("".join(w + "\n" for w in sorted(self.words)), encoding="utf-8")
        os.replace(tmp, WORDS)
        return True


def utf16(text, errors):
    """Python's indices count characters, QML's count UTF-16 units: an emoji is two there."""
    if all(ord(c) < 0x10000 for c in text):
        return [{"s": s, "l": l, "w": w} for s, l, w in errors]
    at, n = [0], 0
    for c in text:
        n += 2 if ord(c) >= 0x10000 else 1
        at.append(n)
    return [{"s": at[s], "l": at[s + l] - at[s], "w": w} for s, l, w in errors]


# ---- the dictionaries ----
def langs():
    cat = catalog()
    installed = []
    for d in dictionaries():
        ru, en = names(d["code"], cat)
        installed.append({"code": d["code"], "ru": ru, "en": en, "source": d["source"], "script": dic_script(d["dic"])})
    have = {d["code"] for d in installed if d["source"] == "user"}
    top = cat.get("top", [])
    rows = [dict(l, installed=l["code"] in have, top=l["code"] in top) for l in cat.get("langs", [])]
    rows.sort(key=lambda l: (top.index(l["code"]) if l["code"] in top else len(top), l["ru" if RU else "en"]))
    out({"engine": bool(lib()), "installed": installed, "catalog": rows})
    return 0


def fetch(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": "angelOS-spell"})
    with urllib.request.urlopen(req, timeout=40) as r, open(dest, "wb") as f:
        size = 0
        while True:
            chunk = r.read(65536)
            if not chunk:
                break
            size += len(chunk)
            if size > MAX_FILE:
                raise ValueError("too big")
            f.write(chunk)
    return size


def install(code):
    cat = catalog()
    if not CODE_RE.match(code) or code not in {l["code"] for l in cat.get("langs", [])}:
        out({"ok": False, "error": t("нет такого словаря: ", "no such dictionary: ") + code})
        return 2
    base = "%s/%s/dictionaries/%s/" % (os.environ.get("ANGELOS_SPELL_SOURCE") or cat["source"], cat["ref"], code)
    USER_DIR.mkdir(parents=True, exist_ok=True)
    parts = {ext: USER_DIR / (".%s.%s.part" % (code, ext)) for ext in ("aff", "dic", "license")}
    try:
        fetch(base + "index.aff", parts["aff"])
        fetch(base + "index.dic", parts["dic"])
        try:
            fetch(base + "license", parts["license"])
        except (urllib.error.URLError, OSError, ValueError):
            pass
        # a dictionary, not a page saying "not found": its first line counts the words
        with open(parts["dic"], "rb") as f:
            first = f.readline().strip()
        if not first.split()[0:1] or not first.split()[0].isdigit():
            raise ValueError(t("это не словарь", "that is no dictionary"))
        if lib():
            probe = Dict({"code": code, "aff": str(parts["aff"]), "dic": str(parts["dic"])})
            probe.ok("a")
            probe.close()
        for ext, part in parts.items():
            if part.exists():
                os.replace(part, USER_DIR / ("%s.%s" % (code, ext)))
    except (urllib.error.URLError, OSError, ValueError) as e:
        for part in parts.values():
            try:
                part.unlink()
            except OSError:
                pass
        reason = getattr(e, "reason", None) or e
        out({"ok": False, "error": t("не скачалось: ", "the download failed: ") + str(reason)})
        return 1
    out({"ok": True, "code": code})
    return 0


def remove(code):
    if not CODE_RE.match(code):
        out({"ok": False, "error": "bad code"})
        return 2
    gone = False
    for ext in ("aff", "dic", "license"):
        try:
            (USER_DIR / ("%s.%s" % (code, ext))).unlink()
            gone = True
        except OSError:
            pass
    out({"ok": gone, "error": "" if gone else t("такого словаря нет", "no such dictionary")})
    return 0 if gone else 1


def serve():
    sp = Speller()
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except ValueError:
            continue
        op, rid = req.get("op"), req.get("id")
        try:
            if op == "check":
                out({"id": rid, "errors": sp.check(str(req.get("text", "")), req.get("off") or ())})
            elif op == "suggest":
                out({"id": rid, "suggest": sp.suggest(str(req.get("word", "")), req.get("off") or ())})
            elif op in ("add", "forget"):
                out({"id": rid, "ok": sp.add(str(req.get("word", "")), op == "add")})
            elif op == "reload":
                sp.reload()
                out({"id": rid, "ok": True})
            else:
                out({"id": rid, "error": "op?"})
        except Exception as e:   # one bad request must not end the service
            out({"id": rid, "error": str(e), "errors": [], "suggest": []})
    return 0


def main(argv):
    cmd = argv[0] if argv else "langs"
    if cmd == "langs":
        return langs()
    if cmd == "serve":
        return serve()
    if cmd == "check":
        off = argv[argv.index("--off") + 1].split(",") if "--off" in argv and len(argv) > argv.index("--off") + 1 else []
        out({"errors": Speller().check(sys.stdin.read(), off), "engine": bool(lib())})
        return 0
    if cmd in ("install", "remove", "suggest", "add", "forget") and len(argv) == 2:
        if cmd == "install":
            return install(argv[1])
        if cmd == "remove":
            return remove(argv[1])
        if cmd == "suggest":
            out({"suggest": Speller().suggest(argv[1])})
            return 0
        out({"ok": Speller().add(argv[1], cmd == "add")})
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
