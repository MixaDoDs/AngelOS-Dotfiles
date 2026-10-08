pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Programs go quiet while hell's circles change (services/CircleFx): every stream the mixer
// lists (Audio.appStreams — not angelOS's own sounds) slides to 0 as the dark comes down, and
// once the dark has lifted climbs slowly back to where its fader was, on a power curve (quiet
// for a while, then the swell). Y2K → System sounds → "Programs quiet between circles".
//
// Never left at 0 (the fallbacks):
//  - their volumes go to ~/.local/state/angelos/duck.json BEFORE anything is turned down, and the
//    file is emptied once all are back. The shell dying, stopped or restarted meanwhile:
//    `angelos reap` (systemd's ExecStopPost) and the next start run scripts/duck-restore.py,
//    which gives them back through pactl;
//  - a duck lasts MAX_MS at most: the transition stuck or never ending, they come back anyway;
//  - a stream whose volume someone moves meanwhile (the mixer, the app itself) is left alone
//    from then on: their hand wins;
//  - a stream that appears in the middle isn't touched; one that goes away is forgotten.
Singleton {
    id: root

    // the real session only: a test or dev instance shares the user's PipeWire and would turn
    // their music down
    readonly property bool live: Quickshell.env("ANGELOS_TEST") !== "1" && !Shell.dev
    readonly property bool enabled: live && Config.ready && Config.y2k.circleDuck
    readonly property int downMs: 450
    readonly property int upMs: 3500
    readonly property int maxMs: 25000
    readonly property real curve: 2.5           // the climb back: fader = saved × t^curve
    readonly property string stateFile: Config.stateDir + "/duck.json"

    property var saved: ({})                    // node id → {node, name, vol, last}
    property string phase: ""                   // "" | down | held | up
    property double _t0: 0
    property real _from: 1                      // the level a phase starts from (0..1 of saved)
    property real level: 1

    // the transition's dark starts: down they go
    function duck() {
        if (!enabled)
            return;
        if (phase === "") {
            const s = {};
            for (const n of Audio.appStreams) {
                if (!n.audio || n.audio.muted || n.audio.volume <= 0.001)
                    continue;
                const p = n.properties || {};
                s[n.id] = {
                    "node": n,
                    "name": String(p["node.name"] || p["application.name"] || n.name || ""),
                    "vol": n.audio.volume,
                    "last": n.audio.volume
                };
            }
            if (!Object.keys(s).length)
                return;
            saved = s;
            _write();
            level = 1;
            safety.restart();
        }
        _start("down");
    }
    // the dark has lifted: back up, slowly
    function release() {
        if (phase === "" || phase === "up")
            return;
        _start("up");
    }
    function _start(p) {
        phase = p;
        _from = level;
        _t0 = Date.now();
        tick.start();
    }
    Timer {
        id: tick
        interval: 40
        repeat: true
        onTriggered: root._step()
    }
    Timer {
        id: safety
        interval: root.maxMs
        onTriggered: root.release()
    }
    function _step() {
        const t = Date.now() - _t0;
        if (phase === "down") {
            const k = Math.min(1, t / downMs);
            level = _from * (1 - k);
            if (k >= 1)
                phase = "held";
        } else if (phase === "up") {
            const k = Math.min(1, t / upMs);
            level = _from + (1 - _from) * Math.pow(k, curve);
            if (k >= 1)
                phase = "";
        }
        _apply();
        if (phase === "held")
            tick.stop();
        if (phase === "") {
            tick.stop();
            safety.stop();
            saved = {};
            _write();
        }
    }
    function _apply() {
        const live = Audio.appStreams;
        for (const id in saved) {
            const e = saved[id];
            const n = e.node;
            // gone, or someone moved its fader: theirs from now on
            if (!n || !n.audio || live.indexOf(n) < 0 || Math.abs(n.audio.volume - e.last) > 0.02) {
                delete saved[id];
                continue;
            }
            const v = Math.max(0, Math.min(1.5, e.vol * level));
            n.audio.volume = v;
            e.last = v;
        }
    }
    function _write() {
        const out = {};
        for (const id in saved)
            out[id] = {
                "name": saved[id].name,
                "vol": saved[id].vol
            };
        file.setText(JSON.stringify({
            "streams": out
        }) + "\n");
    }
    FileView {
        id: file
        path: root.stateFile
        blockWrites: true
        printErrors: false
    }
    // a duck the last shell left behind (it died in the middle): the volumes back at once
    Process {
        running: Config.ready && root.live
        command: ["python3", Quickshell.shellDir + "/scripts/duck-restore.py", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim())
                console.log("AppDuck: " + text.trim())
        }
    }
}
