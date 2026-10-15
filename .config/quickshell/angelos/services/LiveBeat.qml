pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// A beat for the live wallpaper's rare events (widgets/LiveWall): when music plays, an event
// waits for the next kick of the bass instead of coming at a random moment. Only listens
// while someone waits — cava (through scripts/audio-tap.py, what everything plays) runs for
// a few seconds and stops; with no beat in 4 s, or no cava, the waiting ones go anyway.
// A music spectrum on the desk that hears what everything plays (MusicSpectrum, `feeders`)
// already runs that cava: its bass bar is listened to instead — no python, cava and pw-record
// started and stopped for every event (5 a minute with two screens).
//   LiveBeat.next(cb)
Singleton {
    id: root

    property var waiting: []
    readonly property string conf: Quickshell.env("HOME") + "/.cache/angelos/cava-livebeat.conf"
    readonly property string fifo: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos-cava-livebeat.fifo"

    property int feeders: 0
    readonly property bool listening: proc.running     // its own cava (the self-test asks)
    function next(cb) {
        const idle = waiting.length === 0;
        waiting = waiting.concat([cb]);
        if (feeders > 0) {
            if (idle)
                learn();
        } else if (!proc.running) {
            learn();
            // the same text again: FileView writes nothing and says no `saved`
            if (written === confText) {
                proc.running = true;
            } else {
                written = confText;
                confFile.setText(confText);
            }
        }
        giveUp.restart();
    }
    function learn() {
        frames = 0;
        avg = 0;
        prev = 0;
    }
    // a spectrum's lowest bar, 0…1 at its 30 frames a second (the own cava: 0…1000 at 60)
    function feed(v) {
        if (waiting.length && !proc.running)
            hear(v * 1000, 6);
    }
    function hear(b, learning) {
        frames++;
        const kick = frames > learning && b > 120 && b > avg * 1.45 && b - prev > 60;
        avg = avg * 0.9 + b * 0.1;
        prev = b;
        if (kick && waiting.length)
            _fire();
    }
    function _fire() {
        const w = waiting;
        waiting = [];
        giveUp.stop();
        proc.running = false;
        for (const cb of w)
            cb();
    }

    // the bass alone, 60 frames a second
    readonly property string confText: ["[general]", "bars = 2", "framerate = 60", "autosens = 1", "[input]", "method = fifo", "source = " + fifo, "sample_rate = 22050", "sample_bits = 16", "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 1000", "bar_delimiter = 59", "frame_delimiter = 10", "channels = mono", "[smoothing]", "noise_reduction = 20", ""].join("\n")
    property string written: ""
    FileView {
        id: confFile
        path: root.conf
        preload: false
        atomicWrites: true
        onSaved: proc.running = root.waiting.length > 0
    }

    // a kick: the bass well over its recent level and rising, after a moment to learn it
    property int frames: 0
    property real avg: 0
    property real prev: 0
    Process {
        id: proc
        command: ["python3", Quickshell.shellDir + "/scripts/audio-tap.py", "run", "--conf", root.conf, "--fifo", root.fifo, ""]
        stdout: SplitParser {
            onRead: line => root.hear(parseInt(line.split(";")[0]) || 0, 12)
        }
        onExited: if (root.waiting.length)
            root._fire()
    }
    Timer {
        id: giveUp
        interval: 4000
        onTriggered: root._fire()
    }
}
