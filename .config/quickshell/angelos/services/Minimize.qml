pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Minimizing for niri, which has none (the Golden Gate skin: the yellow light of angelOS's title
// bars, Window → Minimize, ⌘M, the Dock). A minimized window moves to a workspace of its own on
// its output, named Niri.hiddenPrefix + output — the shell's lists of desktops leave it out — and
// shows on the right of the Dock as a snapshot of itself (grim, taken just before it goes: niri
// gives screencopy of whole outputs only, and ScreencopyView crashes Quickshell 0.3.1 on several
// monitors). It comes back to the desktop it left: a click in the Dock, its app's icon when it
// has no other window, Alt+Tab, the overview, the Dock menu. Scrolling through the desktops steps
// over the hidden one; it is kept last on its output and given up when empty. When the skin goes
// every minimized window comes back.
Singleton {
    id: root

    property var origin: ({})               // window id -> {ws, output}: where it came back to
    property var shots: ({})                // window id -> file url of its snapshot
    property var order: []                  // window ids, oldest minimized first
    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/angelos-minimized"
    // the minimized windows, in the order they were minimized
    readonly property var windows: {
        const mine = Niri.windows.filter(w => Niri.isHidden(Niri.workspaceById(w.workspace_id)));
        const at = id => {
            const i = order.indexOf(id);
            return i < 0 ? 1e9 + id : i;
        };
        return mine.sort((a, b) => at(a.id) - at(b.id));
    }
    function isMinimized(w) {
        return !!w && Niri.isHidden(Niri.workspaceById(w.workspace_id));
    }
    function hiddenOn(output) {
        return Niri.allWorkspaces.find(x => x.output === output && x.name === Niri.hiddenPrefix + output) || null;
    }

    // ---- away ----
    property var _queue: []
    function minimize(id) {
        const w = Niri.windows.find(x => x.id === id);
        const ws = w ? Niri.workspaceById(w.workspace_id) : null;
        if (!w || !ws || isMinimized(w) || _queue.some(q => q.id === id))
            return;
        const o = Object.assign({}, origin);
        o[id] = {
            "ws": ws.id,
            "output": ws.output
        };
        origin = o;
        _queue = _queue.concat([{
                "id": id,
                "output": ws.output,
                "rect": rectOf(w, ws.output)
            }]);
        _next();
    }
    // the window on the screen, in the global logical coordinates grim takes
    function rectOf(w, output) {
        const s = Shell.screenByName(output);
        const l = w.layout;
        if (!s || !l || !l.tile_pos_in_workspace_view || !l.tile_size)
            return null;
        const x = Math.round(s.x + l.tile_pos_in_workspace_view[0]), y = Math.round(s.y + l.tile_pos_in_workspace_view[1]);
        const wd = Math.round(l.tile_size[0]), ht = Math.round(l.tile_size[1]);
        // only what is on the screen
        const x0 = Math.max(x, s.x), y0 = Math.max(y, s.y);
        const x1 = Math.min(x + wd, s.x + s.width), y1 = Math.min(y + ht, s.y + s.height);
        return x1 - x0 < 8 || y1 - y0 < 8 ? null : [x0, y0, x1 - x0, y1 - y0];
    }
    function _next() {
        if (shooter.running || !_queue.length)
            return;
        const q = _queue[0];
        if (!q.rect || Shell.dev) {
            _away(q);
            return;
        }
        shooter.job = q;
        shooter.path = dir + "/" + q.id + "-" + Date.now() + ".png";
        shooter.command = ["sh", "-c", "mkdir -p \"$1\" && grim -g \"$2\" \"$3\"", "sh", dir, q.rect[0] + "," + q.rect[1] + " " + q.rect[2] + "x" + q.rect[3], shooter.path];
        shooter.running = true;
    }
    Process {
        id: shooter
        property var job: null
        property string path: ""
        stderr: StdioCollector {
            id: shotErr
        }
        onExited: code => {
            const q = job;
            if (code !== 0)
                console.warn("angelOS minimize: no snapshot:", shotErr.text);
            if (code === 0 && q) {
                const s = Object.assign({}, root.shots);
                s[q.id] = "file://" + path;
                root.shots = s;
            }
            if (q)
                root._away(q);
        }
    }
    function _away(q) {
        _queue = _queue.filter(x => x !== q);
        const w = Niri.windows.find(x => x.id === q.id);
        const name = Niri.hiddenPrefix + q.output;
        if (w) {
            if (!hiddenOn(q.output)) {
                // the output's last workspace (niri keeps an empty one there) becomes the hidden one
                const last = Niri.allWorkspaces.filter(x => x.output === q.output).sort((a, b) => b.idx - a.idx)[0];
                if (last)
                    Niri.action("SetWorkspaceName", {
                        "name": name,
                        "workspace": {
                            "Id": last.id
                        }
                    });
            }
            Niri.action("MoveWindowToWorkspace", {
                "window_id": q.id,
                "reference": {
                    "Name": name
                },
                "focus": false
            });
            order = order.filter(x => x !== q.id).concat([q.id]);
        }
        _next();
    }

    // ---- back ----
    function restore(id) {
        const w = Niri.windows.find(x => x.id === id);
        if (!w)
            return;
        if (!isMinimized(w)) {
            Niri.focusWindow(id);
            return;
        }
        const hid = Niri.workspaceById(w.workspace_id);
        const o = origin[id];
        let to = o ? Niri.workspaceById(o.ws) : null;
        if (!to || Niri.isHidden(to))
            to = Niri.activeWorkspace(o ? o.output : hid.output) || Niri.activeWorkspace(hid.output);
        if (!to)
            to = Niri.workspacesOn(hid.output)[0] || null;
        if (!to)
            return;
        Niri.action("MoveWindowToWorkspace", {
            "window_id": id,
            "reference": {
                "Id": to.id
            },
            "focus": true
        });
        Niri.action("FocusWindow", {
            "id": id
        });
        forget(id);
    }
    function restoreAll() {
        for (const w of windows)
            restore(w.id);
    }
    function forget(id) {
        const o = Object.assign({}, origin);
        delete o[id];
        origin = o;
        const s = Object.assign({}, shots);
        if (s[id]) {
            Quickshell.execDetached(["rm", "-f", String(s[id]).replace("file://", "")]);
            delete s[id];
        }
        shots = s;
        order = order.filter(x => x !== id);
    }
    Connections {
        target: Niri
        function onRestoreRequested(id) {
            root.restore(id);
        }
        // scrolled onto the hidden workspace: on to the next one the same way (back, if it is
        // the last); in the overview it may be looked at — what is focused there when the
        // overview closes comes back
        function onHiddenActivated(ws, from) {
            if (Niri.overviewOpen)
                return;
            const list = Niri.allWorkspaces.filter(x => x.output === ws.output && !Niri.isHidden(x));
            const down = !from || from.idx < ws.idx;
            const next = down ? list.find(x => x.idx > ws.idx) : list.slice().reverse().find(x => x.idx < ws.idx);
            const to = next || list.slice().reverse().find(x => x.idx < ws.idx) || list[0];
            if (to)
                Niri.focusWorkspace(to.id);
        }
        function onOverviewOpenChanged() {
            if (Niri.overviewOpen)
                return;
            const f = Niri.focusedWindow;
            if (f && root.isMinimized(f))
                root.restore(f.id);
            else
                for (const ws of Niri.allWorkspaces)
                    if (Niri.isHidden(ws) && ws.is_active)
                        root.onHiddenActivated(ws, null);
        }
        function onWindowClosed(id) {
            root.forget(id);
        }
        function onAllWorkspacesChanged() {
            tidyLater.restart();
        }
        function onWindowsChanged() {
            tidyLater.restart();
        }
    }
    // after niri has settled (a hidden workspace is named a moment before its window arrives)
    Timer {
        id: tidyLater
        interval: 700
        onTriggered: root.tidy()
    }
    // a hidden workspace with nothing left is given up (niri removes an empty unnamed one); one
    // that is not last on its output (a desktop was added after it) moves back to the end
    function tidy() {
        if (!Niri.ready || _queue.length || shooter.running) {
            if (Niri.ready)
                tidyLater.restart();
            return;
        }
        for (const ws of Niri.allWorkspaces) {
            if (!Niri.isHidden(ws))
                continue;
            if (!Niri.windows.some(w => w.workspace_id === ws.id)) {
                Niri.action("UnsetWorkspaceName", {
                    "reference": {
                        "Id": ws.id
                    }
                });
                continue;
            }
            const last = Math.max(...Niri.allWorkspaces.filter(x => x.output === ws.output).map(x => x.idx));
            if (ws.idx < last - 1)
                Niri.action("MoveWorkspaceToIndex", {
                    "index": last,
                    "reference": {
                        "Id": ws.id
                    }
                });
        }
    }

    // nothing stays hidden without the skin (and none from before a restart of the shell)
    Connections {
        target: GoldenGate
        function onOnChanged() {
            if (!GoldenGate.on)
                root.restoreAll();
        }
    }
    Connections {
        target: Niri
        function onReadyChanged() {
            if (Niri.ready && !GoldenGate.on)
                root.restoreAll();
        }
    }
}
