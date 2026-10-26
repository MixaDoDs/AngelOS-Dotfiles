pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// angelOS settings in the P5 look: not a window but P5's pause menu — the whole monitor in focus,
// the desktop seen dimmed behind it (the owner, 23.10). A window that opens while it is up (a
// file picker, a program started from it) comes in front: the menu stands aside until that
// window closes. Golden Gate, hell's dresses and the extra Settings windows stay windows
// (SettingsWindow).
// takes input: the whole monitor is the menu, as P5's pause; Esc goes back to the desktop
PanelWindow {
    id: win

    property var nav: Shell
    // the monitor it opened on: the focus moving later doesn't drag it along
    property var shownOn: Shell.focusedScreen
    // the window opened while it was up, the menu standing aside for it; -1: none
    property int awayFor: -1
    // up from opening until it has played its way out (set in the handler, not bound to settingsOpen:
    // a binding dropped the surface for a few frames before the way out could begin)
    property bool up: false
    readonly property bool leaving: up && !nav.settingsOpen

    // P3 Reload's pause: a shot of the screen taken before the menu maps (grim, as SwitchFx: a
    // screencopy view crashes the shell), the menu softens and pixelates it; no shot in time: the
    // live desktop dimmed behind, as before
    property bool grabbing: false
    property string frozen: ""
    readonly property string shotPath: WorkspaceAnim.runtimeDir + "/settings-freeze.ppm"
    property int serial: 0
    function freeze(fresh) {
        if ((win.visible && !fresh) || !win.shownOn)
            return;
        grabbing = true;
        grab.command = ["grim", "-o", win.shownOn.name, "-t", "ppm", shotPath];
        grab.running = true;
        grabLate.restart();
    }
    // made lazily as it opens (LazyWindows): the open that made it
    Component.onCompleted: if (nav.settingsOpen) {
        freeze(true);
        up = true;
    }
    Process {
        id: grab
        onExited: code => {
            if (!win.grabbing)
                return;
            grabLate.stop();
            win.frozen = code === 0 ? "file://" + win.shotPath + "?" + (++win.serial) : "";
            win.grabbing = false;
        }
    }
    Timer {
        id: grabLate
        interval: 200
        onTriggered: {
            win.frozen = "";
            win.grabbing = false;
        }
    }
    Process {
        id: unshot
        command: ["rm", "-f", win.shotPath]
    }

    screen: shownOn
    visible: up && awayFor < 0 && !grabbing
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    // the polkit dialog (newer overlay) gets the keys while it asks — #122/#123
    WlrLayershell.keyboardFocus: visible && !Shell.polkitAsking ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    Connections {
        target: win.nav
        function onSettingsOpenChanged() {
            if (win.nav.settingsOpen) {
                if (!win.visible)
                    win.shownOn = Shell.focusedScreen;
                win.freeze();
                win.up = true;
            } else {
                if (win.awayFor >= 0) {
                    win.up = false;
                    win.frozen = "";
                    unshot.running = true;
                }
                win.awayFor = -1;
            }
        }
    }
    Connections {
        target: Niri
        function onWindowOpened(id) {
            if (win.nav.settingsOpen && win.awayFor < 0)
                win.awayFor = id;
        }
        function onWindowClosed(id) {
            if (id === win.awayFor) {
                win.freeze();
                win.awayFor = -1;
            }
        }
    }

    SettingsView {
        anchors.fill: parent
        settingsNav: win.nav
        overDesk: true
        leaving: win.leaving
        frozen: win.frozen
        onGoneOut: {
            win.up = false;
            win.frozen = "";
            unshot.running = true;
        }
    }

    RightClickGuard {}
}
