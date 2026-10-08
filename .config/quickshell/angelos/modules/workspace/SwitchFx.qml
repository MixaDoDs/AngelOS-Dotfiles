pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Workspace transition over one screen (styles with `fx` in WorkspaceAnim):
//   capture — `grim` grabs the old workspace into a private file; the (still empty,
//             transparent) window maps meanwhile, so the frame shows the moment it loads
//   hold    — that frame is shown whole for a frame
//   play    — niri switches instantly underneath and the frozen frame is taken
//             away by shaders/ws_transition.frag, revealing the live new desk.
// The grab is done by grim, not ScreencopyView: in Quickshell 0.3.1 screencopy
// views crash the shell (Qt Wayland screen bookkeeping) on multi-monitor setups.
// Mapped only while it captures and plays (a permanent overlay would block direct scanout of
// fullscreen games); never takes input.
PanelWindow {
    id: win

    required property string screenName
    readonly property var style: WorkspaceAnim.current
    readonly property string shotPath: WorkspaceAnim.runtimeDir + "/switch-" + screenName.replace(/[^A-Za-z0-9_-]/g, "_") + ".ppm"
    property string phase: "idle"          // idle | capture | hold | play
    property string target: ""
    property int dir: 1                    // 1 the switch goes down, -1 up (the shader's `dir`)
    property real progress: 0
    property int serial: 0                 // cache-buster for the frame file

    function start(t, d) {
        if (phase === "capture" || phase === "hold") {
            // still freezing: the newest key press wins
            target = t;
            dir = d;
            return;
        }
        if (phase === "play") {
            // pressed again mid-transition: switch right away under the effect
            WorkspaceAnim.niriAct(t);
            return;
        }
        target = t;
        dir = d;
        progress = 0;
        phase = "capture";
        grab.running = true;
        timeout.restart();
    }
    function captured() {
        if (phase !== "capture")
            return;
        timeout.stop();
        serial++;
        frame.source = "file://" + shotPath + "?" + serial;
    }
    function frameReady() {
        if (phase !== "capture")
            return;
        phase = "hold";
        hold.restart();
    }
    function finish() {
        anim.stop();
        hold.stop();
        timeout.stop();
        phase = "idle";
        frame.source = "";
        remove.running = true;
    }

    Connections {
        target: WorkspaceAnim
        function onCaptureRequested(screen, t, d) {
            if (screen === win.screenName)
                win.start(t, d);
        }
    }

    visible: phase !== "idle"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "angelos-switch-fx"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Process {
        id: grab
        // uncompressed: ~20 ms for a 1080p screen, no cursor
        command: ["grim", "-o", win.screenName, "-t", "ppm", win.shotPath]
        onExited: code => code === 0 ? win.captured() : undefined
    }
    Process {
        id: remove
        command: ["rm", "-f", win.shotPath]
    }
    // no frame in time (grim missing, capture refused, busy compositor): switch plainly
    Timer {
        id: timeout
        interval: 250
        onTriggered: {
            WorkspaceAnim.niriAct(win.target);
            win.finish();
        }
    }
    // the frozen frame has to reach the screen before niri switches under it (the
    // window is already mapped: one frame and a bit)
    Timer {
        id: hold
        interval: 22
        onTriggered: {
            WorkspaceAnim.niriAct(win.target);
            win.phase = "play";
            anim.duration = WorkspaceAnim.fxMs;
            anim.restart();
        }
    }
    NumberAnimation {
        id: anim
        target: win
        property: "progress"
        from: 0
        to: 1
        easing.type: Easing.Linear
        onFinished: win.finish()
    }

    Image {
        id: frame
        anchors.fill: parent
        visible: false
        asynchronous: false
        cache: false
        smooth: false
        onStatusChanged: {
            if (status === Image.Ready)
                win.frameReady();
            else if (status === Image.Error && win.phase === "capture") {
                WorkspaceAnim.niriAct(win.target);
                win.finish();
            }
        }
    }
    ShaderEffect {
        anchors.fill: parent
        visible: win.phase === "hold" || win.phase === "play"
        property variant source: frame
        property real progress: win.progress
        property real mode: win.style.fx === undefined ? 0 : win.style.fx
        property real cell: Theme.u * 8
        property real seed: 0.37
        property size resolution: Qt.size(width, height)
        property color accent: Theme.accent
        property real dir: win.dir
        property real realm: Theme.hell ? 1 : 0
        fragmentShader: Qt.resolvedUrl("../../shaders/ws_transition.frag.qsb")
    }

    RightClickGuard {}
}
