pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Region screenshot / screen recording through the dotfiles tools, which draw
// the selector in the skin chosen in Settings → Screenshots (Config.capture.skin).
// They are spawned by niri, exactly like from the keybind, a moment after the
// window or menu that asked has closed: started by the shell itself they took
// its environment and blocked signals along, and the selector could stay on
// screen after the shot (issue #8).
Singleton {
    id: root

    readonly property string screenshotTool: Config.home + "/.local/bin/niri-screenshot-region"
    readonly property string recordTool: Config.home + "/.local/bin/niri-record-region"

    // the recorder is there (the dotfiles put it): Golden Gate's Control Center offers
    // recording only then
    property bool canRecord: false
    Process {
        running: true
        command: ["test", "-x", root.recordTool]
        onExited: code => root.canRecord = code === 0
    }

    // niri's own shots (Print, screenshot-window/-screen) land loose in the screenshots folder:
    // scripts/screenshot-sort.py moves each into its month (<shots>/2026-10 Октябрь), and on its
    // first run tidies the per-app folders of before into months too
    property bool sorting: false        // set by the process (read before it exists: undefined)
    Process {
        id: sorter
        running: true
        property real startedAt: 0
        onRunningChanged: {
            root.sorting = running;
            if (running)
                startedAt = Date.now();
        }
        command: ["python3", Quickshell.shellDir + "/scripts/screenshot-sort.py", "watch"]
        // gone at once: each try waits twice as long, up to 5 minutes
        onExited: {
            sorterAgain.interval = Date.now() - startedAt < 30000 ? Math.min(sorterAgain.interval * 2, 300000) : 5000;
            sorterAgain.restart();
        }
    }
    Timer {
        id: sorterAgain
        interval: 2500
        onTriggered: sorter.running = true
    }

    // the screenshot is the overlay now (services/CircleSearch: areas, words, search, save);
    // Settings → Screenshots → «Classic region selection» keeps the old selector. Called from
    // menus and panels: the overlay grabs the screen once they have gone (wait)
    function screenshot(screen) {
        Achievements.note("screenshot");
        if (Config.capture.classic)
            launch(screenshotTool, "niri msg action screenshot");
        else
            CircleHost.start(screen || "", 0.3);
    }
    // the overlay's picked part (rect: {x, y, w, h} in frame pixels, null: the whole frame) kept
    // as the old tool kept it (scripts/capture_save.py): the month folder, the clipboard, the
    // notification with its buttons. opts: {copy, save, open} override the settings; quiet: no
    // notification (the caller says what happened); noThumb: no corner / Halo picture of it.
    // done(r): {path, copied} once it is kept
    function saveShot(framePath, rect, opts, done) {
        const o = opts || {};
        const args = ["python3", Quickshell.shellPath("scripts/capture_save.py"), "save", framePath];
        if (rect)
            args.push("--rect", [rect.x, rect.y, rect.w, rect.h].map(Math.round).join(","));
        if (o.copy !== undefined)
            args.push(o.copy ? "--copy" : "--no-copy");
        if (o.save === false)
            args.push("--no-save");
        if (o.open)
            args.push("--open");
        if (o.quiet)
            args.push("--quiet");
        // privacy on stream hides apps: no picture in the notification (it is on the screen too)
        if (Privacy.hiddenNow.length)
            args.push("--private");
        // its last line says where the picture went: the Halo shows it a moment (shotSaved)
        shotRun.createObject(root, {
            "command": args,
            "done": done || null,
            "noThumb": !!o.noThumb
        });
    }
    // a screenshot kept in its month folder (the overlay's save): the Halo's thumbnail
    signal shotSaved(string path)
    Component {
        id: shotRun
        Process {
            id: sr
            property var done: null
            property bool noThumb: false
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    const last = text.trim().split("\n").pop() || "";
                    let r = {};
                    try {
                        r = JSON.parse(last) || {};
                        if (r.path && !sr.noThumb)
                            root.shotSaved(r.path);
                    } catch (e) {
                        // no answer at all (python died): said once here — quiet callers (Lens,
                        // share) said nothing; its own errors come with its own notification
                        Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "dialog-error", "--", I18n.t("Скриншот не сохранился", "Screenshot not saved"), I18n.t("Не получилось сохранить снимок", "Could not keep the picture")]);
                    }
                    if (sr.done)
                        sr.done(r);
                }
            }
            onRunningChanged: if (!running)
                Qt.callLater(sr.destroy)
        }
    }
    // our own screen recording (niri-record-region, the Halo's record capsule): its pid file says
    // one runs, the file's time when it began. The script pokes recChanged (modules/Ipc) on start
    // and stop; while one runs a slow look also notices a recorder that died by itself. Paused
    // (the Halo): no recorder runs, the pieces wait to be glued; recAcc = ms recorded before
    // the running piece, so the time shown is recAcc + (now - recSince)
    property bool recording: false
    property bool recPaused: false
    property real recAcc: 0
    property real recSince: 0           // ms, 0 = not recording (or paused)
    property string recFile: ""
    property bool recAgain: false
    function recCheck() {
        if (recLook.running)
            recAgain = true;
        else
            recLook.running = true;
    }
    function stopRecord() {
        launch(recordTool, "true", ["--stop"]);
    }
    function pauseRecord() {
        launch(recordTool, "true", ["--pause"]);
    }
    // the ms recorded so far
    function recElapsed(now) {
        return recAcc + (recPaused || !recSince ? 0 : Math.max(0, now - recSince));
    }
    // the recording is saved (IPC recSaved from the script): onto the Halo's shelf
    function saved(path) {
        if (Config.halo.enabled && path)
            Shelf.addDrop([FileSearch.uri(path)], "", false);
    }
    Process {
        id: recLook
        running: true
        // lines: the piece's start (s; 0 paused), the file, "paused" or "", the ms before the piece
        command: ["sh", "-c", 'r="${XDG_RUNTIME_DIR:-/tmp}"; p=$(cat "$r/niri-record-region.pid" 2>/dev/null); if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then stat -c %Y "$r/niri-record-region.pid"; elif [ -f "$r/niri-record-region.paused" ]; then echo 0; else exit 0; fi; cat "$r/niri-record-region.out" 2>/dev/null; [ -f "$r/niri-record-region.paused" ] && echo paused || echo; cat "$r/niri-record-region.acc" 2>/dev/null || echo 0']
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.recording = l[0] !== "";
                root.recSince = root.recording ? Number(l[0]) * 1000 : 0;
                root.recFile = root.recording ? (l[1] || "") : "";
                root.recPaused = root.recording && l[2] === "paused";
                root.recAcc = root.recording ? Number(l[3]) || 0 : 0;
            }
        }
        onExited: if (root.recAgain) {
            root.recAgain = false;
            running = true;
        }
    }
    Timer {
        interval: 3000
        repeat: true
        running: root.recording
        onTriggered: root.recCheck()
    }
    // instant replay (Settings → Screen recording, Mod+Alt+G → Ipc clip): gpu-screen-recorder keeps
    // the last replaySec seconds of the main screen in memory, from the GPU straight into NVENC
    // (on vkcube ~2 % of the frames, where wf-recorder took 90 %); SIGUSR1 saves them, it prints
    // the file's path, and the clip goes onto the Halo's shelf like a recording
    property bool canReplay: false
    Process {
        running: true
        command: ["sh", "-c", "command -v gpu-screen-recorder"]
        onExited: code => root.canReplay = code === 0
    }
    readonly property bool replayOn: Config.capture.replay && canReplay && Shell.primaryName !== ""
    // a clip without the game's sound is no clip: "mic" adds the voice to what you hear
    readonly property var replayAudio: ({
            "system": ["-a", "default_output"],
            "mic": ["-a", "default_output|default_input"],
            "both": ["-a", "default_output|default_input"]
        })[Config.capture.recordAudio] || []
    readonly property var replayCommand: ["gpu-screen-recorder", "-w", Shell.primaryName, "-f", String(Config.capture.recordFps), "-r", String(Config.capture.replaySec), "-c", "mp4", "-k", "h264", "-ac", "aac", "-q", "high", "-v", "no", "-o", (Config.capture.recordDir || "~/Videos").replace(/^~/, Config.home)].concat(replayAudio)
    onReplayOnChanged: replay.running = replayOn
    // new settings: stop it, replayAgain starts it with them
    onReplayCommandChanged: if (replay.running)
        replay.signal(15)
    Process {
        id: replay
        command: root.replayCommand
        stdout: SplitParser {
            onRead: line => {
                if (!line.startsWith("/"))
                    return;
                root.saved(line);
                if (!Config.halo.enabled)
                    Quickshell.execDetached(["notify-send", "-a", "angelOS", I18n.t("Клип сохранён", "Clip saved"), line]);
            }
        }
        onExited: if (root.replayOn)
            replayAgain.restart()
    }
    Timer {
        id: replayAgain
        interval: 3000
        onTriggered: replay.running = root.replayOn
    }
    function clip() {
        if (replay.running)
            replay.signal(10);
        else
            Quickshell.execDetached(["notify-send", "-a", "angelOS", I18n.t("Мгновенный повтор выключен", "Instant replay is off"), canReplay ? I18n.t("Настройки → Скриншоты и запись → «Мгновенный повтор»", "Settings → Screenshots and recording → “Instant replay”") : I18n.t("Нужен gpu-screen-recorder", "It needs gpu-screen-recorder")]);
    }
    function record() {
        launch(recordTool, 'notify-send -a angelOS "' + I18n.t("Запись экрана не установлена: нет niri-record-region", "Screen recording isn't installed: niri-record-region is missing") + '"');
    }
    // the Golden Gate skin's ⇧⌘3 / ⇧⌘4 / ⇧⌘5 menu (scripts/mac-screenshot.sh: screen | region |
    // window | record): a picture of the screen, of a part, of the focused window, a video
    readonly property string macTool: Quickshell.shellDir + "/scripts/mac-screenshot.sh"
    function mac(kind) {
        launch(macTool, "niri msg action screenshot", [kind]);
    }
    // each call its own timer: one shared, a second call within 220 ms dropped the first
    function launch(tool, fallback, args) {
        later.createObject(root, {
            "tool": tool,
            "fallback": fallback,
            "args": args || []
        });
    }
    Component {
        id: later
        Timer {
            id: lt
            property string tool: ""
            property string fallback: ""
            property var args: []
            interval: 220
            running: true
            onTriggered: {
                Quickshell.execDetached(["sh", "-c", 't="$1"; f="$2"; shift 2; [ -x "$t" ] || exec sh -c "$f"; niri msg action spawn -- "$t" "$@" >/dev/null 2>&1 || exec "$t" "$@"', "sh", tool, fallback].concat(args));
                lt.destroy();
            }
        }
    }
}
