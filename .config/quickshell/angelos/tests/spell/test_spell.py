#!/usr/bin/env python3
"""scripts/spell.py with two tiny dictionaries made here (no network): which words are
underlined and where (QML's UTF-16 indices), what is left alone (links, paths, code, ACRONYMS,
words of a script no dictionary covers), the user's own words, switching a dictionary off, the
line protocol of `serve`, and installing/removing a dictionary from a folder standing in for
the download source.
Run: python3 tests/spell/test_spell.py   (scripts/check.sh runs it; exit 77 = no libhunspell)
"""
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "spell.py"
AFF = "SET UTF-8\nTRY абвгдеёжзийклмнопрстуфхцчшщъыьэюя\n"
RU = ["привет", "мир", "это", "заметка", "елка", "кое-как", "зелёная", "какой", "то"]
EN = ["hello", "world", "this", "is", "fine", "note"]


def write_dict(folder, code, words, aff=AFF):
    folder.mkdir(parents=True, exist_ok=True)
    (folder / (code + ".aff")).write_text(aff, encoding="utf-8")
    (folder / (code + ".dic")).write_text("%d\n%s\n" % (len(words), "\n".join(words)), encoding="utf-8")


class Spell(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp(prefix="aos-spell-"))
        self.data = self.dir / "data" / "angelos" / "spell"
        write_dict(self.data, "ru", RU)
        write_dict(self.data, "en", EN, "SET UTF-8\nTRY esianrtolcdugmphbyfvkwzxjq\n")
        self.env = {"PATH": os.environ.get("PATH", "/usr/bin"), "HOME": str(self.dir), "XDG_DATA_HOME": str(self.dir / "data"),
                    "XDG_CONFIG_HOME": str(self.dir / "config"), "ANGELOS_SPELL_SYSTEM": str(self.dir / "system"),
                    "ANGELOS_LANG": "en", "ANGELOS_TEST": "1"}

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def run_spell(self, *args, stdin=None, **env):
        done = subprocess.run([sys.executable, str(SCRIPT), *args], env=dict(self.env, **env), input=stdin,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=30)
        self.last = done
        return json.loads(done.stdout.strip().splitlines()[-1])

    def bad(self, text, *args):
        res = self.run_spell("check", *args, stdin=text)
        # every answer points at its own word, in UTF-16 units
        units = text.encode("utf-16-le")
        for e in res["errors"]:
            self.assertEqual(units[e["s"] * 2:(e["s"] + e["l"]) * 2].decode("utf-16-le"), e["w"])
        return [e["w"] for e in res["errors"]]

    def test_words_and_offsets(self):
        self.assertEqual(self.bad("Привет, мир! Это замтка. Hello wrold, this is fine."), ["замтка", "wrold"])
        self.assertEqual(self.bad("😀 привет 😀😀 мирр и wrld"), ["мирр", "wrld"])
        self.assertEqual(self.bad("Ёлка зелёная, ёлка, элка"), ["элка"])              # ё for е is no mistake
        self.assertEqual(self.bad("кое-как какой-то чтото-то"), ["чтото"])            # a compound: only its bad half
        self.assertEqual(self.bad(""), [])

    def test_left_alone(self):
        text = "https://exmaple.com/pth www.exmpl.org mail@exmpl.com ~/Dokuments/fle /usr/lcal ./fle `kod wrng` @nik #tegg NASA myVar h264 x a_b_c 3rd"
        self.assertEqual(self.bad(text), [])

    def test_script_without_a_dictionary(self):
        shutil.rmtree(self.data)
        write_dict(self.data, "ru", RU)
        self.assertEqual(self.bad("привет wrold ошибкаа"), ["ошибкаа"])               # no English dictionary: English is not judged
        self.assertEqual(self.bad("привет wrold ошибкаа", "--off", "ru"), [])
        shutil.rmtree(self.data)
        self.assertEqual(self.bad("привет wrold"), [])                                # no dictionaries at all

    def test_off_and_own_words(self):
        self.assertEqual(self.bad("hello wrold мирр", "--off", "en"), ["мирр"])
        self.assertTrue(self.run_spell("add", "Wrold")["ok"])
        self.assertEqual(self.bad("hello wrold мирр"), ["мирр"])
        self.assertEqual((self.dir / "config/angelos/spell-words.txt").read_text(), "wrold\n")
        self.run_spell("forget", "wrold")
        self.assertEqual(self.bad("hello wrold"), ["wrold"])

    def test_suggest(self):
        self.assertIn("world", self.run_spell("suggest", "wrold")["suggest"])
        self.assertEqual(self.run_spell("suggest", "привт")["suggest"][:1], ["привет"])

    def test_serve(self):
        lines = [{"id": 1, "op": "check", "text": "hello wrold"}, {"id": 2, "op": "suggest", "word": "wrold"},
                 {"id": 3, "op": "add", "word": "wrold"}, {"id": 4, "op": "check", "text": "hello wrold"},
                 {"id": 5, "op": "check", "text": "hello wrold мирр", "off": ["ru"]}, {"id": 6, "op": "nope"},
                 {"id": 7, "op": "forget", "word": "wrold"}, {"id": 8, "op": "reload"}, {"id": 9, "op": "check", "text": "wrold"}]
        done = subprocess.run([sys.executable, str(SCRIPT), "serve"], env=self.env, text=True, timeout=30, stdout=subprocess.PIPE,
                              input="".join(json.dumps(l, ensure_ascii=False) + "\n" for l in lines) + "not json\n")
        got = {a["id"]: a for a in map(json.loads, done.stdout.splitlines())}
        self.assertEqual([e["w"] for e in got[1]["errors"]], ["wrold"])
        self.assertIn("world", got[2]["suggest"])
        self.assertEqual(got[4]["errors"], [])
        self.assertEqual(got[5]["errors"], [])
        self.assertIn("error", got[6])
        self.assertEqual([e["w"] for e in got[9]["errors"]], ["wrold"])

    def test_langs_install_remove(self):
        write_dict(self.dir / "system", "de_DE", ["hallo"])
        (self.dir / "system" / "hyph_de_DE.dic").write_text("x")
        res = self.run_spell("langs")
        self.assertTrue(res["engine"])
        self.assertEqual([(d["code"], d["source"], d["script"]) for d in res["installed"]],
                         [("en", "user", "LATIN"), ("ru", "user", "CYRILLIC"), ("de_DE", "system", "LATIN")])
        self.assertEqual(res["installed"][2]["en"], "German (DE)")
        self.assertEqual([c["code"] for c in res["catalog"][:2]], ["ru", "en"])
        self.assertTrue(res["catalog"][0]["installed"] and res["catalog"][0]["top"])
        self.assertGreater(len(res["catalog"]), 80)
        # the download source, standing in a folder: <source>/<ref>/dictionaries/<code>/index.*
        ref = json.loads((ROOT / "data/spell-langs.json").read_text())["ref"]
        src = self.dir / "src" / ref / "dictionaries"
        write_dict(src / "uk", "index", ["привіт"])
        (src / "uk" / "license").write_text("MIT")
        write_dict(src / "pl", "index", ["x"])
        (src / "pl" / "index.dic").write_text("<html>Not found</html>")
        source = (self.dir / "src").as_uri()
        self.assertTrue(self.run_spell("install", "uk", ANGELOS_SPELL_SOURCE=source)["ok"])
        self.assertEqual(sorted(p.name for p in self.data.glob("uk.*")), ["uk.aff", "uk.dic", "uk.license"])
        self.assertEqual(self.bad("привіт привт"), ["привт"])
        self.assertFalse(self.run_spell("install", "pl", ANGELOS_SPELL_SOURCE=source)["ok"])       # a page, not a dictionary
        self.assertFalse(self.run_spell("install", "de", ANGELOS_SPELL_SOURCE=source)["ok"])       # not there
        self.assertFalse(self.run_spell("install", "../../etc", ANGELOS_SPELL_SOURCE=source)["ok"])
        self.assertEqual(sorted(p.name for p in self.data.iterdir() if "pl" in p.name or "de" in p.name or "part" in p.name), [])
        self.assertTrue(self.run_spell("remove", "uk")["ok"])
        self.assertFalse(self.run_spell("remove", "uk")["ok"])
        self.assertFalse(self.run_spell("remove", "../ru")["ok"])
        self.assertTrue((self.data / "ru.dic").exists())


if __name__ == "__main__":
    spec = importlib.util.spec_from_file_location("spell", SCRIPT)
    spell = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(spell)
    if not spell.lib():
        print("no libhunspell here: the spelling check has nothing to run on")
        sys.exit(77)
    unittest.main(verbosity=2)
