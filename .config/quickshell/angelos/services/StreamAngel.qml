pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The angel on stream (modules/y2k/AngelHelper, Angel.streamer): while OBS streams she sits
// on the streamed screen's taskbar like a streamer at her desk, cut off at the waist, and talks with
// the streamer's voice — the mic level as OBS hears it (scripts/stream-mic.py: the mic
// input after its slider, nothing while it's muted there; without OBS the PipeWire
// source itself). Settings → Y2K → Stream mode → The angel on stream; `angelos stream angel`.
Singleton {
    id: root

    // OBS as this helper sees it (its own connection: stream mode's auto switch may be off)
    property bool obsUp: false
    property bool obsLive: false
    property real level: 0           // 0…1 of the voice (-55 → -12 dBFS)
    property real db: -100
    property var inputs: []          // [{name, kind, device, score}] what can be her voice
    property string using: ""        // obs:<input> | pw:<source>
    property string error: ""
    // a look without a stream: Settings → "Show her now", `angelos stream angel test`
    property bool preview: false

    readonly property bool enabled: Config.ready && !!Config.stream.streamer
    readonly property bool live: obsLive || StreamMode.active
    readonly property bool shown: (enabled && live) || preview
    // the voice: talking above the threshold, quiet again a little under it (no flicker)
    readonly property real threshold: Math.max(0.05, Math.min(0.95, (Config.stream.streamerThreshold ?? 30) / 100))
    property bool talking: false
    onLevelChanged: {
        if (level >= threshold)
            talking = true;
        else if (level < threshold * 0.7)
            hold.restart();
    }
    // words have gaps: she keeps the mouth going for a beat after the voice dips
    Timer {
        id: hold
        interval: 180
        onTriggered: if (root.level < root.threshold * 0.7)
            root.talking = false
    }

    // her screen: the one picked, else the first streamed one, else where the helper is
    readonly property var screen: {
        const want = Config.stream.streamerScreen || (StreamMode.screens.length ? StreamMode.screens[0] : "");
        return (want && Shell.screenByName(want)) || Shell.primaryScreen || Shell.screens[0] || null;
    }

    // where you see her (Config.stream.streamerView): on your screen too | only in OBS
    readonly property string view: Config.stream.streamerView === "obs" ? "obs" : "screen"
    // her window for OBS (modules/y2k/StreamerCast): open and drawing her the whole time OBS
    // runs (or she is shown), live or not, so OBS is pointed at it once and always has her
    readonly property bool castOpen: enabled && (obsUp || shown)
    // off your screen (view "obs"): while that window is there to show her
    readonly property bool hidden: view === "obs" && castOpen

    function set(mode) {
        if (mode === "view")
            Config.stream.streamerView = view === "screen" ? "obs" : "screen";
        else if (["screen", "obs"].includes(mode))
            Config.stream.streamerView = mode;
        else if (mode === "on")
            Config.stream.streamer = true;
        else if (mode === "off") {
            Config.stream.streamer = false;
            preview = false;
        } else if (mode === "toggle")
            Config.stream.streamer = !Config.stream.streamer;
        else if (mode === "test")
            preview = !preview;
    }

    // ---- the niri key Mod+Alt+A (cfg/angelos-windows.kdl through window-config.py, like
    // the lens' keys), with the window rule that sends her OBS window off the screens ----
    property bool niriKeys: false
    property bool niriRead: false
    readonly property bool wantKeys: Config.ready && !!Config.stream.streamer && Config.stream.streamerKeys !== false
    onWantKeysChanged: syncKeys()
    function syncKeys() {
        if (!Shell.dev && Config.ready && niriRead && niriKeys !== wantKeys && !keyWriter.running) {
            keyWriter.command = ["python3", Quickshell.shellDir + "/scripts/window-config.py", JSON.stringify({
                    "streamAngel": root.wantKeys
                })];
            keyWriter.running = true;
        }
    }
    Process {
        id: keyReader
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/window-config.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.niriKeys = !!JSON.parse(text).streamAngel;
                    root.niriRead = true;
                    root.syncKeys();
                } catch (e) {}
            }
        }
    }
    Process {
        id: keyWriter
        onExited: keyReader.running = true
    }

    // a manual stream (no OBS to say it's live) and the preview hear the mic straight away
    readonly property bool always: preview || (StreamMode.active && Config.stream.manual)
    // --with-obs: her window for OBS (StreamerCast) draws her the whole time OBS runs, the
    // mouth on the mic too
    readonly property var command: ["python3", "-u", Quickshell.shellDir + "/scripts/stream-mic.py", "--port", String(Config.stream.port || 4455), "--mic", Config.stream.streamerMic || "auto", "--with-obs"].concat(always ? ["--always"] : [])
    onCommandChanged: if (mic.running) {
        mic.running = false;
        restart.restart();
    }
    Timer {
        id: restart
        interval: 200
        onTriggered: mic.running = Qt.binding(() => root.enabled || root.preview)
    }
    Process {
        id: mic
        running: root.enabled || root.preview
        command: root.command
        stdout: SplitParser {
            onRead: line => {
                let m;
                try {
                    m = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (m.level !== undefined) {
                    root.level = m.level;
                    root.db = m.db;
                } else if (m.obs !== undefined) {
                    root.obsUp = m.obs;
                    root.obsLive = !!m.live;
                } else if (m.inputs !== undefined) {
                    root.inputs = m.inputs;
                    root.using = m.using || "";
                    root.error = "";
                } else if (m.error !== undefined)
                    root.error = m.error;
            }
        }
        onRunningChanged: if (!running) {
            root.obsUp = false;
            root.obsLive = false;
            root.level = 0;
            root.talking = false;
        }
    }
}
