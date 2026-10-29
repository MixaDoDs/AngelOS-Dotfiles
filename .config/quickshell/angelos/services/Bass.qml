pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The bass of what plays, for the Halo's glow (modules/halo: the closed pill with the music
// glows along its inner edge with the bass, a kick flashes it), for the angel's nod and for a layered
// wallpaper that flinches on the kicks (modules/background/WallpaperView). Its own small cava through
// scripts/audio-tap.py (what everything plays): three bands from 40 Hz to 6 kHz with cava's
// autosens, so the low one says how much of the sound is bass, whatever the volume —
// measured on real music: 0.3…0.6 at rest, 0.8…0.95 on a kick. Runs only while the pill shows
// music that plays and someone can see it (not locked, no full-screen game everywhere, no game boost, not in
// the eco mode); Settings → Halo → «Glow with the bass».
//   level   0…3: how dense the bass is, in whole steps (the dither band's rows, the arc's weight)
//   flash   1 on a kick, then down in a fifth of a second; kicked() once per kick (the wave)
//   beat()  on the song's beat: the kicks' tempo (bpm), kept through a few missed or quiet beats
//           — the angel nods on it, not on every bass note
Singleton {
    id: root

    // the song in any capsule: a recording (or a timer) goes first, the bass goes on
    readonly property bool shownMusic: Halo.items.some(i => i.kind === "music")
    // the angel in her corner nods to it (modules/y2k/AngelHelper: she says she listens)
    property bool angelListens: false
    // the layered wallpapers that flinch on it, running now (WallpaperView: walls += 1 / -1)
    property int walls: 0
    readonly property bool haloWants: !!Config.halo.enabled && Config.halo.bassGlow !== false && shownMusic && Shell.screens.some(s => Halo.on(s.name) && !Shell.stillScreen(s.name))
    readonly property bool wanted: Config.ready && !Shell.dev && !Power.eco && Lyrics.playing && !Lyrics.unseen && (haloWants || angelListens || walls > 0)

    property int level: 0
    property real flash: 0
    signal kicked
    signal beat
    property real avg: 0.4
    property real prev: 0
    property real dense: 0
    // the kick: a sharp jump of the lowest band only (40–140 Hz: the drum's body, below most bass
    // lines), at most ~214 a minute
    property real kickAvg: 0.4
    property real kickPrev: 0
    property double lastKick: 0
    // the tempo from the gaps between kicks (the median of the last ones, folded into 70…180 bpm
    // so a missed kick or a double-time hat doesn't halve or double it); the beat runs on it
    // by itself and each kick near a beat pulls its phase back in, so a quiet bar or a few
    // missed kicks don't stop it — 16 beats without a kick and it is lost
    property real period: 0                 // ms; 0 = no tempo yet
    readonly property int bpm: period > 0 ? Math.round(60000 / period) : 0
    property var gaps: []
    property double nextBeat: 0
    property int missed: 0
    function fold(ms) {
        while (ms > 60000 / 70)
            ms /= 2;
        while (ms < 60000 / 180)
            ms *= 2;
        return ms;
    }
    function tempo(now, kick) {
        if (kick) {
            const gap = now - lastKick;
            if (lastKick > 0 && gap < 2000) {
                gaps = gaps.concat([fold(gap)]).slice(-8);
                const g = gaps.slice().sort((a, b) => a - b);
                if (g.length >= 3)
                    period = g[Math.floor(g.length / 2)];
            }
            lastKick = now;
            if (period > 0) {
                // the kick lands on a beat: that beat's phase follows it
                const d = now - (nextBeat - period);
                if (nextBeat === 0 || Math.abs(d) > period * 0.5)
                    nextBeat = now + period;
                else if (Math.abs(d) < period * 0.25)
                    nextBeat += -d * 0.5;
                missed = 0;
            }
        }
        if (period > 0 && nextBeat > 0 && now >= nextBeat - 16) {
            beat();
            nextBeat += period;
            if (now - lastKick > period * 1.5 && ++missed > 16) {
                period = 0;
                nextBeat = 0;
                gaps = [];
                missed = 0;
            }
        }
    }
    function hear(b, low) {
        const now = Date.now();
        const kick = low - kickPrev > 0.1 && low > kickAvg * 1.35 && low > 0.5 && now - lastKick > 280;
        kickAvg = kickAvg * 0.95 + low * 0.05;
        kickPrev = low;
        tempo(now, kick);
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
            period = 0;
            nextBeat = 0;
            gaps = [];
        }
    }

    readonly property string conf: Quickshell.env("HOME") + "/.cache/angelos/cava-halo-bass.conf"
    readonly property string fifo: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos-cava-halo-bass.fifo"
    readonly property string confText: ["[general]", "bars = 8", "framerate = 30", "autosens = 1", "lower_cutoff_freq = 40", "higher_cutoff_freq = 6000", "[input]", "method = fifo", "source = " + fifo, "sample_rate = 22050", "sample_bits = 16", "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 1000", "bar_delimiter = 59", "frame_delimiter = 10", "channels = mono", "[smoothing]", "noise_reduction = 15", ""].join("\n")
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
                // eight bands from 40 Hz: the first two (to ~140 Hz) the kick, the first three
                // (to ~270 Hz) the bass the glow shows, as the one low band of before
                const v = line.split(";").map(x => parseInt(x));
                if (v.length >= 3 && !isNaN(v[0]))
                    root.hear(Math.max(v[0], v[1], v[2]) / 1000, Math.max(v[0], v[1]) / 1000);
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
