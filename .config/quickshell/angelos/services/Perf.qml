pragma Singleton

import QtQuick
import Quickshell
import qs.config

// What the shell spends while it runs — `angelos perf [seconds]` (scripts/perf.py) asks here.
// Every window signs in through its RightClickGuard (each window has one: scripts/test-ui.sh
// checks); a walk over them finds what keeps working while nobody looks — repeating timers,
// endless animations, FrameAnimations, shaders on screen, helper processes — and a sample of N
// seconds counts the frames each window drew and the processes it started. Nothing is watched
// until a sample is asked for. The services' own timers show in the QML profile instead
// (`angelos perf --profile`, scripts/perf-trace.py): Quickshell's Scope does not list its
// children, so a walk cannot reach them.
//   snapshot()        JSON: the walk alone
//   start(seconds)    begin a sample; report() after it (scripts/perf.py waits in between)
Singleton {
    id: root

    property var guards: []
    function addWindow(guard) {
        guards = guards.filter(g => g && g !== guard).concat([guard]);
    }
    function dropWindow(guard) {
        guards = guards.filter(g => g && g !== guard);
    }
    // the windows: the QQuickWindow of a shown one, the content of a hidden one (Quickshell
    // keeps its items while the window is away; their timers and animations still run)
    function windowsNow() {
        const out = [], seen = new Set();
        for (const g of guards) {
            let w = null;
            try {
                w = g.hostWindow || g.parent;
            } catch (e) {}
            if (w && !seen.has(w)) {
                seen.add(w);
                out.push(w);
            }
        }
        return out;
    }

    // "BarLyrics_QMLTYPE_42(0x…)", "PxWindow_QMLTYPE_283_QML_456(0x…)" → "BarLyrics", "PxWindow";
    // C++ types stay as they are ("QQmlTimer")
    function typeName(o) {
        const s = String(o);
        const m = s.match(/^([A-Za-z0-9_]+?)(?:_QMLTYPE_\d+)?(?:_QML_\d+)?\(/);
        return m ? m[1] : s.slice(0, 40);
    }
    // the shell's own types name where a thing lives; Qt's and Quickshell's do not
    readonly property var builtin: ["Process", "Scope", "Variants", "LazyLoader", "PanelWindow", "FloatingWindow", "PopupWindow", "ProxyPanelWindow", "ProxyFloatingWindow", "ProxyPopupWindow", "IpcHandler", "FileView", "JsonAdapter", "JsonObject", "SplitParser", "StdioCollector", "Socket", "Region", "Connections", "Binding", "Component", "Instantiator", "Repeater", "Loader", "ListModel", "ScriptModel", "Behavior", "State", "Transition", "ElapsedTimer", "SystemClock", "ColorQuantizer", "ScreencopyView", "IconImage", "ClippingRectangle", "WrapperItem", "RightClickGuard", "ProxyWindowContentItem", "ZoneReport", "PxWindow"]
    function own(t) {
        return !/^Q[A-Z]/.test(t) && !builtin.includes(t) && /^[A-Z]/.test(t);
    }
    function kidsOf(o) {
        const out = [];
        const add = v => {
            if (!v || typeof v !== "object")
                return;
            if (v.length !== undefined) {
                for (let i = 0; i < v.length; i++)
                    if (v[i] && typeof v[i] === "object")
                        out.push(v[i]);
            } else
                out.push(v);
        };
        for (const k of ["data", "contentItem", "item", "instances", "animations"]) {
            try {
                if (o[k] !== undefined)
                    add(o[k]);
            } catch (e) {}
        }
        return out;
    }
    function screenOf(o) {
        try {
            return o.screen ? String(o.screen.name || "") : "";
        } catch (e) {
            return "";
        }
    }
    // the windows are the QQuickWindows that draw (a Quickshell window has one while it is shown)
    function shown(win) {
        try {
            return !!win && win.contentItem !== undefined && !!win.visible;
        } catch (e) {
            return false;
        }
    }

    // One pass over every window: visit(o, type, where, win) for each object in it. `where` is the
    // chain of the shell's own types above the object ("Bar › Clock").
    function walk(visit) {
        const seen = new Set();
        const stack = [];
        const push = (o, where, win, depth) => {
            if (!o || typeof o !== "object" || seen.has(o) || seen.size > 300000)
                return;
            seen.add(o);
            stack.push([o, where, win, depth]);
        };
        for (const w of windowsNow())
            push(w, [winName(w)], w, 0);
        while (stack.length) {
            const [o, where, win, depth] = stack.pop();
            const t = typeName(o);
            const w = own(t) && where[where.length - 1] !== t ? where.concat([t]) : where;
            visit(o, t, w, win);
            if (depth < 400)
                for (const c of kidsOf(o))
                    push(c, w, win, depth + 1);
        }
        return seen.size;
    }
    function at(where) {
        // the window, then the innermost two of the shell's own types
        return where.length <= 3 ? where.join(" › ") : [where[0], "…"].concat(where.slice(-2)).join(" › ");
    }
    // a window's name: the shell's own types it is or holds first, its size and screen
    function winName(win) {
        const parts = [];
        const self = typeName(win);
        if (own(self) && !/Window$/.test(self))
            parts.push(self);
        const q = [win.contentItem !== undefined ? win.contentItem : win];
        let n = 0;
        while (q.length && parts.length < 2 && n++ < 600) {
            const o = q.shift();
            const t = typeName(o);
            if (own(t) && !parts.includes(t) && !/^Px/.test(t))
                parts.push(t);
            for (const c of kidsOf(o))
                q.push(c);
        }
        return (parts.join("/") || self).replace(/^ProxyWindowContentItem\/?/, "") + " " + Math.round(win.width || 0) + "×" + Math.round(win.height || 0) + (screenOf(win) ? " @" + screenOf(win) : "");
    }

    function collect() {
        const timers = [], anims = [], frameAnims = [], procs = [], shaders = {};
        const perWin = new Map();
        const total = walk((o, t, where, win) => {
            const v = shown(win);
            perWin.set(win, (perWin.get(win) || 0) + 1);
            if (t === "QQmlTimer") {
                if (o.running && o.repeat)
                    timers.push({
                        "at": at(where),
                        "interval": o.interval,
                        "visible": v
                    });
            } else if (t === "QQuickFrameAnimation") {
                if (o.running && !o.paused)
                    frameAnims.push({
                        "at": at(where),
                        "visible": v
                    });
            } else if (/^QQuick\w*(Animation|Animator)$/.test(t)) {
                try {
                    if (o.running && !o.paused && o.loops === -1)
                        anims.push({
                            "at": at(where),
                            "type": t.replace(/^QQuick/, ""),
                            "visible": v
                        });
                } catch (e) {}
            } else if (t === "Process") {
                if (o.running)
                    procs.push({
                        "at": at(where),
                        "cmd": (o.command || []).slice(0, 4).join(" ").slice(0, 120)
                    });
            } else if (t === "QQuickShaderEffect") {
                try {
                    if (o.visible && v)
                        shaders[at(where)] = (shaders[at(where)] || 0) + 1;
                } catch (e) {}
            }
        });
        return {
            "objects": total,
            "windows": windowsNow().map(w => ({
                        "name": winName(w),
                        "visible": shown(w),
                        "objects": perWin.get(w) || 0
                    })),
            "timers": timers,
            "anims": anims,
            "frameAnims": frameAnims,
            "procs": procs,
            "shaders": Object.keys(shaders).map(k => ({
                        "at": k,
                        "count": shaders[k]
                    })),
            "motion": Motion.level,
            "guards": guards.length,
            "unhosted": guards.filter(g => {
                try {
                    return !g.hostWindow;
                } catch (e) {
                    return true;
                }
            }).length
        };
    }
    function snapshot() {
        return JSON.stringify(collect());
    }

    // ---- a sample: frames per window and processes started, for N seconds ----
    property var _hooks: []
    property var _frames: ({})
    property var _spawns: ({})
    property double _since: 0
    property bool sampling: false
    function start(seconds) {
        stop();
        const frames = {}, spawns = {}, hooks = [];
        const hook = (sig, fn) => {
            try {
                sig.connect(fn);
                hooks.push([sig, fn]);
            } catch (e) {}
        };
        for (const w of windowsNow()) {
            if (!shown(w))
                continue;
            const key = winName(w);
            frames[key] = frames[key] || 0;
            hook(w.frameSwapped, () => frames[key]++);
        }
        walk((o, t, where) => {
            if (t !== "Process")
                return;
            const cmd = (o.command || []).map(String);
            const exe = (cmd[0] || "").split("/").pop();
            const arg = cmd[1] === "-u" || cmd[1] === "-c" ? cmd[2] : cmd[1];
            const key = at(where) + " · " + exe + (/^(python3?|sh|bash)$/.test(exe) && arg ? " " + arg.split("/").pop().slice(0, 40) : "");
            hook(o.started, () => spawns[key] = (spawns[key] || 0) + 1);
        });
        _frames = frames;
        _spawns = spawns;
        _hooks = hooks;
        _since = Date.now();
        sampling = true;
        stopper.interval = Math.max(1, seconds || 10) * 1000 + 30000;   // a sample nobody reads ends by itself
        stopper.restart();
        return hooks.length;
    }
    function stop() {
        for (const [sig, fn] of _hooks)
            try {
                sig.disconnect(fn);
            } catch (e) {}
        _hooks = [];
        sampling = false;
        stopper.stop();
    }
    function report() {
        const secs = Math.max(0.001, (Date.now() - _since) / 1000);
        const r = collect();
        r.seconds = Math.round(secs * 10) / 10;
        r.frames = Object.keys(_frames).map(k => ({
                    "window": k,
                    "fps": Math.round(_frames[k] / secs * 10) / 10
                })).filter(f => f.fps > 0).sort((a, b) => b.fps - a.fps);
        r.spawns = Object.keys(_spawns).map(k => ({
                    "at": k,
                    "perMin": Math.round(_spawns[k] / secs * 600) / 10
                })).sort((a, b) => b.perMin - a.perMin);
        stop();
        return JSON.stringify(r);
    }
    Timer {
        id: stopper
        onTriggered: root.stop()
    }
}
