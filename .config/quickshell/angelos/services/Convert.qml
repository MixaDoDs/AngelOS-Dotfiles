pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The conversion ring (modules/convert/ConvertRing): left Shift + right click on files in Strata
// opens a pixel ring at the pointer — what kind to make of them when they are of several (pictures,
// video, sound: a video goes into sound too), then the format; the files go to
// scripts/videograb.py convert through services/VideoGrab («Сконвертировано» beside them, the
// Halo's capsule, the shelf). Strata tells nobody what is selected, so the shell asks it the way a
// person would: Esc (its own menu, opened by the same click, goes), Ctrl+C, the file list read from
// the clipboard — and the clipboard put back as it was (services/Clipboard's newest entry).
// The click itself: scripts/click-watch.py --shift-right (evdev, read-only; that combination only).
Singleton {
    id: root

    readonly property string strataId: "io.github.lgse.Strata"
    readonly property bool watching: Config.ready && Config.system.convertRing !== false && Quickshell.env("ANGELOS_TEST") !== "1" && !Shell.dev
    property var kinds: ({})        // videograb.py formats: kind → [extensions]
    property var formats: ({})      // kind → [{id, label}]
    property bool open: false
    property var groups: ({})       // the picked files by kind: {image: […], video: […], audio: […]}
    property int skipped: 0         // picked files of no kind it converts
    property string level: ""       // "" = the kinds' ring, else the kind whose formats show
    // the formats' ring, worked out as it opens (videograb.py sizes): bytes now, each format's
    // estimate, the formats every file already is (offered no more)
    property double now: 0
    property var sizes: ({})
    property var same: []
    onLevelChanged: {
        sizes = {};
        same = [];
        now = 0;
        sizer.running = false;
        if (!level)
            return;
        sizer.command = ["python3", Quickshell.shellDir + "/scripts/videograb.py", "sizes", level].concat(filesFor(level));
        sizer.running = true;
    }
    Process {
        id: sizer
        environment: ({
                "VIDEOGRAB_MB": String(VideoGrab.limitMb)
            })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text.trim().split("\n").pop());
                    root.now = j.now;
                    root.sizes = j.sizes;
                    root.same = j.same;
                } catch (e) {}
            }
        }
    }
    // the kinds offered: sound for the sounds and the videos
    readonly property var ringKinds: ["image", "video", "audio"].filter(k => (groups[k] || []).length > 0 || (k === "audio" && (groups.video || []).length > 0))

    function kindOf(path) {
        const ext = String(path).split("/").pop().split(".").pop().toLowerCase();
        return Object.keys(kinds).find(k => kinds[k].includes(ext)) || "";
    }
    function filesFor(kind) {
        return kind === "audio" ? (groups.audio || []).concat(groups.video || []) : (groups[kind] || []);
    }
    function show(list) {
        const g = {
            "image": [],
            "video": [],
            "audio": []
        };
        let skip = 0;
        for (const f of list) {
            const k = kindOf(f);
            if (k)
                g[k].push(f);
            else
                skip++;
        }
        groups = g;
        skipped = skip;
        if (!ringKinds.length) {
            Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "dialog-information", I18n.t("Конвертировать нечего", "Nothing to convert"), I18n.t("Среди выделенного нет картинок, видео или звука", "No pictures, video or sound among the selected files")]);
            return;
        }
        level = "";
        level = ringKinds.length === 1 ? ringKinds[0] : "";
        open = true;
    }
    function close() {
        open = false;
    }
    // Esc / a right click: back to the kinds, or away
    function back() {
        if (level && ringKinds.length > 1)
            level = "";
        else
            close();
    }
    function run(fmt) {
        if (same.includes(fmt))
            return;
        const list = filesFor(level);
        if (fmt === "discord")
            for (const f of list)
                VideoGrab.shrink(f, 0, 0);
        else if (fmt === "edit")
            for (const f of list)
                VideoGrab.edit(f, 0, 0);
        else
            VideoGrab.convert(fmt, list, level !== "image");
        close();
    }

    Process {
        command: ["python3", Quickshell.shellDir + "/scripts/videograb.py", "formats"]
        running: Config.ready
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.kinds = j.kinds;
                    root.formats = j.formats;
                } catch (e) {}
            }
        }
    }

    // ---- the click, and what Strata has selected ----
    Process {
        id: watcher
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/click-watch.py", "--shift-right"]
        running: root.watching
        stdout: SplitParser {
            onRead: line => {
                const w = Niri.focusedWindow;
                if (line.trim() === "shiftright" && w && w.app_id === root.strataId && !asker.running)
                    root.askStrata();
            }
        }
    }
    function askStrata() {
        // our own Ctrl+C is no clipboard history entry
        Clipboard.quietUntil = Date.now() + 3000;
        asker.running = true;
    }
    Process {
        id: asker
        command: ["sh", "-c", "wtype -k Escape; sleep 0.15; wtype -M ctrl -k c -m ctrl; sleep 0.3; wl-paste -n -t text/uri-list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const files = text.split(/\r?\n/).filter(l => /^file:\/\//.test(l)).map(l => decodeURIComponent(l.trim().replace(/^file:\/\/[^/]*/, "")));
                // the clipboard as it was
                if (Clipboard.history.length)
                    Clipboard.copy(Clipboard.history[0]);
                else
                    Quickshell.execDetached(["wl-copy", "--clear"]);
                if (files.length)
                    root.show(files);
            }
        }
    }
}
