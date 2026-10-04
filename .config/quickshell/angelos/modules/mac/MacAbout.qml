pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// "About <App>" for apps with no About of their own (the app menu, AppMenu.aboutApp): a small
// glass panel in the middle of the focused screen with the app's icon, its name, what it is (its
// .desktop file) and its version — the package that owns the app's program, asked from pacman.
// Esc, OK or a click outside close it.
PanelWindow {
    id: win

    required property var modelData
    readonly property var app: AppMenu.aboutApp
    readonly property bool open: !!app && Shell.focusedScreen === modelData
    property string version: ""

    screen: modelData
    visible: open
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-macabout"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // takes input: the whole screen while it shows (a click outside closes it)
    BackgroundEffect.blurRegion: Config.appearance.blur && open ? blurRegion : null
    Region {
        id: blurRegion
        item: card
        radius: GoldenGate.panelRadius
    }

    onAppChanged: {
        version = "";
        if (app && app.pid) {
            // the program behind the window → its package and version (pacman -Qo)
            probe.command = ["sh", "-c", 'exe=$(readlink -f "/proc/$1/exe" 2>/dev/null) && [ -n "$exe" ] && pacman -Qo "$exe" 2>/dev/null | sed -E "s/.* is owned by //"', "sh", String(app.pid)];
            probe.running = true;
        }
    }
    Process {
        id: probe
        stdout: StdioCollector {
            onStreamFinished: win.version = text.trim()
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: AppMenu.aboutApp = null
    }
    MacGlass {
        id: card
        width: GoldenGate.px(300)
        height: col.implicitHeight + GoldenGate.px(40)
        anchors.centerIn: parent
        radius: GoldenGate.panelRadius
        fill: GoldenGate.glass(0.25)
        focus: win.open
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                AppMenu.aboutApp = null;
                e.accepted = true;
            }
        }
        MouseArea {
            anchors.fill: parent
        }
        Column {
            id: col
            width: parent.width - GoldenGate.px(40)
            anchors.centerIn: parent
            spacing: GoldenGate.px(6)
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: GoldenGate.px(80)
                height: width
                sourceSize: Qt.size(width * 2, height * 2)
                smooth: true
                source: {
                    const i = win.app ? String(win.app.icon || win.app.id || "") : "";
                    return !i ? "" : i.startsWith("/") ? "file://" + i : Quickshell.iconPath(i, true) || Quickshell.iconPath("application-x-executable", true);
                }
            }
            Item {
                width: 1
                height: GoldenGate.px(4)
            }
            MacText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: win.app ? win.app.name : ""
                size: GoldenGate.px(17)
                bold: true
            }
            MacText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: win.version ? I18n.t("Версия ", "Version ") + win.version : win.app ? win.app.id : ""
                size: GoldenGate.smallSize
                color: GoldenGate.secondaryLabel
            }
            MacText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: text !== ""
                text: win.app ? win.app.comment : ""
                wrapMode: Text.Wrap
                maximumLineCount: 3
                size: GoldenGate.smallSize + GoldenGate.px(1)
            }
            Item {
                width: 1
                height: GoldenGate.px(8)
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: GoldenGate.px(90)
                height: GoldenGate.px(26)
                radius: height / 2
                color: GoldenGate.accent
                MacText {
                    anchors.centerIn: parent
                    text: "OK"
                    color: "#ffffff"
                    semibold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: AppMenu.aboutApp = null
                }
            }
        }
    }

    RightClickGuard {}
}
