#!/usr/bin/env python3
"""Build the clipboard's emoji catalog from Unicode emoji-test.txt and CLDR annotation XML.

Pass a directory with emoji-test.txt and CLDR release-48's en.xml, ru.xml,
en-derived.xml and ru-derived.xml (common/annotations{,Derived}).
"""

import argparse
import json
from pathlib import Path
from xml.etree import ElementTree

GROUPS = {
    "Smileys & Emotion": "faces",
    "People & Body": "people",
    "Animals & Nature": "nature",
    "Food & Drink": "food",
    "Travel & Places": "travel",
    "Activities": "activities",
    "Objects": "objects",
    "Symbols": "emoji-symbols",
    "Flags": "flags",
}


def annotations(directory, lang):
    names, keywords = {}, {}
    for suffix in ("-derived", ""):
        for item in ElementTree.parse(directory / f"{lang}{suffix}.xml").iter("annotation"):
            key = item.attrib["cp"].replace("\ufe0f", "")
            value = item.text.strip()
            if item.attrib.get("type") == "tts":
                names[key] = value
            else:
                keywords[key] = value.replace(" | ", " ")
    return names, keywords


def generate(directory):
    en_names, en_keywords = annotations(directory, "en")
    ru_names, ru_keywords = annotations(directory, "ru")
    catalog = {group: [] for group in GROUPS.values()}
    group = ""
    for line in (directory / "emoji-test.txt").read_text().splitlines():
        if line.startswith("# group: "):
            group = GROUPS.get(line.removeprefix("# group: "), "")
        if not group or not line or line.startswith("#"):
            continue
        spec, description = line.split("#", 1)
        codes, status = spec.split(";")
        points = [int(code, 16) for code in codes.split()]
        if status.strip() != "fully-qualified" or any(0x1F3FB <= cp <= 0x1F3FF for cp in points):
            continue
        glyph = "".join(map(chr, points))
        key = glyph.replace("\ufe0f", "")
        unicode_name = description.strip().split(" ", 2)[2]
        en = en_names.get(key, unicode_name)
        ru = ru_names.get(key, en)
        aliases = " ".join(filter(None, (en_keywords.get(key), ru_keywords.get(key))))
        catalog[group].append([glyph, ru, en, aliases])
    return catalog


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sources", type=Path)
    args = parser.parse_args()
    data = generate(args.sources)
    print("{")
    for number, (group, rows) in enumerate(data.items()):
        print(f'  "{group}": [')
        print(",\n".join("    " + json.dumps(row, ensure_ascii=False, separators=(",", ":")) for row in rows))
        print("  ]" + ("," if number < len(data) - 1 else ""))
    print("}")
