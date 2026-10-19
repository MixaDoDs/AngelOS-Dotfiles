pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The overlay process's line to the shell (services/CircleHost, the other end): JSON lines over
// $XDG_RUNTIME_DIR/angelos/circle.sock. The shell says when to open (with what niri shows on that
// screen, where a saved shot's picture will be, the bar's edge) and how things are (stream, calm
// motion, privacy); the overlay hands back what only the shell does: saving, the island, Quick
// Share, Settings. The shell gone, this process goes too (the shell starts it again).
Singleton {
    id: root

    // the shell's state (CircleHost.state)
    property bool onAir: false
    property bool streamActive: false
    property bool calm: false
    property bool still: false
    property bool hell: false
    property bool privacy: false
    // given with each opening
    property var ws: null
    property var windows: []
    property int focusedWindowId: -1
    property string focusedOutput: ""
    property string land: "bottom-right"
    property string barEdge: "bottom"

    property bool _was: false
    property int _next: 1
    property var _pending: ({})

    function connect() {
        sock.connected = true;
        retry.start();
    }
    function send(obj) {
        if (!sock.connected)
            return false;
        sock.write(JSON.stringify(obj) + "\n");
        sock.flush();
        return true;
    }
    // a question with an answer later: done(answer)
    function ask(obj, done) {
        const id = _next++;
        if (done)
            _pending[id] = done;
        obj.id = id;
        if (!send(obj) && done) {
            delete _pending[id];
            done({});
        }
    }

    function _take(m) {
        if (m.t === "state") {
            onAir = !!m.onAir;
            streamActive = !!m.active;
            calm = !!m.calm;
            still = !!m.still;
            hell = !!m.hell;
            privacy = !!m.privacy;
            Motion.calm = calm;
            Motion.still = still;
            Theme.realm = hell ? "hell" : "heaven";
        } else if (m.t === "start" || m.t === "toggle") {
            if (m.t === "toggle" && (CircleSearch.open || CircleSearch.fading)) {
                CircleSearch.close();
                return;
            }
            ws = m.ws || null;
            windows = m.windows || [];
            focusedWindowId = m.focused === undefined ? -1 : m.focused;
            focusedOutput = m.screen || "";
            land = m.land || "bottom-right";
            barEdge = m.barEdge || "bottom";
            CircleSearch.start(m.screen || "", m.wait || 0);
        } else if (m.t === "close") {
            CircleSearch.close();
        } else if (m.t === "forget") {
            CircleSearch.forget();
        } else if (m.t === "answer") {
            const done = _pending[m.id];
            delete _pending[m.id];
            if (done)
                done(m.r || {});
        }
    }

    Socket {
        id: sock
        // CircleHost gives it (the dev stand's shell has a socket of its own)
        path: Quickshell.env("ANGELOS_CIRCLE_SOCK") || (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos/circle.sock"
        onConnectedChanged: {
            if (connected) {
                root._was = true;
                retry.stop();
                root.send({
                    "t": "hello",
                    "learned": CircleSearch.learnedCount
                });
            } else if (root._was) {
                Qt.quit();
            }
        }
        parser: SplitParser {
            onRead: line => {
                let m = null;
                try {
                    m = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (m)
                    root._take(m);
            }
        }
    }
    // the shell's socket may come a moment after this process
    Timer {
        id: retry
        interval: 500
        repeat: true
        property int tries: 0
        onTriggered: {
            if (sock.connected)
                return stop();
            if (++tries > 40)
                Qt.quit();
            sock.connected = true;
        }
    }

    Connections {
        target: CircleSearch
        function onOpenChanged() {
            root.send({
                "t": "open",
                "on": CircleSearch.open,
                "screen": CircleSearch.screenName
            });
        }
        function onLearnedCountChanged() {
            root.send({
                "t": "learned",
                "n": CircleSearch.learnedCount
            });
        }
    }
}
