pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Strip ↔ Desktop (angel-niri stacking) remembers each side (Settings → Windows → Desktop or
// Strip → «Each side keeps its windows»; off by default). Leaving a side it notes every window:
// minimized or not, its desk and column, in Desktop its place and size. Coming back to that side
// the windows are made as they were, in this order:
//   1. away   — the ones minimized there go: those on the screen with the minimize animation
//               (into the taskbar / the Dock), those on other desks quietly
//   2. switch — the stacking switch itself; the ones staying fly in / drop off (desk throw)
//   3. place  — the open ones onto their desks (Strip) or glide to their places (Desktop); the
//               Strip shows the desk of the window that had the focus
//   4. back   — the ones open there come out of the taskbar / the Dock with the restore
//               animation onto the desk on the screen (in Desktop right where they stood);
//               the Strip's on other desks go back onto theirs quietly
//   5. order  — the Strip's columns in their old order; then the focus goes back
// (angel-niri's own record of the desks loses windows minimized around the switch — the desks
// slid — so the Strip's desks and columns are put back here.) Windows opened meanwhile are left
// alone, closed ones are skipped (an id is checked with its app). Sides: "strip" and "desk".
// Kept for the session in $XDG_RUNTIME_DIR (niri's ids live as long). Caller:
// WindowConfig.setFloatAll. Ported from pc-kit (Frostpix11).
Singleton {
    id: root

    property var mem: ({})
    property bool busy: false
    // where a switch under way goes: "on" (Desktop) | "off" (Strip), "" when none
    readonly property string heading: busy ? (_to === "strip" ? "off" : "on") : ""
    property string _to: ""
    property var _switch: null
    property var _done: null
    property real _throwEnd: 0
    property string _phase: ""
    property var _back: []          // ids to bring back in step 4

    function _key(w) {
        return String(w.id) + "|" + (w.app_id || "");
    }
    function snap(key) {
        const wins = {};
        for (const w of Niri.windows) {
            const ws = Niri.workspaceById(w.workspace_id);
            const l = w.layout || {};
            wins[_key(w)] = {
                "min": !!w.is_minimized,
                "out": ws ? ws.output : "",
                "idx": ws ? ws.idx : -1,
                "floating": !!w.is_floating,
                "pos": l.tile_pos_in_workspace_view || null,
                "tile": l.tile_size || null,
                "col": l.pos_in_scrolling_layout ? l.pos_in_scrolling_layout[0] : -1,
                "size": l.window_size || null
            };
        }
        // a side left with every window minimized (the desktop shown, a skin's peek) is no state
        // to come back to: kept, the next visit minimized them all again and the next leaving
        // noted that again — the side stuck empty for good (2026-11-13).
        // The side keeps what it had before
        const ws = Object.values(wins);
        if (ws.length > 0 && ws.every(x => x.min) && (key in mem))
            return;
        const f = Niri.windows.find(w => w.is_focused);
        const m = Object.assign({}, mem);
        m[key] = {
            "wins": wins,
            "focus": f ? _key(f) : ""
        };
        mem = m;
        _save();
    }
    function forget(key) {
        if (!(key in mem))
            return;
        const m = Object.assign({}, mem);
        delete m[key];
        mem = m;
        _save();
    }
    function _saved(key, w) {
        const m = mem[key];
        return m ? m.wins[_key(w)] || null : null;
    }
    function _win(id) {
        return Niri.windows.find(w => w.id === id) || null;
    }
    // on the screen now: on its output's shown desk
    function _shown(w) {
        const ws = Niri.workspaceById(w.workspace_id);
        return !!ws && !!ws.is_active;
    }
    function _wait(ms) {
        step.interval = Math.max(1, ms);
        step.restart();
    }

    // from side `from` to side `to`: switchFn() is the stacking switch itself, doneFn() runs when
    // everything has landed; false while a switch is still under way
    function run(from, to, switchFn, doneFn) {
        if (busy)
            return false;
        busy = true;
        _to = to;
        _switch = switchFn;
        _done = doneFn;
        snap(from);
        _back = [];
        let flying = 0, quiet = 0;
        if (mem[to]) {
            for (const w of Niri.windows) {
                const s = _saved(to, w);
                if (!s || Minimize.isAppHidden(w))
                    continue;
                if (s.min && !w.is_minimized) {
                    if (_shown(w) && Minimize.canFly) {
                        Minimize.minimize(w.id);    // its snapshot flies into the taskbar / Dock
                        flying++;
                    } else {
                        Niri.action("MinimizeWindow", {
                            "id": w.id,
                            "now": true
                        });
                        quiet++;
                    }
                } else if (!s.min && w.is_minimized) {
                    _back.push(w.id);
                }
            }
        }
        _phase = "away";
        _wait(flying ? Minimize.flightMs + 250 : quiet ? 150 : 1);
        return true;
    }
    Timer {
        id: step
        onTriggered: root._next()
    }
    function _next() {
        switch (_phase) {
        case "away":
            _phase = "switch";
            _throwEnd = 0;
            if (_switch)
                _switch();
            _wait(400);     // no DesksThrown by then: nothing flew
            break;
        case "switch":
            _phase = "place";
            _wait(_place() ? 320 : 1);
            break;
        case "place":
            _phase = "back";
            _wait(_bringBack());
            break;
        case "back":
            _phase = "order";
            _wait(_to === "strip" ? (_order() ? 300 : 1) : (_place() ? 320 : 1));
            break;
        case "order":
            _phase = "";
            _focus();
            busy = false;
            const d = _done;
            _switch = null;
            _done = null;
            if (d)
                d();
            break;
        }
    }
    Connections {
        target: Niri
        function onDesksThrown(hits) {
            if (root._phase !== "switch" || !hits.length)
                return;
            // the last hit (or slide), then the bounce home; leaving, angel-niri puts the windows
            // back ~0.12 s after the last drop — nothing may switch stacking again before
            const last = Math.max(...hits.map(h => h.in_ms || 0));
            const end = Date.now() + last + (hits[0].bottom ? 500 : 700);
            root._throwEnd = Math.min(Date.now() + 6000, Math.max(root._throwEnd, end));
            root._wait(root._throwEnd - Date.now());
        }
    }

    // step 3 (and again after step 4 in Desktop): the open windows to their places; whether
    // anything moved
    function _place() {
        const m = mem[_to];
        if (!m)
            return false;
        let moved = false;
        if (_to !== "strip") {
            for (const w of Niri.windows) {
                const s = _saved(_to, w);
                const l = w.layout || {};
                if (!s || s.min || w.is_minimized || !w.is_floating || !s.floating)
                    continue;
                if (s.size && l.window_size) {
                    if (Math.abs(s.size[0] - l.window_size[0]) > 3) {
                        Niri.action("SetWindowWidth", {
                            "id": w.id,
                            "change": {
                                "SetFixed": Math.round(s.size[0])
                            }
                        });
                        moved = true;
                    }
                    if (Math.abs(s.size[1] - l.window_size[1]) > 3) {
                        Niri.action("SetWindowHeight", {
                            "id": w.id,
                            "change": {
                                "SetFixed": Math.round(s.size[1])
                            }
                        });
                        moved = true;
                    }
                }
                const p = l.tile_pos_in_workspace_view;
                if (s.pos && p && (Math.abs(s.pos[0] - p[0]) > 2 || Math.abs(s.pos[1] - p[1]) > 2)) {
                    Niri.action("MoveFloatingWindow", {
                        "id": w.id,
                        "x": {
                            "AdjustFixed": s.pos[0] - p[0]
                        },
                        "y": {
                            "AdjustFixed": s.pos[1] - p[1]
                        }
                    });
                    moved = true;
                }
            }
            return moved;
        }
        // the Strip: each open window onto its desk, the lower desks first (a desk gone empty
        // meanwhile is made again at the end, so the next ones keep their numbers)
        const plan = [];
        for (const w of Niri.windows) {
            const s = _saved(_to, w);
            const ws = Niri.workspaceById(w.workspace_id);
            if (s && !s.min && !w.is_minimized && !w.is_floating && s.idx > 0 && ws && ws.output === s.out && ws.idx !== s.idx)
                plan.push([s.idx, w.id]);
        }
        plan.sort((a, b) => a[0] - b[0]);
        for (const [idx, id] of plan)
            Niri.action("MoveWindowToWorkspace", {
                "window_id": id,
                "reference": {
                    "Index": idx
                },
                "focus": false
            });
        // the desk that had the focus comes on the screen now, so the windows coming back onto it
        // are seen arriving
        const f = Niri.windows.find(w => _key(w) === m.focus && !w.is_minimized);
        if (f)
            Niri.action("FocusWindow", {
                "id": f.id
            });
        return true;
    }

    // step 4: the windows open on this side come back; ms to wait
    function _bringBack() {
        if (_to === "strip")
            return _bringBackStrip();
        let flying = 0;
        for (const id of _back) {
            const w = _win(id);
            if (!w || !w.is_minimized)
                continue;
            const s = _saved(_to, w);
            if (!s)
                continue;
            // Desktop: the snapshot lands right where the window stood there
            const o = Minimize.origin[id];
            const sc = Shell.screenByName(s.out);
            if (o && sc && s.pos && s.tile && o.output === s.out) {
                const og = Object.assign({}, Minimize.origin);
                og[id] = Object.assign({}, o, {
                    "rect": [Math.round(sc.x + s.pos[0]), Math.round(sc.y + s.pos[1]), Math.round(s.tile[0]), Math.round(s.tile[1])]
                });
                Minimize.origin = og;
            }
            Minimize.restore(id, false, s.out);
            flying++;
        }
        _back = [];
        return flying ? Minimize.flightMs + 350 : 1;
    }

    // the Strip: every window back onto its own desk, one by one, the desks in their order. With
    // every window minimized niri drops the emptied desks and the indexes slide (the shown one was
    // 0 or 3, the windows' 1 and 2): moved by index they landed elsewhere or stayed minimized
    // (2026-11-13). So a window goes to the desk that has its index now, by id, or — gone — to the
    // last (empty) one, after which niri opens a new empty one for the next index; the list is
    // read again between two moves. angel-niri brings a minimized window back where it is moved,
    // without the focus; step 6 focuses the remembered window, which shows its desk
    property var _stripQueue: []
    function _bringBackStrip() {
        const q = [];
        for (const id of _back) {
            const w = _win(id);
            const s = w && w.is_minimized ? _saved(_to, w) : null;
            if (s && s.out && s.idx >= 0)
                q.push({
                    "id": id,
                    "out": s.out,
                    "idx": s.idx,
                    "col": s.col
                });
        }
        _back = [];
        q.sort((a, b) => a.out < b.out ? -1 : a.out > b.out ? 1 : a.idx - b.idx || a.col - b.col);
        _stripQueue = q;
        if (!q.length)
            return 1;
        stripStep.restart();
        return q.length * stripStep.interval + 250;
    }
    Timer {
        id: stripStep
        interval: 150
        onTriggered: {
            const q = root._stripQueue.slice();
            const c = q.shift();
            root._stripQueue = q;
            if (c) {
                const desks = (Niri.allWorkspaces || []).filter(ws => ws.output === c.out && !Niri.isHidden(ws)).sort((a, b) => a.idx - b.idx);
                const to = desks.find(ws => ws.idx === c.idx) || desks[desks.length - 1];
                const w = root._win(c.id);
                if (to && w && w.is_minimized)
                    Niri.action("MoveWindowToWorkspace", {
                        "window_id": c.id,
                        "reference": {
                            "Id": to.id
                        },
                        "focus": false
                    });
            }
            if (q.length)
                restart();
        }
    }

    // step 5, the Strip: on every desk the remembered columns in their old order (focus a window,
    // move its column to its old index, left to right); whether anything moved
    function _order() {
        const desks = {};
        for (const w of Niri.windows) {
            const s = _saved(_to, w);
            const l = w.layout || {};
            if (!s || s.min || w.is_minimized || w.is_floating || !(s.col > 0) || !l.pos_in_scrolling_layout)
                continue;
            (desks[w.workspace_id] = desks[w.workspace_id] || []).push({
                "id": w.id,
                "want": s.col,
                "now": l.pos_in_scrolling_layout[0]
            });
        }
        let moved = false;
        for (const k in desks) {
            const list = desks[k].sort((a, b) => a.want - b.want);
            // already in this order (other windows between them are fine): nothing to do
            if (list.every((c, i) => i === 0 || list[i - 1].now < c.now))
                continue;
            for (const c of list) {
                Niri.action("FocusWindow", {
                    "id": c.id
                });
                Niri.action("MoveColumnToIndex", {
                    "index": c.want
                });
            }
            moved = true;
        }
        return moved;
    }
    function _focus() {
        const m = mem[_to];
        const f = m ? Niri.windows.find(w => _key(w) === m.focus && !w.is_minimized) : null;
        if (f && !f.is_focused)
            Niri.action("FocusWindow", {
                "id": f.id
            });
    }

    FileView {
        id: store
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos-stack-memory.json"
        printErrors: false
        onLoaded: {
            try {
                root.mem = JSON.parse(text()) || {};
            } catch (e) {
                root.mem = {};
            }
        }
    }
    function _save() {
        store.setText(JSON.stringify(mem));
    }
}
