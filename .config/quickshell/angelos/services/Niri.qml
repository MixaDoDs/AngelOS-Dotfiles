pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// niri IPC: event stream for state + a request socket for actions.
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET")
    readonly property bool available: socketPath !== ""

    property var workspaces: []       // sorted by output, idx; without the hidden ones (below)
    // every workspace, the hidden ones too: a workspace named hiddenPrefix + output holds the
    // windows minimized on that output (services/Minimize — niri itself has no minimizing); the
    // shell's lists of desktops leave it out
    property var allWorkspaces: []
    readonly property string hiddenPrefix: "angelos-minimized-"
    function isHidden(ws) {
        return !!ws && String(ws.name || "").indexOf(hiddenPrefix) === 0;
    }
    // the angel's window for OBS (modules/y2k/StreamerCast) is the shell's own and nobody's to
    // see: kept out of `windows` (the taskbar, Alt+Tab, minimizing), its id and workspace here
    readonly property string castTitle: "angelOS · ангел для OBS"
    property int castWindowId: -1
    property int castWindowWs: -1
    function _isCast(w) {
        return w.app_id === "org.quickshell" && w.title === castTitle;
    }
    property var windows: []
    property int focusedWindowId: -1
    // A title alone changes many times a second (a terminal's spinner, a player's track):
    // it is patched into its window in place and announced by this tick only, so the
    // taskbar, Alt+Tab and the title bars re-read one string instead of rebuilding
    // their lists. Read titles through titleOf(window).
    property int titleTick: 0
    function titleOf(w) {
        titleTick;
        return w ? w.title || "" : "";
    }
    property var keyboardLayouts: []
    property int currentLayout: 0
    property bool overviewOpen: false
    property bool ready: false
    readonly property string focusedOutput: {
        const ws = allWorkspaces.find(w => w.is_focused) || workspaces.find(w => w.is_focused);
        return ws ? ws.output : "";
    }
    readonly property var focusedWindow: windows.find(w => w.id === focusedWindowId) || null
    readonly property string layoutName: keyboardLayouts[currentLayout] || ""
    readonly property string layoutShort: shortLayout(layoutName)

    // emitted only after the initial state arrived (never on startup)
    signal workspaceActivated(var ws, bool focused)
    // a hidden workspace came to the front (scrolled to, the overview): services/Minimize
    signal hiddenActivated(var ws, var from)
    // the shell asked to focus a minimized window: services/Minimize brings it back
    signal restoreRequested(int id)
    signal layoutSwitched(string name)
    signal configLoaded(bool failed)
    signal windowClosed(int id)
    signal windowOpened(int id)

    function shortLayout(name) {
        if (!name)
            return "";
        const map = {
            "English (US)": "EN",
            "Russian": "RU",
            "Ukrainian": "UA",
            "German": "DE",
            "French": "FR",
            "Japanese": "JP",
            "Belarusian": "BY",
            "Kazakh": "KZ"
        };
        if (map[name])
            return map[name];
        const m = name.match(/\(([A-Z]{2})\)/);
        return m ? m[1] : name.slice(0, 2).toUpperCase();
    }

    function workspacesOn(output) {
        return workspaces.filter(w => w.output === output);
    }
    function activeWorkspace(output) {
        return workspaces.find(w => w.output === output && w.is_active) || null;
    }
    function windowsOn(wsId) {
        return windows.filter(w => w.workspace_id === wsId);
    }
    function workspaceById(id) {
        return workspaces.find(w => w.id === id) || allWorkspaces.find(w => w.id === id) || null;
    }
    function sortedWindows(list) {
        return list.slice().sort((a, b) => {
            const wa = workspaceById(a.workspace_id), wb = workspaceById(b.workspace_id);
            const oa = wa ? wa.output + ":" + ("00" + wa.idx).slice(-3) : "~";
            const ob = wb ? wb.output + ":" + ("00" + wb.idx).slice(-3) : "~";
            if (oa !== ob)
                return oa < ob ? -1 : 1;
            const pa = a.layout && a.layout.pos_in_scrolling_layout ? a.layout.pos_in_scrolling_layout : [999, 999];
            const pb = b.layout && b.layout.pos_in_scrolling_layout ? b.layout.pos_in_scrolling_layout : [999, 999];
            return pa[0] - pb[0] || pa[1] - pb[1] || a.id - b.id;
        });
    }

    // ---- actions ----
    function action(name, args) {
        const body = {};
        body[name] = args || {};
        request({
            "Action": body
        });
    }
    function focusWorkspace(id) {
        action("FocusWorkspace", {
            "reference": {
                "Id": id
            }
        });
    }
    function focusWindow(id) {
        const w = windows.find(x => x.id === id);
        if (w && isHidden(workspaceById(w.workspace_id))) {
            restoreRequested(id);
            return;
        }
        action("FocusWindow", {
            "id": id
        });
    }
    function closeWindow(id) {
        action("CloseWindow", {
            "id": id
        });
    }
    function fullscreenWindow(id) {
        action("FullscreenWindow", {
            "id": id
        });
    }
    function maximizeWindow(id) {
        action("MaximizeWindowToEdges", {
            "id": id
        });
    }
    function toggleFloating(id) {
        action("ToggleWindowFloating", {
            "id": id
        });
    }
    function moveWindowToWorkspace(id, wsIdx) {
        action("MoveWindowToWorkspace", {
            "window_id": id,
            "reference": {
                "Index": wsIdx
            },
            "focus": false
        });
    }
    function moveWindowToMonitor(id, output) {
        action("MoveWindowToMonitor", {
            "id": id,
            "output": output
        });
    }
    function switchLayout(next) {
        action("SwitchLayout", {
            "layout": next === false ? "Prev" : "Next"
        });
    }
    function quit() {
        action("Quit", {
            "skip_confirmation": true
        });
    }
    function powerOffMonitors() {
        action("PowerOffMonitors", {});
    }
    function toggleOverview() {
        action("ToggleOverview", {});
    }

    // one request per connection (niri closes the socket after replying)
    property var _queue: []
    property var _current: null
    function request(obj, cb) {
        _queue.push({
            "body": JSON.stringify(obj),
            "cb": cb
        });
        _pump();
    }
    function _pump() {
        if (_current || _queue.length === 0 || !available)
            return;
        _current = _queue.shift();
        req.connected = true;
    }

    Socket {
        id: req
        path: root.socketPath
        onConnectedChanged: {
            if (connected && root._current) {
                write(root._current.body + "\n");
                flush();
            } else if (!connected) {
                root._current = null;
                Qt.callLater(root._pump);
            }
        }
        onError: {
            root._current = null;
            connected = false;
        }
        parser: SplitParser {
            onRead: line => {
                const cur = root._current;
                try {
                    const reply = JSON.parse(line);
                    if (reply.Err)
                        console.warn("niri:", reply.Err);
                    if (cur && cur.cb)
                        cur.cb(reply.Ok !== undefined ? reply.Ok : null, reply.Err || null);
                } catch (e) {
                    console.warn("niri reply parse:", e);
                }
                req.connected = false;
            }
        }
    }

    // ---- event stream ----
    Socket {
        id: events
        path: root.socketPath
        connected: root.available
        onConnectedChanged: {
            if (connected) {
                write('"EventStream"\n');
                flush();
            } else {
                reconnect.start();
            }
        }
        parser: SplitParser {
            onRead: line => root._handle(line)
        }
    }

    Timer {
        id: reconnect
        interval: 1000
        onTriggered: events.connected = true
    }

    function _sameBesidesTitle(a, b) {
        const ka = Object.keys(a), kb = Object.keys(b);
        if (ka.length !== kb.length)
            return false;
        for (const k of kb)
            if (k !== "title" && JSON.stringify(a[k]) !== JSON.stringify(b[k]))
                return false;
        return true;
    }

    // While a window is dragged with Mod + mouse (niri's interactive move) niri reports it on
    // no workspace (workspace_id null) until it is dropped: the taskbar, Alt+Tab and the
    // window menu would lose it mid-drag. It keeps its last workspace, marked `moving`.
    function _keepWorkspace(w, old) {
        if (w.workspace_id === null || w.workspace_id === undefined) {
            if (old && old.workspace_id !== null && old.workspace_id !== undefined)
                return Object.assign({}, w, {
                    "workspace_id": old.workspace_id,
                    "moving": true
                });
        }
        return w;
    }

    function _setWorkspaces(list) {
        allWorkspaces = list.slice().sort((a, b) => a.output === b.output ? a.idx - b.idx : (a.output < b.output ? -1 : 1));
        workspaces = allWorkspaces.filter(w => !isHidden(w));
    }

    function _handle(line) {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (ev.Ok !== undefined)
            return;
        const kind = Object.keys(ev)[0];
        const d = ev[kind];
        switch (kind) {
        case "WorkspacesChanged":
            _setWorkspaces(d.workspaces);
            if (!ready)
                readyTimer.restart();
            break;
        case "WorkspaceActivated":
            {
                const target = allWorkspaces.find(w => w.id === d.id);
                if (!target)
                    break;
                const switched = !target.is_active; // focus moving to another monitor is not a switch
                const from = allWorkspaces.find(w => w.output === target.output && w.is_active) || null;
                _setWorkspaces(allWorkspaces.map(w => {
                    const c = Object.assign({}, w);
                    if (w.output === target.output)
                        c.is_active = w.id === d.id;
                    if (d.focused)
                        c.is_focused = w.id === d.id;
                    return c;
                }));
                if (ready && switched && isHidden(target))
                    hiddenActivated(target, from);
                else if (ready && switched)
                    workspaceActivated(workspaces.find(w => w.id === d.id), d.focused);
                break;
            }
        case "WorkspaceActiveWindowChanged":
            _setWorkspaces(allWorkspaces.map(w => w.id === d.workspace_id ? Object.assign({}, w, {
                    "active_window_id": d.active_window_id
                }) : w));
            break;
        case "WorkspaceUrgencyChanged":
            _setWorkspaces(allWorkspaces.map(w => w.id === d.id ? Object.assign({}, w, {
                    "is_urgent": d.urgent
                }) : w));
            break;
        case "WindowsChanged":
            {
                const cast = d.windows.find(w => root._isCast(w));
                castWindowId = cast ? cast.id : -1;
                castWindowWs = cast ? cast.workspace_id : -1;
            }
            windows = d.windows.filter(w => !root._isCast(w)).map(w => _keepWorkspace(w, windows.find(o => o.id === w.id)));
            {
                const f = d.windows.find(w => w.is_focused);
                focusedWindowId = f ? f.id : -1;
            }
            break;
        case "WindowOpenedOrChanged":
            if (_isCast(d.window) || d.window.id === castWindowId) {
                castWindowId = d.window.id;
                castWindowWs = d.window.workspace_id;
                break;
            }
            {
                const old = windows.find(w => w.id === d.window.id);
                const next = _keepWorkspace(d.window, old);
                if (old && _sameBesidesTitle(old, next)) {
                    if (old.title !== next.title) {
                        old.title = next.title;
                        titleTick++;
                    }
                    break;
                }
                const list = windows.filter(w => w.id !== d.window.id);
                const isNew = !old;
                list.push(next);
                if (d.window.is_focused) {
                    focusedWindowId = d.window.id;
                    for (let i = 0; i < list.length; i++)
                        if (list[i].id !== d.window.id && list[i].is_focused)
                            list[i] = Object.assign({}, list[i], {
                                "is_focused": false
                            });
                }
                windows = list;
                if (isNew && ready)
                    windowOpened(d.window.id);
                break;
            }
        case "WindowClosed":
            if (d.id === castWindowId) {
                castWindowId = -1;
                castWindowWs = -1;
            }
            windows = windows.filter(w => w.id !== d.id);
            if (ready)
                windowClosed(d.id);
            if (focusedWindowId === d.id)
                focusedWindowId = -1;
            break;
        case "WindowFocusChanged":
            focusedWindowId = d.id === null ? -1 : d.id;
            windows = windows.map(w => w.is_focused === (w.id === d.id) ? w : Object.assign({}, w, {
                    "is_focused": w.id === d.id
                }));
            break;
        case "WindowFocusTimestampChanged":
            windows = windows.map(w => w.id === d.id ? Object.assign({}, w, {
                    "focus_timestamp": d.focus_timestamp
                }) : w);
            break;
        case "WindowUrgencyChanged":
            windows = windows.map(w => w.id === d.id ? Object.assign({}, w, {
                    "is_urgent": d.urgent
                }) : w);
            break;
        case "WindowLayoutsChanged":
            {
                const map = {};
                for (const [id, layout] of d.changes)
                    map[id] = layout;
                windows = windows.map(w => map[w.id] ? Object.assign({}, w, {
                        "layout": map[w.id]
                    }) : w);
                break;
            }
        case "KeyboardLayoutsChanged":
            keyboardLayouts = d.keyboard_layouts.names;
            currentLayout = d.keyboard_layouts.current_idx;
            break;
        case "KeyboardLayoutSwitched":
            currentLayout = d.idx;
            if (ready)
                layoutSwitched(layoutName);
            break;
        case "OverviewOpenedOrClosed":
            overviewOpen = d.is_open;
            break;
        case "ConfigLoaded":
            configLoaded(!!d.failed);
            break;
        }
    }

    // initial burst of events settles before we start animating
    Timer {
        id: readyTimer
        interval: 400
        onTriggered: root.ready = true
    }
}
