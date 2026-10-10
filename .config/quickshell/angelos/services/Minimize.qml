pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Minimizing for niri, which has none (the Golden Gate skin: the apps' own yellow light through
// extras/minimize-hook, System Settings' light, Window → Minimize, ⌘M, the Dock). A minimized window moves to a workspace of its own on
// its output, named Niri.hiddenPrefix + output — the shell's lists of desktops leave it out — and
// shows on the right of the Dock as a snapshot of itself (grim, taken just before it goes: niri
// gives screencopy of whole outputs only, and ScreencopyView crashes Quickshell 0.3.1 on several
// monitors). It comes back to the desktop in front now, focused: a click in the Dock (on that
// screen), its app's icon when it has no other window, Alt+Tab / ⌘Tab, the overview, the Dock
// menu. ⌘H hides an app: all its windows go the same way, without a place in the Dock; its icon
// brings them all back. Scrolling through the desktops steps over the hidden one; it is kept last
// on its output and given up when empty. When the skin goes every minimized window comes back.
// What is minimized is niri's state (the windows on that workspace), so it outlives a restart of
// the shell; the snapshots, the order and which ones are hidden are kept in `stateFile`.
Singleton {
    id: root

    property var origin: ({})               // window id -> {ws, output, rect}: where it was
    property var shots: ({})                // window id -> file url of its snapshot
    property var order: []                  // window ids, oldest minimized first
    property var hidden: ({})               // window id -> true: gone with its app (⌘H), not in the Dock
    property var lastDesk: ({})             // output -> id of the desktop last in front there
    property var _to: ({})                  // window id -> id of the desktop it is coming back to
    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/angelos-minimized"
    // the minimized windows (the Dock's), in the order they were minimized
    readonly property var windows: {
        const mine = Niri.windows.filter(w => Niri.isHidden(Niri.workspaceById(w.workspace_id)) && !hidden[w.id]);
        const at = id => {
            const i = order.indexOf(id);
            return i < 0 ? 1e9 + id : i;
        };
        return mine.sort((a, b) => at(a.id) - at(b.id));
    }
    // the windows of hidden apps (⌘H)
    readonly property var hiddenWindows: Niri.windows.filter(w => Niri.isHidden(Niri.workspaceById(w.workspace_id)) && !!hidden[w.id])
    // minimized or hidden: on a hidden workspace
    function isMinimized(w) {
        return !!w && Niri.isHidden(Niri.workspaceById(w.workspace_id));
    }
    function isAppHidden(w) {
        return isMinimized(w) && !!hidden[w.id];
    }
    // the desktop in front on an output (the hidden workspace never counts: the one before it).
    // With the hidden one in front (the overview went to a minimized window) and no desktop noted
    // yet (a restart of the shell) it is the desktop right before the hidden one — never simply
    // the first desktop, where the window would show up and then jump away
    function currentDesk(output) {
        const act = Niri.activeWorkspace(output);
        if (act)
            return act;
        const last = Niri.workspaceById(lastDesk[output]);
        if (last && !Niri.isHidden(last) && last.output === output)
            return last;
        const list = Niri.workspacesOn(output);
        const hid = hiddenOn(output);
        return (hid ? list.slice().reverse().find(x => x.idx < hid.idx) : null) || list[list.length - 1] || null;
    }
    function noteDesks() {
        const d = Object.assign({}, lastDesk);
        let changed = false;
        for (const ws of Niri.workspaces)
            if (ws.is_active && d[ws.output] !== ws.id) {
                d[ws.output] = ws.id;
                changed = true;
            }
        if (changed)
            lastDesk = d;
    }
    // where a tiled window stands is worked out from the layout (rectOf)
    Component.onCompleted: WindowConfig.loaded
    function hiddenOn(output) {
        return Niri.allWorkspaces.find(x => x.output === output && x.name === Niri.hiddenPrefix + output) || null;
    }

    // ---- the hook: every minimize button (the apps' own yellow light, that of System
    // Settings, Window → Minimize, ⌘M, the Dock menu) asks here. `requested` is the signal to hang your own
    // minimizing on: connect to it (Connections { target: Minimize; function onRequested(wid,
    // source) {…} }) and set `builtin` false to drop the hidden-workspace one below. wid is niri's
    // window id (-1 when the window isn't known to niri), source who asked: "app", "settings",
    // "menu", "keys".
    signal requested(int wid, string source)
    property bool builtin: true
    function request(wid, source) {
        requested(wid === undefined || wid === null ? -1 : wid, source || "");
        if (builtin && wid >= 0)
            minimize(wid);
    }

    // ---- the apps' own minimize buttons (GTK's yellow light, Qt's, Firefox's) ----
    // extras/minimize-hook (LD_PRELOAD) catches their xdg_toplevel.set_minimized, which niri
    // ignores, and sends "<pid>\t<title>" here; only while the skin is on (the socket is gone
    // otherwise and the request goes to niri as before)
    readonly property string socketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/angelos-minimize.sock"
    SocketServer {
        active: GoldenGate.on
        path: root.socketPath
        handler: Socket {
            parser: SplitParser {
                onRead: line => root.fromApp(line)
            }
        }
    }
    // apps the session bus starts (Nautilus) get their environment from systemd's user manager;
    // environment.d can't hold ld.so's literal $LIB, so the shell puts the preload there each
    // login (extras/minimize-hook/install.sh puts it in angelos.service and niri's config; the
    // dotfiles' install.sh too, for everyone) — not once `install.sh --remove` left minimize-hook.off
    readonly property string hookLib: Quickshell.env("HOME") + "/.local/lib/angelos/$LIB/libangelos-minimize.so"
    Process {
        running: true
        command: ["sh", "-c", 'lib="$1"; [ -f "$(printf %s "$lib" | sed "s/\\$LIB/lib/")" ] || exit 0; [ -e "$HOME/.config/angelos/minimize-hook.off" ] && exit 0; cur=$(systemctl --user show-environment 2>/dev/null | sed -n "s/^LD_PRELOAD=//p" | sed "s/^\\$\x27\\(.*\\)\x27$/\\1/"); case "$cur" in *libangelos-minimize.so*) exit 0 ;; "") v="$lib" ;; *) v="$cur:$lib" ;; esac; systemctl --user set-environment "LD_PRELOAD=$v"', "sh", root.hookLib]
    }
    // which window of that process: the one with that title (Nautilus runs all its windows in one
    // process), the focused one, the last focused
    function fromApp(line) {
        const tab = String(line).indexOf("\t");
        const pid = parseInt(tab < 0 ? line : String(line).slice(0, tab));
        const title = tab < 0 ? "" : String(line).slice(tab + 1);
        const ts = w => w.focus_timestamp ? w.focus_timestamp.secs * 1e9 + w.focus_timestamp.nanos : 0;
        const mine = Niri.windows.filter(w => w.pid === pid && !isMinimized(w)).sort((a, b) => (b.is_focused - a.is_focused) || ts(b) - ts(a));
        const named = title ? mine.filter(w => w.title === title) : [];
        const w = named[0] || mine[0];
        if (w)
            request(w.id, "app");
    }

    // ---- away ----
    property var _queue: []
    function minimize(id) {
        const w = Niri.windows.find(x => x.id === id);
        const ws = w ? Niri.workspaceById(w.workspace_id) : null;
        if (!w || !ws || isMinimized(w) || _queue.some(q => q.id === id))
            return;
        const rect = rectOf(w, ws.output);
        const o = Object.assign({}, origin);
        o[id] = {
            "ws": ws.id,
            "output": ws.output,
            "rect": rect
        };
        origin = o;
        _queue = _queue.concat([{
                "id": id,
                "output": ws.output,
                "rect": rect
            }]);
        _next();
    }
    // the window on the screen, in the global logical coordinates grim takes
    function rectOf(w, output) {
        const s = Shell.screenByName(output);
        const l = w.layout;
        if (!s || !l || !l.tile_size)
            return null;
        const pos = l.tile_pos_in_workspace_view || tiledPos(w, s);
        if (!pos)
            return null;
        const x = Math.round(s.x + pos[0]);
        const y = Math.round(s.y + pos[1]);
        const wd = Math.round(l.tile_size[0]);
        const ht = Math.round(l.tile_size[1]);
        // only what is on the screen
        const x0 = Math.max(x, s.x), y0 = Math.max(y, s.y);
        const x1 = Math.min(x + wd, s.x + s.width), y1 = Math.min(y + ht, s.y + s.height);
        return x1 - x0 < 8 || y1 - y0 < 8 ? null : [x0, y0, x1 - x0, y1 - y0];
    }
    // niri tells where floating windows are, not tiled ones. The focused column is where niri
    // centres it (center-focused-column "always", Settings → Windows): in the middle across; down,
    // its windows fill the working area — the screen less the Dock's zone (MacDock writes
    // dockZone) and the gaps — so they are counted up from its bottom; across, the working area
    // is narrower by the zone of a Dock on the left or right. Otherwise: no snapshot.
    property var dockZone: ({})             // output -> the Dock's exclusive zone, px
    property var dockEdge: ({})             // output -> the edge it stands on: bottom | left | right
    function tiledPos(w, s) {
        const l = w.layout;
        const ws = Niri.workspaceById(w.workspace_id);
        if (!ws || !ws.is_active || !w.is_focused || !l.pos_in_scrolling_layout)
            return null;
        const size = l.tile_size;
        if (size[0] >= s.width && size[1] >= s.height)
            return [0, 0];
        const edge = dockEdge[ws.output] || "bottom";
        const zone = dockZone[ws.output] || 0;
        const zl = edge === "left" ? zone : 0, zr = edge === "right" ? zone : 0, zb = edge === "bottom" ? zone : 0;
        if (WindowConfig.center !== "always" || size[0] > s.width - zl - zr)
            return null;
        const col = l.pos_in_scrolling_layout[0];
        const column = Niri.windows.filter(x => x.workspace_id === w.workspace_id && !x.is_floating && x.layout && x.layout.pos_in_scrolling_layout && x.layout.pos_in_scrolling_layout[0] === col && x.layout.tile_size).sort((a, b) => a.layout.pos_in_scrolling_layout[1] - b.layout.pos_in_scrolling_layout[1]);
        const gap = Math.max(0, WindowConfig.gaps);
        const total = column.reduce((a, x) => a + x.layout.tile_size[1], 0) + gap * Math.max(0, column.length - 1);
        let y = s.height - zb - gap - total;
        for (const x of column) {
            if (x.id === w.id)
                break;
            y += x.layout.tile_size[1] + gap;
        }
        return y < 0 ? null : [zl + (s.width - zl - zr - size[0]) / 2, y];
    }
    function _next() {
        // (one whose snapshot is in flight already waits for goTimer, not for another shot)
        const q = _queue.find(x => !x.flown);
        if (shooter.running || !q)
            return;
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
        if (flightMs > 0 && shots[q.id] && q.rect && !q.flown) {
            q.flown = true;
            fly(q.id, q.output, q.rect, false);
            Qt.callLater(() => goTimer.go(q));
            return;
        }
        _queue = _queue.filter(x => x !== q);
        const w = Niri.windows.find(x => x.id === q.id);
        const name = Niri.hiddenPrefix + q.output;
        // the output's hidden workspace, or its last one (niri keeps an empty one there) named so;
        // the window goes there by id — not by the name, which a moment ago was not there yet
        const target = hiddenOn(q.output) || Niri.allWorkspaces.filter(x => x.output === q.output).sort((a, b) => b.idx - a.idx)[0];
        if (w && target) {
            if (!Niri.isHidden(target))
                Niri.action("SetWorkspaceName", {
                    "name": name,
                    "workspace": {
                        "Id": target.id
                    }
                });
            Niri.action("MoveWindowToWorkspace", {
                "window_id": q.id,
                "reference": {
                    "Id": target.id
                },
                "focus": false
            });
            order = order.filter(x => x !== q.id).concat([q.id]);
        }
        _next();
    }

    // ---- hidden with the app (⌘H) ----
    // every window of the app (its app id) that is out goes the way ⌘M sends one — the snapshot
    // flies (Genie or Scale) into the app's own Dock icon, not into a place of its own: hidden
    // windows get no thumbnail in the Dock, the app keeps its running dot. Windows that are not on
    // the screen go at once; its minimized ones stay minimized
    function hide(id) {
        const w = Niri.windows.find(x => x.id === id);
        if (!w)
            return;
        const mine = Niri.windows.filter(x => x.app_id === w.app_id && !isMinimized(x) && !_queue.some(q => q.id === x.id));
        const h = Object.assign({}, hidden);
        const o = Object.assign({}, origin);
        const jobs = [];
        for (const x of mine) {
            const ws = Niri.workspaceById(x.workspace_id);
            if (!ws)
                continue;
            h[x.id] = true;
            const rect = ws.is_active ? rectOf(x, ws.output) : null;
            o[x.id] = {
                "ws": ws.id,
                "output": ws.output,
                "rect": rect
            };
            jobs.push({
                "id": x.id,
                "output": ws.output,
                "rect": rect
            });
        }
        hidden = h;
        origin = o;
        _queue = _queue.concat(jobs);
        _next();
    }
    // all the hidden windows of an app come back to the desktop in front on `output`, the one
    // used last (or `focusId`) focused
    function unhide(appId, focusId, output) {
        const mine = hiddenWindows.filter(w => w.app_id === appId);
        if (!mine.length)
            return false;
        const ts = w => w.focus_timestamp ? w.focus_timestamp.secs * 1e9 + w.focus_timestamp.nanos : 0;
        const front = mine.find(w => w.id === focusId) || mine.slice().sort((a, b) => ts(b) - ts(a))[0];
        const to = currentDesk(output || Niri.focusedOutput);
        if (!to)
            return false;
        for (const w of mine)
            if (w.id !== front.id)
                Niri.action("MoveWindowToWorkspace", {
                    "window_id": w.id,
                    "reference": {
                        "Id": to.id
                    },
                    "focus": false
                });
        _setTo(front.id, to);
        _restoreNow(front.id);
        for (const w of mine)
            forget(w.id);
        return true;
    }
    function hiddenOf(appId) {
        return hiddenWindows.filter(w => w.app_id === appId);
    }

    // ---- back ----
    // to the desktop in front on `output` (the Dock's screen; the focused one when not given),
    // focused. Animated (a click in the Dock): the snapshot flies out of the Dock to where the
    // window was, the window comes back under it as it lands — when it returns to the screen it
    // left (a floating window keeps its place across that screen's desktops; a tiled one comes back
    // centred, as it went). Instant (Alt+Tab, the overview — niri has already gone to the window)
    // when asked so, on another screen, or with nothing to fly. A hidden app's window brings all
    // of the app back.
    function restore(id, instant, output) {
        const w = Niri.windows.find(x => x.id === id);
        if (!w)
            return;
        if (!isMinimized(w)) {
            Niri.focusWindow(id);
            return;
        }
        const out = output || Niri.focusedOutput || (origin[id] || {}).output || "";
        if (hidden[id]) {
            unhide(w.app_id, id, out);
            return;
        }
        const to = currentDesk(out);
        if (to)
            _setTo(id, to);
        const o = origin[id];
        if (!instant && flightMs > 0 && shots[id] && o && o.rect && o.output === out) {
            if (flying.indexOf(id) < 0)
                fly(id, o.output, o.rect, true);
            return;
        }
        _restoreNow(id);
    }
    function _setTo(id, ws) {
        const t = Object.assign({}, _to);
        t[id] = ws.id;
        _to = t;
    }
    function _restoreNow(id) {
        const w = Niri.windows.find(x => x.id === id);
        if (!w || !isMinimized(w))
            return;
        const hid = Niri.workspaceById(w.workspace_id);
        let to = Niri.workspaceById(_to[id]);
        if (!to || Niri.isHidden(to))
            to = currentDesk(Niri.focusedOutput) || currentDesk(hid.output);
        if (!to)
            return;
        // First quietly onto the desktop (by id, focus false: niri switches no workspace — its
        // `focus: true` is "smart" and, with the hidden workspace in front, would switch on its
        // own), then focused there. A tiled window is a new column right of the focused one, and
        // focusing it scrolls the view: niri slides it in from the side while its snapshot has
        // landed in the middle. A screen transition freezes the screen (the snapshot where the
        // window is going) over the move and the scroll and fades to the result.
        if (!w.is_floating && to.is_active && Motion.ms(100) > 0)
            Niri.action("DoScreenTransition", {
                "delay_ms": 200
            });
        Niri.action("MoveWindowToWorkspace", {
            "window_id": id,
            "reference": {
                "Id": to.id
            },
            "focus": false
        });
        Niri.action("FocusWindow", {
            "id": id
        });
        forget(id);
    }
    function restoreAll() {
        const mins = windows.slice();
        const apps = {};
        for (const w of hiddenWindows)
            apps[w.app_id] = true;
        for (const a in apps)
            unhide(a, -1, "");
        for (const w of mins)
            restore(w.id, true);
    }

    // ---- the flight: macOS's Scale effect (MacMinimizeFx draws it) ----
    // a snapshot of the window shrinks into its place in the Dock (or grows out of it); the Dock
    // tells where its items are (dockSlots, written by MacDock as it lays out — not a bound
    // property: the magnification moves them every frame). Motion off: no flight, as before.
    // Genie (the window bends and pours into the Dock) or Scale (it shrinks into it), as macOS's
    // "Minimise windows using"; Genie takes a little longer, as there
    readonly property string effect: Config.mac.minimizeEffect === "scale" ? "scale" : "genie"
    readonly property int flightMs: Motion.ms(effect === "genie" ? 560 : 380)
    property var flights: []                // [{key, id, output, rect, shot, back}]
    readonly property var flying: flights.map(f => f.id)
    property var dockSlots: ({})            // output + "|" + key -> [centre x, centre y, size], screen px
    function slotOf(output, id) {
        // a hidden app's window (⌘H) flies into the app's icon (MacDock reports "@app:<app id>")
        if (hidden[id]) {
            const w = Niri.windows.find(x => x.id === id);
            const s = w ? dockSlots[output + "|@app:" + w.app_id] : null;
            if (s)
                return s;
        }
        return dockSlots[output + "|@w" + id] || dockSlots[output + "|@downloads"] || null;
    }
    property int _flightN: 0
    function fly(id, output, rect, back) {
        _flightN++;
        flights = flights.concat([{
                "key": _flightN,
                "id": id,
                "output": output,
                "rect": rect,
                "shot": shots[id],
                "back": back
            }]);
    }
    // a flight ended: back home, the window returns under the snapshot (which goes a moment later)
    function landed(key) {
        const f = flights.find(x => x.key === key);
        if (!f)
            return;
        if (!f.back) {
            flights = flights.filter(x => x.key !== key);
            return;
        }
        // the window is drawn a frame or two after niri moves it: the snapshot covers that
        _restoreNow(f.id);
        dropLater.keys = dropLater.keys.concat([key]);
        dropLater.restart();
    }
    Timer {
        id: dropLater
        property var keys: []
        interval: 150
        onTriggered: {
            const ks = keys;
            keys = [];
            root.flights = root.flights.filter(x => ks.indexOf(x.key) < 0);
        }
    }
    // the window leaves a frame after its snapshot is up over it
    Timer {
        id: goTimer
        property var jobs: []
        interval: 30
        function go(q) {
            jobs = jobs.concat([q]);
            restart();
        }
        onTriggered: {
            const js = jobs;
            jobs = [];
            for (const q of js)
                root._away(q);
        }
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
        if (hidden[id]) {
            const h = Object.assign({}, hidden);
            delete h[id];
            hidden = h;
        }
        if (_to[id] !== undefined) {
            const t = Object.assign({}, _to);
            delete t[id];
            _to = t;
        }
    }
    Connections {
        target: Niri
        function onRestoreRequested(id) {
            root.restore(id, true);
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
                root.restore(f.id, true);
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
        function onWorkspacesChanged() {
            root.noteDesks();
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

    // ---- kept over a restart of the shell: the snapshots, where the windows came from, the order ----
    // (in the runtime dir, as the snapshots: gone with the session, as the windows are)
    readonly property string stateFile: dir + "/state.json"
    property bool _loaded: false
    onShotsChanged: if (_loaded)
        saveLater.restart()
    onOriginChanged: if (_loaded)
        saveLater.restart()
    onOrderChanged: if (_loaded)
        saveLater.restart()
    onHiddenChanged: if (_loaded)
        saveLater.restart()
    Timer {
        id: saveLater
        interval: 300
        onTriggered: {
            saver.command = ["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$3.tmp" && mv "$3.tmp" "$3"', "sh", root.dir, JSON.stringify({
                    "shots": root.shots,
                    "origin": root.origin,
                    "order": root.order,
                    "hidden": root.hidden
                }), root.stateFile];
            saver.running = true;
        }
    }
    Process {
        id: saver
    }
    Process {
        id: loader
        running: true
        command: ["sh", "-c", 'cat "$1" 2>/dev/null; true', "sh", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const st = text.trim() ? JSON.parse(text) : {};
                    // only what is still there: niri keeps window ids for its session
                    const alive = id => Niri.windows.some(w => String(w.id) === String(id));
                    const pick = o => {
                        const out = {};
                        for (const k in o || {})
                            if (!Niri.ready || alive(k))
                                out[k] = o[k];
                        return out;
                    };
                    root.shots = Object.assign(pick(st.shots), root.shots);
                    root.origin = Object.assign(pick(st.origin), root.origin);
                    root.hidden = Object.assign(pick(st.hidden), root.hidden);
                    root.order = (st.order || []).filter(id => !Niri.ready || alive(id)).concat(root.order.filter(id => (st.order || []).indexOf(id) < 0));
                } catch (e) {
                    console.warn("angelOS minimize: state", e);
                }
                root._loaded = true;
            }
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
