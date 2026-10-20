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
Singleton {
    id: root

    readonly property string frames: Config.home + "/.local/state/angelos/timelapse"
    readonly property string outDir: (Config.capture.recordDir || "~/Videos").replace(/^~(?=\/|$)/, Config.home)
    readonly property bool on: Config.ready && !!Config.capture.timelapse && Capture.canReplay && Shell.primaryName !== "" && Quickshell.env("ANGELOS_TEST") !== "1"
    property string day: today()
    property bool building: false
    property string last: ""                // the last video made

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
        running: root.on
        // a new file each start (a restart, a new day): mkv keeps what was written when cut off
        command: ["sh", "-c", 'mkdir -p "$1" && chmod 700 "$1" "$2" && exec gpu-screen-recorder -w "$3" -f 1 -c mkv -k h264 -q medium -s 960x540 -v no -o "$1/$(date +%H%M%S).mkv"', "sh", root.frames + "/" + root.day, root.frames, Shell.primaryName]
        onExited: if (root.on)
            again.restart()
    }
    Timer {
        id: again
        interval: 10000
        onTriggered: rec.running = Qt.binding(() => root.on)
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
            // yesterday's file closed first (it comes back in today's folder), then glued
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
