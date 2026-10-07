pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Stream mode: while OBS streams (obs-websocket, scripts/obs-watch.py) or when
// switched on by hand, angelOS keeps out of the picture — the angel leaves the
// streamed screens, its sounds stay quiet, Do not disturb is on, and sparkles,
// the loading screen and the angel/demon effects skip the streamed screens.
// Settings → Y2K → Stream mode; `angelos stream on|off|auto`.
Singleton {
    id: root

    property bool obsUp: false
    property bool obsLive: false
    property bool obsAuth: false             // OBS asks for a password we do not have
    // switched off by hand while OBS is live: stays off until this stream ends — also
    // through a shell restart in the middle of it (Config.stream.suppressed)
    readonly property bool suppressed: !!Config.stream.suppressed
    function unsuppress() {
        if (Config.stream.suppressed)
            Config.stream.suppressed = false;
    }
    // OBS answered but isn't streaming: the stream that was switched off is over
    Timer {
        id: notLive
        interval: 6000
        onTriggered: if (!root.obsLive)
            root.unsuppress()
    }
    readonly property bool active: Config.ready && (Config.stream.manual || (Config.stream.auto && obsLive && !suppressed))
    readonly property var screens: Config.stream.screens || []

    // is this screen seen by the viewers right now?
    function onStream(name) {
        return active && (screens.length === 0 || screens.includes(name));
    }
    // effects (sparkles, loading screen, rays, cracks) on this screen
    function effectsOn(name) {
        return !(Config.stream.effects && onStream(name));
    }
    readonly property bool quiet: active && Config.stream.mute
    // the angel's screen during the stream: off the streamed screens, or none
    function angelScreen(wanted) {
        if (!active || !Config.stream.hideAngel || !wanted || !onStream(wanted.name))
            return wanted;
        return Shell.screens.find(s => !onStream(s.name)) || null;
    }

    function set(mode) {
        if (mode !== "toggle")
            unsuppress();
        if (mode === "on")
            Config.stream.manual = true;
        else if (mode === "off") {
            Config.stream.manual = false;
            Config.stream.auto = false;
        } else if (mode === "auto") {
            Config.stream.manual = false;
            Config.stream.auto = true;
        } else if (mode === "toggle") {
            const on = !active;
            Config.stream.manual = on;
            Config.stream.suppressed = !on && obsLive;
        }
    }

    // Do not disturb for the stream; only undone when stream mode turned it on
    onActiveChanged: sync()
    Connections {
        target: Config
        function onReadyChanged() {
            root.sync();
        }
    }
    function sync() {
        if (!Config.ready)
            return;
        if (active && Config.stream.dnd && !Config.notifications.dnd) {
            Config.notifications.dnd = true;
            Config.stream.dndSet = true;
        } else if (!active && Config.stream.dndSet) {
            Config.stream.dndSet = false;
            Config.notifications.dnd = false;
        }
    }

    // ---- OBS as a habit: the two achievements (a stream or a recording of a minute or more
    // counts) and, once, the angel's hint that she can sit on the stream (StreamerCast) ----
    property bool obsRec: false
    property real liveSince: 0
    property real recSince: 0
    onObsLiveChanged: {
        if (!obsLive)
            unsuppress();
        if (obsLive)
            liveSince = Date.now();
        else if (liveSince && Date.now() - liveSince >= 60000)
            Achievements.note("obs.stream");
        if (!obsLive)
            liveSince = 0;
    }
    onObsRecChanged: {
        if (obsRec)
            recSince = Date.now();
        else if (recSince && Date.now() - recSince >= 60000)
            Achievements.note("obs.record");
        if (!obsRec)
            recSince = 0;
    }
    onObsUpChanged: if (obsUp)
        hintTimer.restart()
    Timer {
        id: hintTimer
        interval: 8000
        onTriggered: root.hintCast()
    }
    function hintCast() {
        if (Config.stream.castHinted || !root.obsUp || Shell.setupLocked)
            return;
        Config.stream.castHinted = true;
        const text = I18n.t("Пст… в OBS можно взять меня с края экрана на стрим: «Источник → Захват экрана (PipeWire)» → окно «%1». Сяду в уголок кадра ♡", "Psst… OBS can take me from the edge of your screen onto the stream: “Source → Screen Capture (PipeWire)” → the window “%1”. I'll sit in the corner of the frame ♡").arg(Niri.castTitle);
        if (Angel.present && !Angel.demon)
            Angel.say(text, [], 14000);
        else
            Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "camera-web", I18n.t("OBS и ангел", "OBS and the angel"), text]);
    }

    // Settings → Streaming → OBS: connect again (a new port, OBS just started)
    function reconnect() {
        watch.running = false;
        rewatch.restart();
    }
    Timer {
        id: rewatch
        interval: 300
        onTriggered: watch.running = Qt.binding(() => Config.ready)
    }
    Process {
        id: watch
        // always, so the achievements and the hint know about OBS; stream mode itself still
        // switches only with Config.stream.auto (`active` above)
        running: Config.ready
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/obs-watch.py", "--port", String(Config.stream.port || 4455)]
        stdout: SplitParser {
            onRead: line => {
                if (line === "up") {
                    root.obsUp = true;
                    root.obsAuth = false;
                    notLive.restart();
                } else if (line === "down") {
                    root.obsUp = false;
                    root.obsLive = false;
                    root.obsRec = false;
                    root.unsuppress();
                } else if (line === "live") {
                    notLive.stop();
                    root.obsLive = true;
                } else if (line === "off") {
                    root.obsLive = false;
                    root.unsuppress();
                } else if (line === "rec") {
                    root.obsRec = true;
                } else if (line === "recoff") {
                    root.obsRec = false;
                }
                else if (line === "auth")
                    root.obsAuth = true;
            }
        }
        onRunningChanged: if (!running) {
            root.obsUp = false;
            root.obsLive = false;
            root.obsRec = false;
        }
    }
}
