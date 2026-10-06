#!/usr/bin/env python3
"""Exercise Story.voiceLine in Qt against every authored voice in both languages."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class VoicePlaceholders(unittest.TestCase):
    def test_all_voices(self):
        source = (ROOT / 'services/Story.qml').read_text()
        start = source.index('    function voiceLine(kind) {')
        end = source.index('\n    }', start) + len('\n    }')
        function = source[start:end].replace(
            'function voiceLine(kind) {',
            '''function voiceLine(kind) {
        const HellLook = {voice: voice};
        const I18n = {english: english};
        const Theme = {roman: function(n) { return "IV"; }};''')
        voices = json.loads((ROOT / 'story/voices.json').read_text())
        qml = '''import QtQuick
import QtTest
TestCase {
    name: "StoryVoicePlaceholders"
    property var voices: VOICES
    property string voice: ""
    property bool english: false
    property bool inHell: true
    property string circle: "greed"
    function render(text) { return text; }
    function circleName(id) { return english ? "Greed" : "Жадность"; }
    function circleN(id) { return 4; }
    FUNCTION
    function test_authored_lines() {
        for (const lang of [false, true]) {
            english = lang;
            for (const key of Object.keys(voices)) {
                if (!voices[key].enter) continue;
                voice = key;
                for (const kind of Object.keys(voices[key])) {
                    const lines = voices[key][kind];
                    if (!Array.isArray(lines)) continue;
                    // Restrict selection to each line to cover every random alternative.
                    const saved = lines.slice();
                    for (const entry of saved) {
                        voices[key][kind] = [entry];
                        const raw = Array.isArray(entry) ? entry[english ? 1 : 0] : entry;
                        const actual = voiceLine(kind);
                        if (kind === "enter") {
                            compare(actual, raw.replace("%1", circleName(circle)).replace("%2", "IV"), key + "/enter");
                        } else {
                            compare(actual, raw, key + "/" + kind);
                            if (kind === "wait") {
                                compare(actual.replace("%1", "7"), raw.replace("%1", "7"), key + "/minutes");
                            }
                            if (kind === "music") {
                                compare(actual.replace("%1", "ARTIST").replace("%2", "SONG"), raw.replace("%1", "ARTIST").replace("%2", "SONG"), key + "/track");
                            }
                        }
                    }
                    voices[key][kind] = saved;
                }
            }
        }
    }
    function test_missing_and_outside_hell() {
        voice = "registry";
        inHell = false;
        compare(voiceLine("wait"), "");
        inHell = true;
        compare(voiceLine("unknown"), "");
        voice = "unknown";
        compare(voiceLine("wait"), "");
    }
}'''.replace('VOICES', json.dumps(voices, ensure_ascii=False)).replace('FUNCTION', function)
        runner = shutil.which('qmltestrunner6') or '/usr/lib/qt6/bin/qmltestrunner'
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / 'tst_voices.qml').write_text(qml)
            result = subprocess.run([runner, '-input', tmp], capture_output=True, text=True,
                                    env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen',
                                         'QT_QUICK_BACKEND': 'software'}, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
