pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Workspace switch transitions.
//   soft, dash, spring, snap — niri's own workspace-switch animation (cfg/animation.kdl)
//   dissolve … crt           — angelOS: the old screen is captured, niri switches
//                              instantly underneath, and the frozen frame is taken
//                              away by shaders/ws_transition.frag (modules/workspace/SwitchFx),
//                              following the direction of the switch (up / down).
// For every animated style the workspace keys (Mod+1…9, Mod+wheel, Mod+O) go
// through `angelos ws …` → the control socket here (captured styles grab the
// screen first; niri's own slides first swap the desktop widgets for their
// pinned pictures, DesktopWidgets.prepareSwitch); scripts/workspace-anim.py
// rewrites those binds and back, and niri falls back to itself if the shell is
// not running.
Singleton {
    id: root

    // `fx` is the shader's mode (shaders/ws_transition.frag), `ms` its length at speed 1
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
            "id": "spring",
            "niri": "spring",
            "label": I18n.t("Пружина", "Spring"),
            "hint": I18n.t("пружинная физика niri: чуть перелетает и возвращается", "niri's spring physics: overshoots a touch and settles back")
        },
        {
            "id": "snap",
            "niri": "snap",
            "label": I18n.t("Щелчок", "Snap"),
            "hint": I18n.t("очень быстрый сдвиг с резким торможением", "a very quick slide with a sharp stop")
        },
        {
            "id": "zoom",
            "niri": "instant",
            "fx": 1,
            "ms": 280,
            "label": I18n.t("Наплыв", "Zoom"),
            "hint": I18n.t("старый стол чуть приближается, мутнеет и тает — проходишь сквозь него", "the old desk grows a little, blurs and melts away, you walk through it")
        },
        {
            "id": "card",
            "niri": "instant",
            "fx": 2,
            "ms": 380,
            "label": I18n.t("Карточка", "Card"),
            "hint": I18n.t("старый стол сжимается в карточку с тенью и улетает вверх или вниз", "the old desk shrinks into a card with a shadow and flies off up or down")
        },
        {
            "id": "wipe",
            "niri": "instant",
            "fx": 3,
            "ms": 320,
            "label": I18n.t("Шторка", "Wipe"),
            "hint": I18n.t("мягкий край с линией акцента проезжает по экрану в сторону переключения", "a soft edge with an accent line sweeps across in the direction of the switch")
        },
        {
            "id": "fade",
            "niri": "instant",
            "fx": 4,
            "ms": 170,
            "label": I18n.t("Растворение", "Fade"),
            "hint": I18n.t("быстрый кроссфейд, ничего лишнего", "a quick crossfade, nothing more")
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
            "id": "realm",
            "niri": "instant",
            "fx": 5,
            "ms": 560,
            "label": I18n.t("Рай / Ад", "Heaven / Hell"),
            "hint": Theme.hell ? I18n.t("в аду старый стол прогорает от краёв, кромка тлеет углями", "in hell the old desk burns away from the edges on a smouldering rim") : I18n.t("в раю старый стол засвечивается и рассеивается светом; в аду — прогорает", "in heaven the old desk overexposes and scatters into light; in hell it burns away")
        },
        {
            "id": "glitch",
            "niri": "instant",
            "fx": 6,
            "ms": 240,
            "label": I18n.t("Глитч", "Glitch"),
            "hint": I18n.t("RGB-сдвиг и рваные срезы, уползающие по направлению", "an RGB split and torn slices that slip away in the direction")
        },
        {
            "id": "crt",
            "niri": "instant",
            "fx": 7,
            "ms": 380,
            "label": I18n.t("ЭЛТ", "CRT"),
            "hint": I18n.t("старый стол гаснет как кинескоп: в линию, в точку — и новый включается", "the old desk switches off like a tube: to a line, to a dot, and the new one comes on")
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
            "teleport": "glitch",
            "ender": "glitch",
            "heart": "zoom",
            "pixel": "dissolve"
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
    readonly property int slideMs: niriMs > 0 ? niriMs : Math.round((({
                    "dash": 460,
                    "spring": 520,
                    "snap": 170
                })[niriPreset] || 380) / speed)
    // the captured effect's length (SwitchFx)
    readonly property int fxMs: Math.round((current.ms || 500) / speed)
    property bool routed: false          // workspace keys go through `angelos ws`
    property string log: ""
    readonly property bool busy: writer.running
    // SwitchFx of that screen captures, then calls niriAct(target); dir: 1 down (the new
    // desk comes from below, like niri's slide), -1 up
    signal captureRequested(string screen, string target, int dir)

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
        // which way the switch goes: numbers by their place, "prev" as if down
        let dir = target === "up" ? -1 : 1;
        if (/^[0-9]+$/.test(target)) {
            const to = list[parseInt(target) - 1];
            dir = to && to.idx < idx ? -1 : 1;
        }
        captureRequested(out, target, dir);
    }
    // plays the current transition over a screen without switching (settings preview)
    function preview(screen) {
        if (captured)
            captureRequested(screen || Niri.focusedOutput, "", 1);
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
