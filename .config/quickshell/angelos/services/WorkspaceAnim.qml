pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Workspace switch transitions.
//   soft, dash         — niri's own workspace-switch animation (bezier curves)
//   dissolve/heart/ender — angelOS: the old screen is captured, niri switches
//                        instantly underneath, and the frozen frame is taken away
//                        by shaders/ws_transition.frag (modules/workspace/SwitchFx).
// For every animated style the workspace keys (Mod+1…9, Mod+wheel, Mod+O) go
// through `angelos ws …` → the control socket here (captured styles grab the
// screen first; niri's own slides first swap the desktop widgets for their
// pinned pictures, DesktopWidgets.prepareSwitch); scripts/workspace-anim.py
// rewrites those binds and back, and niri falls back to itself if the shell is
// not running.
Singleton {
    id: root

    readonly property var styles: [
        {
            "id": "soft",
            "niri": "soft",
            "label": I18n.t("Мягкий", "Soft"),
            "hint": I18n.t("плавно разгоняется и мягко тормозит, без отскока", "eases in and settles softly, no overshoot")
        },
        {
            "id": "dash",
            "niri": "dash",
            "label": I18n.t("Рывок", "Dash"),
            "hint": I18n.t("медленный старт, рывок и аккуратная остановка", "a slow start, a dash and a tidy stop")
        },
        {
            "id": "dissolve",
            "niri": "instant",
            "fx": 0,
            "ms": 480,
            "label": I18n.t("Пиксели", "Pixels"),
            "hint": I18n.t("старый стол рассыпается пиксельными блоками", "the old desk crumbles into pixel blocks")
        },
        {
            "id": "heart",
            "niri": "instant",
            "fx": 1,
            "ms": 620,
            // the shape follows the desk sprite (Config.workspaces.sprite)
            "label": ({
                    "star": I18n.t("Звезда ✦", "Star ✦"),
                    "cd": I18n.t("CD-диск", "CD")
                })[Config.workspaces.sprite] || I18n.t("Сердечко", "Heart"),
            "hint": ({
                    "star": I18n.t("новый стол открывается сквозь растущую звезду-блёстку", "the new desk opens through a growing sparkle star"),
                    "cd": I18n.t("новый стол открывается растущим радужным диском с дыркой посередине", "the new desk opens as a growing rainbow disc with a hole in the middle")
                })[Config.workspaces.sprite] || I18n.t("новый стол открывается сквозь растущее сердце", "the new desk opens through a growing heart")
        },
        {
            "id": "ender",
            "niri": "instant",
            "fx": 2,
            "ms": 720,
            "label": I18n.t("Телепорт", "Teleport"),
            "hint": I18n.t("экран распадается на фиолетовые частицы эндермена", "the screen breaks into purple enderman particles")
        },
        {
            "id": "instant",
            "niri": "instant",
            "label": I18n.t("Мгновенно", "Instant"),
            "hint": I18n.t("без анимации", "no animation")
        }
    ]
    // styles of earlier versions
    readonly property var legacy: ({
            "slide": "dash",
            "bounce": "soft",
            "teleport": "ender",
            "pixel": "dissolve",
            "glitch": "dissolve"
        })
    readonly property var current: styles.find(s => s.id === (legacy[Config.workspaces.switchFx] || Config.workspaces.switchFx)) || styles[0]
    readonly property bool captured: current.fx !== undefined
    // the workspace keys go through `angelos ws` for every animated style: the
    // captured ones grab the screen first, niri's own slides first put the
    // desktop widgets' pictures up (DesktopWidgets.prepareSwitch)
    function wantsRoute(s) {
        return s.id !== "instant";
    }
    property string niriPreset: ""       // what cfg/animation.kdl has now
    property real slowdown: 1            // animations { slowdown } in cfg/animation.kdl
    property real niriSpeed: 1           // the speed that file was written with
    property int niriMs: 0               // its workspace-switch duration-ms
    // Settings → Workspaces → Switch speed (×): niri's slides and the captured effects
    readonly property real speed: Math.max(0.25, Math.min(4, Config.workspaces.switchSpeed > 0 ? Config.workspaces.switchSpeed : 1))
    readonly property int slideMs: niriMs > 0 ? niriMs : Math.round((niriPreset === "dash" ? 460 : 380) / speed)
    // the captured effect's length (SwitchFx)
    readonly property int fxMs: Math.round((current.ms || 500) / speed)
    // 0 heart, 1 star, 2 CD: the "Heart" transition's shape (shaders/ws_transition.frag)
    readonly property int shape: ({
            "star": 1,
            "cd": 2
        })[Config.workspaces.sprite] || 0
    property bool routed: false          // workspace keys go through `angelos ws`
    property string log: ""
    readonly property bool busy: writer.running
    // SwitchFx of that screen captures, then calls niriAct(target)
    signal captureRequested(string screen, string target)

    function pick(id) {
        const s = styles.find(x => x.id === id);
        if (!s)
            return;
        Config.workspaces.switchFx = id;
        const route = wantsRoute(s);
        if (s.niri === niriPreset && route === routed && speedSynced(s))
            return;
        if (Shell.dev) {
            log = I18n.t("В dev-режиме конфиг niri не изменяется", "Dev mode does not modify niri");
            return;
        }
        write(s, route);
    }
    function write(s, route) {
        writer.command = ["python3", Quickshell.shellDir + "/scripts/workspace-anim.py", s.niri, route ? "--route" : "--native", "--speed", String(speed)];
        writer.running = true;
    }
    // niri's own slide already runs at the chosen speed (instant has none)
    function speedSynced(s) {
        return s.niri === "instant" || Math.abs(niriSpeed - speed) < 0.02;
    }
    // Settings → Switch speed (also undo / "Reset this page"): niri's slide is
    // rewritten once the value settles
    onSpeedChanged: if (readDone)
        speedWrite.restart()
    Timer {
        id: speedWrite
        interval: 400
        onTriggered: {
            if (!root.speedSynced(root.current) && !Shell.dev) {
                if (writer.running)
                    restart();
                else
                    root.write(root.current, root.wantsRoute(root.current));
            }
        }
    }
    // the keys of earlier versions went straight to niri for its own slides
    property bool readDone: false
    property bool routeSynced: false     // once per start: a failed write must not loop
    function syncRoute() {
        readDone = true;
        if (Config.ready && !routeSynced && (routed !== wantsRoute(current) || !speedSynced(current)) && current.niri === niriPreset) {
            routeSynced = true;
            reapply();
        }
    }
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready && root.readDone)
                root.syncRoute();
        }
    }
    function refresh() {
        if (!reader.running)
            reader.running = true;
    }
    // after an update the installer may bring back default binds: write the chosen style again
    function reapply() {
        if (Shell.dev || writer.running)
            return;
        write(current, wantsRoute(current));
    }

    // ---- switching ----
    // target: a workspace number, "up", "down" or "prev"
    function go(target) {
        target = String(target);
        if (!/^([0-9]{1,2}|up|down|prev)$/.test(target))
            return;
        const out = Niri.focusedOutput;
        const screen = Shell.screenByName(out);
        const list = Niri.workspacesOn(out);
        const active = list.find(w => w.is_active);
        const idx = active ? active.idx : -1;
        // nothing would change: no transition
        const same = /^[0-9]+$/.test(target) ? !!list[parseInt(target) - 1] && list[parseInt(target) - 1].is_active : target === "up" ? idx <= (list[0] ? list[0].idx : 1) : target === "down" ? idx >= (list.length ? list[list.length - 1].idx : 1) : false;
        // leaving a fullscreen game or video: switch plainly, no grab of the game
        const plain = !screen || same || Idle.active || Shell.locked || MetaTap.coversOutput(Niri.focusedWindow);
        if (!captured || Motion.still) {
            // niri slides: the desktop widgets' pictures go up before it moves (motion off:
            // niri's animations are off too, it just switches)
            if (plain || current.id === "instant" || Shell.fullscreenOn(out) || Motion.still)
                niriAct(target);
            else
                DesktopWidgets.prepareSwitch(out, () => root.niriAct(target));
            return;
        }
        if (plain) {
            niriAct(target);
            return;
        }
        captureRequested(out, target);
    }
    // plays the current transition over a screen without switching (settings preview)
    function preview(screen) {
        if (captured)
            captureRequested(screen || Niri.focusedOutput, "");
    }
    // up, down and numbers count the desktops the shell shows: the workspace that holds the
    // minimized windows (services/Minimize) is stepped over, not even passed through for a frame
    function niriAct(target) {
        if (!target)
            return;
        const out = Niri.focusedOutput;
        const list = Niri.workspacesOn(out);
        const active = list.find(w => w.is_active) || Niri.workspaceById(Minimize.lastDesk[out]);
        const i = active ? list.findIndex(w => w.id === active.id) : -1;
        let to = null;
        if (/^[0-9]+$/.test(target))
            to = list[parseInt(target) - 1] || null;
        else if (target === "up" && i >= 0)
            to = list[i - 1] || null;
        else if (target === "down" && i >= 0)
            to = list[i + 1] || null;
        if (to) {
            Niri.focusWorkspace(to.id);
            return;
        }
        if (/^[0-9]+$/.test(target))
            Niri.action("FocusWorkspace", {
                "reference": {
                    "Index": parseInt(target)
                }
            });
        else if (target === "prev" || i < 0)
            Niri.action(({
                    "up": "FocusWorkspaceUp",
                    "down": "FocusWorkspaceDown",
                    "prev": "FocusWorkspacePrevious"
                })[target], {});
    }

    // `angelos ws …` (and `angelos alttab …`) from the niri keybinds land here (a few ms instead of `qs ipc`)
    readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos"
    readonly property string socketPath: runtimeDir + (Shell.dev ? "/ctl-dev.sock" : "/ctl.sock")
    property bool socketReady: false
    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "$1" && chmod 700 "$1" && rm -f "$2"', "sh", root.runtimeDir, root.socketPath]
        onExited: code => root.socketReady = code === 0
    }
    SocketServer {
        active: root.socketReady
        path: root.socketPath
        handler: Socket {
            id: client
            parser: SplitParser {
                onRead: line => {
                    const m = line.trim().match(/^ws ([0-9]{1,2}|up|down|prev)$/);
                    // Alt+Tab shares the socket (services/AltTab): one hop instead of `qs ipc`
                    // (and ⌘Tab / ⌘` of the Golden Gate skin's Mac keys: apps, appsback, appwin, appwinback)
                    const a = line.trim().match(/^alttab (next|prev|cancel|apps|appsback|appwin|appwinback)$/);
                    // the lens at the pointer, too (services/Lens)
                    const l = line.trim().match(/^lens (in|out|close|toggle|refresh)$/);
                    if (l) {
                        client.write("ok\n");
                        client.flush();
                        Lens.cmd(l[1], "");
                        return;
                    }
                    const mac = !!a && /^app/.test(a[1]);
                    const ok = !!m || !!a && (AltTab.ours || mac);
                    client.write(ok ? "ok\n" : "err\n");
                    client.flush();
                    if (m)
                        root.go(m[1]);
                    else if (ok && a[1] === "cancel")
                        AltTab.cancel();
                    else if (ok && /^appwin/.test(a[1]))
                        AltTab.cycleAppWindows(a[1] === "appwinback" ? -1 : 1);
                    else if (ok && mac)
                        AltTab.stepApps(a[1] === "appsback" ? -1 : 1);
                    else if (ok)
                        AltTab.step(a[1] === "prev" ? -1 : 1);
                }
            }
        }
    }

    Process {
        id: reader
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/workspace-anim.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.niriPreset = r.preset || "";
                    root.niriSpeed = r.speed > 0 ? r.speed : 1;
                    root.niriMs = r.ms > 0 ? r.ms : 0;
                    root.routed = !!r.routed;
                    root.slowdown = r.slowdown > 0 ? r.slowdown : 1;
                    // one-time move from the old style names
                    if (root.legacy[Config.workspaces.switchFx])
                        Qt.callLater(() => root.pick(root.legacy[Config.workspaces.switchFx]));
                    else
                        root.syncRoute();
                } catch (e) {}
            }
        }
    }
    Process {
        id: writer
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.log = r.error ? I18n.t("niri: ", "niri: ") + r.error : "";
                } catch (e) {
                    root.log = text.trim();
                }
            }
        }
        onExited: root.refresh()
    }
}
