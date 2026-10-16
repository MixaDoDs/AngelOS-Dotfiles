pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The bass of what plays, for the Halo's glow (modules/halo: the closed pill with the music
// glows along its inner edge with the bass, a kick flashes it). Its own small cava through
// scripts/audio-tap.py (what everything plays): three bands from 40 Hz to 6 kHz with cava's
// autosens, so the low one says how much of the sound is bass, whatever the volume —
// measured on real music: 0.3…0.6 at rest, 0.8…0.95 on a kick. Runs only while the pill shows
// music that plays and someone can see it (not locked, no full-screen game everywhere, not in
// the eco mode); Settings → Halo → «Glow with the bass».
//   level   0…3: how dense the bass is, in whole steps (the dither band's rows, the arc's weight)
//   flash   1 on a kick, then down in a fifth of a second; kicked() once per kick (the wave)
Singleton {
    id: root

    // the song in any capsule: a recording (or a timer) goes first, the bass goes on
    readonly property bool shownMusic: Halo.items.some(i => i.kind === "music")
    readonly property bool wanted: Config.ready && !!Config.halo.enabled && Config.halo.bassGlow !== false && !Shell.dev && !Power.eco && Lyrics.playing && !Lyrics.unseen && shownMusic

    property int level: 0
    property real flash: 0
    signal kicked
    property real avg: 0.4
    property real prev: 0
    property real dense: 0
    function hear(b) {
        const kick = b - prev > 0.12 && b > avg * 1.3 && b > 0.55;
        avg = avg * 0.95 + b * 0.05;
        prev = b;
        // the level follows the bass up at once and down a little slower (no flicker)
        const d = Math.max(0, Math.min(1, (b - 0.45) / 0.4));
        dense = d > dense ? d : dense * 0.85 + d * 0.15;
        const lv = dense < 0.12 ? 0 : dense < 0.4 ? 1 : dense < 0.7 ? 2 : 3;
        if (lv !== level)
            level = lv;
        // the flash in steps the shader tells apart (> 0.6 = solid): no update for each frame
        const f = kick ? 1 : flash > 0.05 ? flash * 0.7 : 0;
        if (f !== flash)
            flash = f;
        if (kick)
            kicked();
    }
    onWantedChanged: {
        if (wanted) {
            writeConf();
        } else {
            proc.running = false;
            level = 0;
            flash = 0;
            dense = 0;
        }
    }

    readonly property string conf: Quickshell.env("HOME") + "/.cache/angelos/cava-halo-bass.conf"
    readonly property string fifo: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos-cava-halo-bass.fifo"
    readonly property string confText: ["[general]", "bars = 3", "framerate = 30", "autosens = 1", "lower_cutoff_freq = 40", "higher_cutoff_freq = 6000", "[input]", "method = fifo", "source = " + fifo, "sample_rate = 22050", "sample_bits = 16", "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 1000", "bar_delimiter = 59", "frame_delimiter = 10", "channels = mono", "[smoothing]", "noise_reduction = 15", ""].join("\n")
    property string written: ""
    function writeConf() {
        // the same text again: FileView writes nothing and says no `saved`
        if (written === confText) {
            proc.running = true;
            return;
        }
        written = confText;
        confFile.setText(confText);
    }
    FileView {
        id: confFile
        path: root.conf
        preload: false
        atomicWrites: true
        onSaved: proc.running = root.wanted
    }
    Process {
        id: proc
        command: ["python3", Quickshell.shellDir + "/scripts/audio-tap.py", "run", "--conf", root.conf, "--fifo", root.fifo, ""]
        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf(";");
                const v = parseInt(i < 0 ? line : line.slice(0, i));
                if (!isNaN(v))
                    root.hear(v / 1000);
            }
        }
        onExited: if (root.wanted)
            again.start()
    }
    // a tap that ended (the sink gone, a hiccup): once more in a while
    Timer {
        id: again
        interval: 5000
        onTriggered: proc.running = root.wanted
    }
}
