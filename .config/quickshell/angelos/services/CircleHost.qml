pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The screenshot overlay (services/CircleSearch, modules/circle) runs in a process of its own
// (scripts/circle-proc.sh): this shell's main thread is busy with the bar, the Halo, the
// wallpapers, and the pointer waited behind them while picking. This is the shell's end of it:
// the process kept running (started again when it goes), opened through here (the screenshot
// key, `angelos capture`, Settings), told how things are (stream, motion, hell, privacy) and
// handed back what only the shell does — saving (Capture), the island, Quick Share, Settings.
// JSON lines over $XDG_RUNTIME_DIR/angelos/circle.sock (the other end:
// modules/circle/proc/services/CircleLink). The process not there within 3 s of a screenshot:
// the classic selector, so the shot isn't lost.
Singleton {
    id: root

    property bool open: false
    property string screenName: ""
    property int learnedCount: 0
    property var client: null
    readonly property bool connected: client !== null
    // a start that waits for the process
    property var pending: null
    property int fails: 0

    readonly property bool test: Quickshell.env("ANGELOS_TEST") === "1"
    readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos"
    // the dev stand's shell has its own (as WorkspaceAnim's ctl-dev.sock)
    readonly property string socketPath: runtimeDir + (Shell.dev ? "/circle-dev.sock" : "/circle.sock")
    readonly property string rootDir: runtimeDir + (Shell.dev ? "/circle-root-dev" : "/circle-root")
    property bool socketReady: false

    readonly property var shellState: ({
            "t": "state",
            "onAir": StreamMode.onAir,
            "active": StreamMode.active,
            "calm": Motion.calm,
            "still": Motion.still,
            "hell": Theme.hell,
            "privacy": Privacy.hiddenNow.length > 0
        })
    onShellStateChanged: send(shellState)

    // wait: seconds before the picture, so a menu that started it has gone from the screen
    function start(screen, wait) {
        ask("start", screen, wait);
    }
    // the key again while it is open closes it
    function toggle(screen) {
        ask("toggle", screen, 0);
    }
    function forget() {
        send({
            "t": "forget"
        });
    }

    function ask(kind, screen, wait) {
        const name = screen || Niri.focusedOutput || Shell.primaryName;
        const ws = Niri.activeWorkspace(name);
        const m = {
            "t": kind,
            "screen": name,
            "wait": wait || 0,
            "ws": ws,
            "windows": ws ? Niri.windowsOn(ws.id) : [],
            "focused": Niri.focusedWindowId,
            "land": ShotEdit.placeOn(name),
            "barEdge": BarLayout.edge
        };
        if (send(m))
            return;
        pending = m;
        fallback.restart();
        if (!proc.running && !test && socketReady)
            proc.running = true;
    }
    function send(obj) {
        if (!client)
            return false;
        client.write(JSON.stringify(obj) + "\n");
        client.flush();
        return true;
    }

    function take(sock, m) {
        if (m.t === "hello") {
            client = sock;
            fails = 0;
            learnedCount = m.learned || 0;
            send(shellState);
            if (pending) {
                send(pending);
                pending = null;
                fallback.stop();
            }
        } else if (m.t === "open") {
            open = !!m.on;
            screenName = m.screen || "";
        } else if (m.t === "learned") {
            learnedCount = m.n || 0;
        } else if (m.t === "save") {
            Capture.saveShot(m.frame, m.rect, m.opts || {}, r => send({
                    "t": "answer",
                    "id": m.id,
                    "r": r
                }));
        } else if (m.t === "island") {
            if (m.act === "search")
                Island.search(m.arg);
            else if (m.act === "open")
                Island.open(m.arg);
            else if (m.act === "lens")
                Island.lens(m.arg);
        } else if (m.t === "share") {
            QuickShare.share(m.paths || [], m.text || "");
        } else if (m.t === "settings") {
            Shell.openSettings(m.page, m.sub);
        }
    }

    // no process to open it: the old selector takes the shot
    Timer {
        id: fallback
        interval: 3000
        onTriggered: {
            if (!root.pending)
                return;
            root.pending = null;
            console.warn("CircleHost: the overlay's process is not there, the classic selector instead");
            Capture.launch(Capture.screenshotTool, "niri msg action screenshot");
        }
    }

    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "$1" && chmod 700 "$1" && rm -f "$2"', "sh", root.runtimeDir, root.socketPath]
        onExited: code => {
            root.socketReady = code === 0;
            if (root.socketReady && !root.test)
                proc.running = true;
        }
    }
    SocketServer {
        active: root.socketReady
        path: root.socketPath
        handler: Socket {
            id: sock
            onConnectedChanged: {
                if (!connected && root.client === sock) {
                    root.client = null;
                    root.open = false;
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
                        root.take(sock, m);
                }
            }
        }
    }

    // the overlay's process, kept running; one that keeps dying is started again less often
    Process {
        id: proc
        command: ["sh", Quickshell.shellDir + "/scripts/circle-proc.sh", Quickshell.shellDir, root.rootDir]
        environment: ({
                "ANGELOS_CIRCLE_SOCK": root.socketPath
            })
        stderr: SplitParser {
            onRead: line => {
                if (line.trim())
                    console.log("circle: " + line);
            }
        }
        onExited: code => {
            root.client = null;
            root.open = false;
            again.interval = Math.min(60000, 2000 * Math.pow(2, root.fails++));
            again.restart();
        }
    }
    Timer {
        id: again
        onTriggered: proc.running = true
    }
}
