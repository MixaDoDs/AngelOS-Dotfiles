pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Y2K loading screen, like a CD-ROM game from 2000: spinning disc, "insert
// disc 1", a chunky progress bar and the startup chime. Once per login (a
// marker in $XDG_RUNTIME_DIR, so crash restarts and `angelos restart` skip it),
// on the screens picked in Settings → Y2K. A click skips it.
// The login starts black: a cover goes up with the shell's very first windows and holds a
// second (the desktop loads under it, the sound player starts), then the show plays in the
// same window — the desktop is never seen before it. The marker used to be checked by a
// process whose answer came ~0.7 s after the desktop was drawn (2026-10-08).
Scope {
    id: root

    property real p: 0                       // 0..1 through the show
    readonly property int step: Math.floor(p * 36)   // stepped, like the old installers
    // ANGELOS_DEV_BOOT=1: a dev instance does it too
    readonly property bool allowed: !Shell.dev || Quickshell.env("ANGELOS_DEV_BOOT") === "1"

    function maybeStart() {
        if (!Shell.bootCover || cover.running || !Config.ready)
            return;
        if (Config.y2k.boot && !Motion.still)
            Shell.bootOpen = true;           // the same windows: no gap between the black and the show
        Shell.bootCover = false;
    }
    function finish() {
        run.stop();
        cover.stop();
        Shell.bootCover = false;
        Shell.bootOpen = false;
    }

    // the first start of this login, known at once (a blocking read, no process)
    FileView {
        id: marker
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos-booted"
        blockLoading: true
        blockWrites: true
        printErrors: false
    }
    Component.onCompleted: {
        if (!allowed)
            return;
        marker.text();                       // the read happens here: `loaded` says it is there
        if (marker.loaded)
            return;
        marker.setText("1\n");
        Shell.bootCover = true;
        cover.start();
    }
    // a second of black from its first frame (or 2.5 s from the start if no frame ever comes)
    Timer {
        id: cover
        interval: 2500
        onTriggered: root.maybeStart()
    }
    Connections {
        target: Shell
        function onBootCoverShownChanged() {
            if (Shell.bootCoverShown && Shell.bootCover) {
                cover.interval = 1000;
                cover.restart();
            }
        }
    }
    Connections {
        target: Config
        function onReadyChanged() {
            // the show is off: the black goes as soon as the settings say so
            if (Config.ready && Shell.bootCover && (!Config.y2k.boot || Motion.still))
                root.finish();
            root.maybeStart();
        }
    }
    Connections {
        target: Shell
        function onBootOpenChanged() {
            if (!Shell.bootOpen)
                return;
            root.p = 0;
            run.restart();                   // its chime: Sounds.playBoot
        }
    }
    NumberAnimation {
        id: run
        target: root
        property: "p"
        from: 0
        to: 1
        duration: Motion.ms(3400)
        onFinished: root.finish()
    }

    Variants {
        // before the settings are read every screen is covered (at login nothing streams yet)
        model: Shell.bootOpen || Shell.bootCover ? (Config.ready ? Shell.bootScreens : Shell.screens) : []

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Shell.bootOpen ? "#0c0710" : "#000000"
            WlrLayershell.layer: WlrLayer.Overlay
            // takes input: the boot screen: a click skips it
            WlrLayershell.namespace: "angelos-boot"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // the first frame out: the desktop may come up under it
            Connections {
                target: Shell.bootCoverShown ? null : coverProbe.Window.window
                function onFrameSwapped() {
                    Shell.bootCoverShown = true;
                }
            }
            Item {
                id: coverProbe
            }

            // fade out at the very end
            Item {
                anchors.fill: parent
                visible: Shell.bootOpen
                opacity: root.p < 0.9 ? 1 : Math.max(0, 1 - (root.p - 0.9) * 10)

                // CRT scanlines
                Image {
                    anchors.fill: parent
                    fillMode: Image.Tile
                    smooth: false
                    opacity: 0.35
                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='4' height='" + Theme.u * 3 + "'><rect width='4' height='" + Theme.u + "' fill='black'/></svg>"
                }
                // glow behind the disc
                Rectangle {
                    anchors.centerIn: disc
                    width: disc.width * 1.9
                    height: width
                    radius: width / 2
                    color: Qt.alpha(Theme.accent, 0.12)
                }

                // the spinning CD
                Item {
                    id: disc
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.verticalCenter
                    anchors.bottomMargin: Theme.u * 10
                    width: Math.round(Math.min(win.width, win.height) * 0.22)
                    height: width
                    rotation: root.step * 40
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "#d9d6e4"
                        border.width: Theme.u
                        border.color: Theme.edge
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: "#cfd8ee"
                            }
                            GradientStop {
                                position: 0.35
                                color: Theme.mix(Theme.accent, "#ffffff", 0.35)
                            }
                            GradientStop {
                                position: 0.5
                                color: "#fff6c9"
                            }
                            GradientStop {
                                position: 0.65
                                color: Theme.mix(Theme.accent2, "#ffffff", 0.3)
                            }
                            GradientStop {
                                position: 1.0
                                color: "#d8d0ee"
                            }
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.34
                        height: width
                        radius: width / 2
                        color: "#b8b3c8"
                        border.width: Theme.u
                        border.color: Theme.edge
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.12
                        height: width
                        radius: width / 2
                        color: "#0c0710"
                    }
                    PxIcon {
                        x: parent.width * 0.62
                        y: parent.height * 0.18
                        name: "heart"
                        pixel: Theme.u
                    }
                }

                Column {
                    anchors.top: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.u * 6
                    width: Math.min(win.width * 0.7, Theme.u * 300)

                    AngelLogo {
                        anchors.horizontalCenter: parent.horizontalCenter
                        pixel: Theme.u * 3
                        fontSize: Math.round(Theme.sizeHuge * 1.6)
                    }
                    PxText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#ffffff"
                        kind: "big"
                        text: root.p < 0.22 ? I18n.t("Вставьте диск 1…", "Please insert disc 1…") : root.p < 0.85 ? I18n.t("Читаю диск ANGEL (D:)…", "Reading disc ANGEL (D:)…") : I18n.t("Готово ♡", "Ready ♡")
                    }
                    // chunky progress bar
                    Rectangle {
                        width: parent.width
                        height: Theme.u * 16
                        color: "#1c1222"
                        border.width: Theme.u
                        border.color: "#d9d6e4"
                        Row {
                            x: Theme.u * 3
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.u * 2
                            Repeater {
                                model: 20
                                Rectangle {
                                    required property int index
                                    width: (parent.parent.width - Theme.u * 6 - 19 * Theme.u * 2) / 20
                                    height: Theme.u * 10
                                    visible: index < Math.floor(Math.max(0, root.p - 0.22) / 0.63 * 20)
                                    color: index % 2 ? Theme.accent : Theme.mix(Theme.accent, "#ffffff", 0.35)
                                }
                            }
                        }
                    }
                    PxText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#b8b3c8"
                        kind: "body"
                        text: Math.min(100, Math.round(Math.max(0, root.p - 0.22) / 0.63 * 100)) + "%  ·  " + I18n.t("клик — пропустить", "click to skip")
                    }
                }
                PxText {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.u * 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#6f6680"
                    kind: "tiny"
                    text: "© 2000 angelOS ♡ best viewed in 800×600"
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.finish()
            }
            RightClickGuard {}
        }
    }
}
