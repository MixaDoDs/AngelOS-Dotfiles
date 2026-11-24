pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services

// skin-morph: switching Classic angelOS ↔ Golden Gate (macOS) is a transformation, not a cut.
//   throw   — Strip ↔ Desktop with angel-niri's desk throw: the windows fly in (to Golden Gate,
//             which is always Desktop) or drop off (back to a Classic Strip) FIRST, in the old
//             skin; only when they have landed does the morph start. Both at once was too much
//             for the VM (the flights + glitches + grim + shader lagged, the shell died).
//   capture — grim grabs every screen in the old skin (the overlay maps meanwhile, empty)
//   hold    — the frozen frames are on screen for a frame
//   settle  — the skin switches underneath; the shell rebuilds its bar / Dock out of sight
//   play    — skin_morph.frag takes the frames away in a wave: top bar, windows and widgets, Dock
// Settings, the setup wizard and `angelos settingsSkin` go through GoldenGate.setSkin, which
// hands the switch here. Other skin changes (windose, stream…) stay plain.
// Each skin has its own arrival: Classic crumbles into pixels, Golden Gate frosts into glass,
// serp — a drop falls over the islands and a ring runs out
// like on water (1.4.0). The windows only move when Golden Gate is one of the two sides.
//   qs -c angelos ipc call skinmorph toggle      Classic ↔ Golden Gate with the effect
//   qs -c angelos ipc call skinmorph to serp     to any of classic | goldengate | serp
//   qs -c angelos ipc call skinmorph slow 10     play ×10 slower (1 = normal) to look at it
//   qs -c angelos ipc call skinmorph sound off   the sound (on | off), volume 0 … 2: `volume 0.8`
// Sounds (to-mac.wav glass bells, to-classic.wav 8-bit power-down) are made by sfx.py.
Scope {
    id: root

    property var plugin
    property string phase: "idle"          // idle | throw | capture | hold | settle | play
    property string target: ""
    property bool toMac: false
    property int mode: 0                   // the arriving skin: 0 classic, 1 goldengate, 2 serp
    readonly property var skins: ["classic", "goldengate", "serp"]
    property real progress: 0
    property int serial: 0                 // cache-buster for the frame files
    property int ready: 0                  // screens whose frame has loaded
    property real slowdown: 1
    readonly property int durationMs: mode === 2 ? 1000 : 850
    readonly property int settleMs: 240
    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    function morph(skin) {
        if (!Config.ready || phase !== "idle" || Quickshell.screens.length === 0)
            return false;
        const from = Config.settingsUi.skin;
        if (skin === from || skins.indexOf(skin) < 0 || skins.indexOf(from) < 0)
            return false;
        target = skin;
        toMac = skin === "goldengate";
        mode = skins.indexOf(skin);
        // Classic ↔ serp: both keep the Config's Strip or Desktop, nothing to throw
        if (skin !== "goldengate" && from !== "goldengate") {
            capture();
            return true;
        }
        // the Strip on the Classic side and the desk throw on: the windows go first
        // with «Each side keeps its windows» (StackMemory): each side's windows come back as they were (Classic's
        // Strip and Golden Gate remember which were minimized, Golden Gate also where they stood)
        const mem = memory();
        if (Niri.nativeMinimize && !Config.windows.floatAll && mem) {
            phase = "throw";
            const on = toMac;
            const started = mem.run(on ? "strip" : "desk", on ? "desk" : "strip", () => Niri.action("SetStackingMode", {
                    "on": on
                }), () => {
                if (root.phase === "throw")
                    root.capture();
            });
            if (!started) {   // a Strip ↔ Desktop switch still under way
                phase = "idle";
                return true;
            }
            return true;
        }
        if (Niri.nativeMinimize && WindowConfig.deskThrow && !Config.windows.floatAll) {
            phase = "throw";
            throwEnd = 0;
            Niri.action("SetStackingMode", {
                "on": toMac
            });
            throwWait.interval = 400;   // no DesksThrown by then: nothing to throw
            throwWait.restart();
            return true;
        }
        capture();
        return true;
    }
    // Settings → Windows → «Each side keeps its windows» (services/StackMemory; Golden Gate is a
    // Desktop side, "desk", like Classic's Desktop)
    function memory() {
        return Config.windows.stackMemory ? StackMemory : null;
    }
    function serpBar() {
        return Serp.barHeight || 40;
    }
    function serpAccent() {
        return Serp.accent;
    }
    function capture() {
        throwWait.stop();
        progress = 0;
        ready = 0;
        serial++;
        phase = "capture";
        timeout.restart();
    }
    // when the last flight is over, ms from now: the last hit (or slide), then the bounce home
    // arriving; leaving, angel-niri puts the windows back ~0.12 s after the last drop — the skin
    // must not switch before (its SetStackingMode off would throw them out again)
    property real throwEnd: 0
    Connections {
        target: Niri
        function onDesksThrown(hits) {
            if (root.phase !== "throw" || !hits.length || root.memory())
                return;
            const last = Math.max(...hits.map(h => h.in_ms || 0));
            const end = Date.now() + last + (root.toMac ? 700 : 500);
            root.throwEnd = Math.min(Date.now() + 6000, Math.max(root.throwEnd, end));
            throwWait.interval = Math.max(1, root.throwEnd - Date.now());
            throwWait.restart();
        }
    }
    Timer {
        id: throwWait
        onTriggered: if (root.phase === "throw") root.capture()
    }
    function frameReady() {
        ready++;
        if (phase === "capture" && ready >= Quickshell.screens.length) {
            timeout.stop();
            phase = "hold";
            hold.restart();
        }
    }
    // no frame (grim failed, busy compositor): switch plainly
    function abort() {
        if (phase === "capture" || phase === "hold")
            Config.settingsUi.skin = target;
        finish();
    }
    function finish() {
        throwWait.stop();
        anim.stop();
        hold.stop();
        settle.stop();
        timeout.stop();
        phase = "idle";
    }

    Component.onCompleted: if ("morphHandler" in GoldenGate) GoldenGate.morphHandler = root
    Component.onDestruction: if ("morphHandler" in GoldenGate && GoldenGate.morphHandler === root) GoldenGate.morphHandler = null

    Timer {
        id: timeout
        interval: 400
        onTriggered: root.abort()
    }
    Timer {
        id: hold
        interval: 30
        onTriggered: {
            Config.settingsUi.skin = root.target;
            root.phase = "settle";
            settle.restart();
        }
    }
    Timer {
        id: settle
        interval: root.settleMs
        onTriggered: {
            root.phase = "play";
            anim.duration = root.durationMs * root.slowdown;
            anim.restart();
            root.chime();
        }
    }
    function chime() {
        if (!plugin || !plugin.get("sound", true) || slowdown !== 1 || Sounds.quietNow())
            return;
        Sounds.playFile(plugin.dir + "/" + ["to-classic.wav", "to-mac.wav", "to-serp.wav"][mode], plugin.get("volume", 0.8));
    }
    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        from: 0
        to: 1
        easing.type: Easing.Linear
        onFinished: root.finish()
    }

    IpcHandler {
        target: "skinmorph"
        function toggle(): string {
            const s = GoldenGate.on ? "classic" : "goldengate";
            if (!root.morph(s))
                Config.settingsUi.skin = s;
            Config.settingsUi.skinChosen = true;
            return s;
        }
        function to(skin: string): string {
            if (!root.morph(skin))
                return "no: " + Config.settingsUi.skin + " → " + skin;
            Config.settingsUi.skinChosen = true;
            return skin;
        }
        function slow(factor: real): string {
            root.slowdown = Math.max(0.2, Math.min(40, factor || 1));
            return "×" + root.slowdown;
        }
        function sound(state: string): string {
            if (state === "on" || state === "off")
                root.plugin.set("sound", state === "on");
            return root.plugin.get("sound", true) ? "on" : "off";
        }
        function volume(v: real): string {
            if (v > 0)
                root.plugin.set("volume", Math.min(2, v));
            return String(root.plugin.get("volume", 0.8));
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win

            required property var modelData
            readonly property string shotPath: root.runDir + "/angelos-skin-morph-" + String(modelData.name).replace(/[^A-Za-z0-9_-]/g, "_") + ".ppm"

            screen: modelData
            visible: root.phase !== "idle" && root.phase !== "throw"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "angelos-skin-morph"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Connections {
                target: root
                function onPhaseChanged() {
                    if (root.phase === "capture") {
                        frame.source = "";
                        grab.running = true;
                    } else if (root.phase === "idle") {
                        frame.source = "";
                        remove.running = true;
                    }
                }
            }
            Process {
                id: grab
                command: ["grim", "-o", win.modelData.name, "-t", "ppm", win.shotPath]
                onExited: code => {
                    if (root.phase !== "capture")
                        return;
                    if (code === 0)
                        frame.source = "file://" + win.shotPath + "?" + root.serial;
                    else
                        root.abort();
                }
            }
            Process {
                id: remove
                command: ["rm", "-f", win.shotPath]
            }

            Image {
                id: frame
                anchors.fill: parent
                visible: false
                asynchronous: false
                cache: false
                smooth: true
                onStatusChanged: {
                    if (status === Image.Ready && root.phase === "capture")
                        root.frameReady();
                    else if (status === Image.Error)
                        root.abort();
                }
            }
            ShaderEffect {
                anchors.fill: parent
                visible: root.phase === "hold" || root.phase === "settle" || root.phase === "play"
                property variant source: frame
                property real progress: root.progress
                property real toMac: root.toMac ? 1 : 0
                property size resolution: Qt.size(width, height)
                property real cell: Math.max(2, Theme.u * 2)
                property real topBand: Math.max(GoldenGate.barHeight, Config.bar.edge === "top" ? Theme.barHeight + Theme.u * 8 : 0) + Theme.u * 4
                property real bottomBand: Math.max(Config.bar.edge === "bottom" ? Theme.barHeight + Theme.u * 8 : 0, Config.mac.dockSize + GoldenGate.px(24))
                property color frost: Theme.dark ? Qt.rgba(0.16, 0.16, 0.18, 1) : Qt.rgba(0.94, 0.94, 0.96, 1)
                property real mode: root.mode
                // serp: the drop falls over the islands' line (the Halo's middle), its sheen in the
                // skin's accent; read at play time, when serp is already up underneath
                property point origin: Qt.point(width / 2, root.serpBar() / 2)
                property color accent: root.serpAccent()
                fragmentShader: Qt.resolvedUrl("skin_morph.frag.qsb")
            }
        }
    }
}
