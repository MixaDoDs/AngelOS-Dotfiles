pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// services/ThemeExport against a slow stand-in renderer (tests/theme/run.sh): the switches
// heaven ⇄ hell in the orders that used to leave the apps in hell's colours. After each one
// the export must settle with palette.json = the palette of the state the shell is in.
// Prints "TEST <name> PASS|FAIL [detail]", then "TEST DONE <failures>".
Scope {
    id: root

    property int failures: 0
    function report(name, ok, detail) {
        if (!ok)
            failures++;
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + (detail ? " " + detail : ""));
    }
    function setDemon(on) {
        Story.player.character = on ? "demon" : "angel";
    }
    property string heaven: ""                    // heaven's palette, as first rendered
    property string hellText: ""                  // hell's palette before a wallpaper accent comes

    // the plan: [what, argument] — "do" runs a function, "sleep" ms, "settle" waits for the
    // export to settle and reads palette.json, "check" a function given the file's md5
    property var plan: []
    property int at: 0
    property double until: 0
    property string fileMd5: ""
    readonly property var steps: [
        ["settle"],
        ["check", md5 => {
                root.heaven = ThemeExport.paletteText;
                root.report("first-render", md5 === Qt.md5(ThemeExport.paletteText) && JSON.parse(root.heaven).realm === "heaven", "accent " + JSON.parse(root.heaven).accent);
            }],
        // a return "as in the game": the angel is back (demon off), the export fires while the
        // widgets still burn, the realm turns heaven only then (and did not re-render)
        ["do", () => root.setDemon(true)],
        ["sleep", 900],
        ["do", () => Theme.realm = "hell"],
        ["settle"],
        ["check", md5 => root.report("hell-settles", md5 === Qt.md5(ThemeExport.paletteText) && JSON.parse(ThemeExport.paletteText).realm === "hell", "accent " + JSON.parse(ThemeExport.paletteText).accent)],
        ["do", () => root.setDemon(false)],
        ["sleep", 700],
        ["do", () => Theme.realm = "heaven"],
        ["settle"],
        ["check", md5 => root.report("late-realm-return", md5 === Qt.md5(root.heaven) && ThemeExport.paletteText === root.heaven, "file " + md5.slice(0, 8) + " heaven " + Qt.md5(root.heaven).slice(0, 8))],
        // out again while hell's render runs (0.8 s here, from the debounce's 0.5 s on): the
        // way back comes due before it ends, and must not be dropped
        ["do", () => root.setDemon(true)],
        ["sleep", 650],
        ["do", () => root.setDemon(false)],
        ["settle"],
        ["check", md5 => root.report("out-during-render", md5 === Qt.md5(root.heaven), "file " + md5.slice(0, 8))],
        // back and forth, several times, inside the debounce and across renders
        ["do", () => root.setDemon(true)],
        ["sleep", 650],
        ["do", () => root.setDemon(false)],
        ["sleep", 120],
        ["do", () => root.setDemon(true)],
        ["sleep", 650],
        ["do", () => root.setDemon(false)],
        ["settle"],
        ["check", md5 => root.report("toggles-during-render", md5 === Qt.md5(root.heaven), "file " + md5.slice(0, 8))],
        // a change while a render runs is rendered right after it
        ["do", () => ThemeExport.apply()],
        ["sleep", 150],
        ["do", () => Config.appearance.customAccent = "#aa3366"],
        ["settle"],
        ["check", md5 => root.report("change-during-render", md5 === Qt.md5(ThemeExport.paletteText) && ThemeExport.paletteText !== root.heaven, "accent " + JSON.parse(ThemeExport.paletteText).accent)],
        ["do", () => Config.appearance.customAccent = "#1f5f99"],
        ["settle"],
        ["check", md5 => root.report("heaven-again", md5 === Qt.md5(root.heaven), "file " + md5.slice(0, 8))],
        // hell wears its own accent: a wallpaper accent landing a beat later changes nothing
        ["do", () => {
                root.setDemon(true);
                Theme.realm = "hell";
            }],
        ["settle"],
        ["do", () => {
                root.hellText = ThemeExport.paletteText;
                Config.appearance.customAccentHell = "#336699";
                PaletteGenerator.apply("#336699", false);
            }],
        ["settle"],
        ["check", md5 => root.report("hell-keeps-its-own", md5 === Qt.md5(ThemeExport.paletteText) && ThemeExport.paletteText === root.hellText && JSON.parse(ThemeExport.paletteText).accent !== JSON.parse(root.heaven).accent && ThemeExport.paletteText.indexOf("\"realm\": \"hell\"") >= 0, "accent " + JSON.parse(ThemeExport.paletteText).accent)],
        ["do", () => {
                root.setDemon(false);
                Theme.realm = "heaven";
            }],
        ["settle"],
        ["check", md5 => root.report("ends-in-heaven", md5 === Qt.md5(root.heaven), "file " + md5.slice(0, 8))]
    ]

    Process {
        id: md5
        command: ["md5sum", Config.cacheDir + "/palette.json"]
        stdout: StdioCollector {
            onStreamFinished: root.fileMd5 = text.split(" ")[0]
        }
    }
    property bool reading: false
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (!Config.ready || root.at >= root.steps.length)
                return;
            const s = root.steps[root.at];
            const now = Date.now();
            if (s[0] === "do") {
                s[1]();
                root.at++;
            } else if (s[0] === "sleep") {
                if (!root.until)
                    root.until = now + s[1];
                if (now >= root.until) {
                    root.until = 0;
                    root.at++;
                }
            } else if (s[0] === "settle") {
                if (!root.until)
                    root.until = now + 15000;
                if (root.reading) {
                    if (md5.running)
                        return;
                    root.reading = false;
                    root.until = 0;
                    root.at++;
                    return;
                }
                if (now > root.until) {
                    root.report("settle-" + root.at, false, "the export never settled");
                    root.until = 0;
                    root.at++;
                    return;
                }
                // settled for real: nothing running or waiting, a beat later still so
                if (ThemeExport.settled && root.settledSince && now - root.settledSince > 300) {
                    root.reading = true;
                    root.fileMd5 = "";
                    md5.running = true;
                }
            } else if (s[0] === "check") {
                s[1](root.fileMd5);
                root.at++;
            }
            if (root.at >= root.steps.length) {
                console.log("TEST DONE " + root.failures);
                Qt.callLater(Qt.quit);
            }
        }
    }
    property double settledSince: 0
    Connections {
        target: ThemeExport
        function onSettledChanged() {
            root.settledSince = ThemeExport.settled ? Date.now() : 0;
        }
    }
    Component.onCompleted: if (ThemeExport.settled)
        settledSince = Date.now()
    Timer {
        interval: 90000
        running: true
        onTriggered: {
            root.report("timeout", false, "step " + root.at);
            console.log("TEST DONE " + root.failures);
            Qt.quit();
        }
    }
}
