pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The day's timelapse (Settings → Screenshots and recording, `angelos timelapse on|off|build`):
// gpu-screen-recorder writes the main screen all day at a frame a second, small, into
// ~/.local/state/angelos/timelapse/<date>/<time>.mkv (only you can read it); at midnight, or at
// the shell's next start, scripts/timelapse.py glues each finished day into
// «Таймлапс <date>.mp4» in the recordings folder — a frame every timelapseStep seconds, the time
// of day in a corner — and the day's recordings go. Nothing is left out: what to show is yours.
// The day's moments: a second gpu-screen-recorder keeps the last 20 s with sound in memory (in
// games too) and saves them when you talk, shout or laugh (timelapse.py listen on
// Config.capture.momentsMic) or the stream's chat bursts; the video is then the timelapse squeezed
// to an intro and the day's best five moments after it. The clip's second sound track is the mic
// alone: what the night's ears (Config.capture.momentsEar / momentsWhisper) listen to.
Singleton {
    id: root

    readonly property string frames: Config.home + "/.local/state/angelos/timelapse"
    readonly property string outDir: (Config.capture.recordDir || "~/Videos").replace(/^~(?=\/|$)/, Config.home)
    readonly property bool on: Config.ready && !!Config.capture.timelapse && Capture.canReplay && Shell.primaryName !== "" && Quickshell.env("ANGELOS_TEST") !== "1"
    // not while a game runs: grabbing its screen once a second cost the 1 % lows (owner's choice
    // 03.11: a gap in the day's film over games); the day still turns over meanwhile
    readonly property bool recording: on && !Shell.gaming
    property string day: today()
    property bool building: false
    property string last: ""                // the last video made
    // the moments: a score waits out the moment's tail, then the buffer's saved
    readonly property int keep: 20          // as timelapse.py KEEP: no use saving below the 20th
    property var scores: []                 // today's saved ones
    property real pending: 0
    property real saving: 0
    property double lastSave: 0
    property var chat: []                   // the chat's last messages' times
    function mark(score, tail) {
        if (!buf.running || Date.now() - lastSave < 20000)
            return;
        const best = scores.slice().sort((a, b) => b - a);
        if (best.length >= keep && score <= best[keep - 1])
            return;
        pending = Math.max(pending, score);
        if (!tailT.running) {
            tailT.interval = tail;
            tailT.start();
        }
    }
    Timer {
        id: tailT
        onTriggered: {
            root.lastSave = Date.now();
            root.saving = root.pending;
            root.scores = root.scores.concat([root.pending]);
            root.pending = 0;
            buf.signal(10);
        }
    }
    // the replay buffer: a new start each day and after a save (-restart-replay-on-save: no clip
    // holds the one before); FRAMES/.moments only until timelapse.py moment takes the file
    Process {
        id: buf
        running: root.on
        command: ["sh", "-c", 'mkdir -p "$1" && chmod 700 "$1" && exec gpu-screen-recorder -w "$2" -f 30 -r 20 -restart-replay-on-save yes -s 1280x720 -c mp4 -k h264 -ac aac -q medium -a "$3" -a "$4" -v no -o "$1"', "sh", root.frames + "/.moments", Shell.primaryName, Config.capture.momentsAudio || "default_output|" + (Config.capture.momentsMic || "default_input"), Config.capture.momentsMic || "default_input"]
        // new settings: stopped, started again with them
        onCommandChanged: if (running)
            signal(15)
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("/"))
                    Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/timelapse.py"), "moment", line, String(root.saving), root.frames]);
            }
        }
        onExited: if (root.on)
            bufAgain.restart()
    }
    Timer {
        id: bufAgain
        interval: 10000
        onTriggered: buf.running = Qt.binding(() => root.on)
    }
    Process {
        id: ear
        running: root.on
        command: ["python3", Quickshell.shellPath("scripts/timelapse.py"), "listen"].concat(Config.capture.momentsMic ? [Config.capture.momentsMic] : [])
        onCommandChanged: if (running)
            signal(15)
        stdout: SplitParser {
            onRead: line => {
                try {
                    const r = JSON.parse(line);
                    if (r.voice)
                        root.mark(r.voice, 4000);
                } catch (e) {}
            }
        }
        onExited: if (root.on)
            earAgain.restart()
    }
    Timer {
        id: earAgain
        interval: 10000
        onTriggered: ear.running = Qt.binding(() => root.on)
    }
    // the chat bursting (5+ in 30 s): it reacts late (the stream's delay), so saved at once
    Connections {
        target: StreamChat
        enabled: root.on
        function onMessage(m) {
            const now = Date.now();
            root.chat = root.chat.filter(t => now - t < 30000).concat([now]);
            if (root.chat.length >= 5)
                root.mark(root.chat.length * 2, 500);
        }
    }

    function today() {
        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }
    function set(mode) {
        if (mode === "on" || mode === "off")
            Config.capture.timelapse = mode === "on";
        else if (mode === "build")
            buildToday();
    }
    // today so far (it goes on recording)
    function buildToday() {
        run(["build", frames, day, outDir, "--keep", "--step", String(Config.capture.timelapseStep || 30)]);
    }
    function run(args) {
        if (building)
            return;
        building = true;
        job.command = ["python3", Quickshell.shellPath("scripts/timelapse.py")].concat(args);
        job.running = true;
    }

    Process {
        id: rec
        running: root.recording
        // a new file each start (a restart, a new day): mkv keeps what was written when cut off
        command: ["sh", "-c", 'mkdir -p "$1" && chmod 700 "$1" "$2" && exec gpu-screen-recorder -w "$3" -f 1 -c mkv -k h264 -q medium -s 960x540 -v no -o "$1/$(date +%H%M%S).mkv"', "sh", root.frames + "/" + root.day, root.frames, Shell.primaryName]
        onExited: if (root.recording)
            again.restart()
    }
    Timer {
        id: again
        interval: 10000
        onTriggered: rec.running = Qt.binding(() => root.recording)
    }
    // a new day: the recorder starts its folder, yesterday is glued
    Timer {
        interval: 60000
        repeat: true
        running: root.on
        onTriggered: {
            const d = root.today();
            if (d === root.day)
                return;
            root.day = d;
            root.scores = [];
            // yesterday's file closed first (it comes back in today's folder), then glued; not
            // recording (a game) — the binding stays, it starts in today's folder after
            if (rec.running)
                rec.running = false;
            tidyLater.restart();
        }
    }
    Timer {
        id: tidyLater
        interval: 3000
        onTriggered: root.tidy()
    }
    function tidy() {
        run(["tidy", frames, outDir]);
    }
    onOnChanged: if (on)
        tidy()

    Process {
        id: job
        environment: ({
                "ANGELOS_MOMENTS_EAR": Config.capture.momentsEar || "",
                "ANGELOS_MOMENTS_WHISPER": Config.capture.momentsWhisper || ""
            })
        stdout: SplitParser {
            onRead: line => {
                let r = null;
                try {
                    r = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (r && r.path) {
                    root.last = r.path;
                    Capture.saved(r.path);
                    Quickshell.execDetached(["notify-send", "-a", "angelOS", I18n.t("Таймлапс готов", "Timelapse ready"), r.path]);
                } else if (r && r.error && r.error !== "none")
                    console.warn("Timelapse:", r.error);
            }
        }
        onExited: root.building = false
    }
}
