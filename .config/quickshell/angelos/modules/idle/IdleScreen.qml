pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Screensaver: the ASCII art plays one random effect after another
// (reveal → hold → dissolve). Any key, click or mouse movement ends it.
// Config.idle.aod: the other screens (not the main one, not a streamed one) show the
// Always On Display face instead (AodFace): the time, music, notifications, dim and still.
Variants {
    model: Idle.active ? Shell.screens.filter(s => s === Shell.primaryScreen || Config.idle.allScreens || (Config.idle.aod && !StreamMode.onStream(s.name))) : []

    PanelWindow {
        id: win

        required property var modelData
        readonly property bool primary: modelData === Shell.primaryScreen || Shell.screens.length === 1
        readonly property color bg: aod ? "#000000" : Theme.mix(Qt.color("#000000"), Theme.accent, 0.035)
        readonly property bool aod: Config.idle.aod && !primary && !StreamMode.onStream(modelData.name)

        screen: modelData
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: bg
        WlrLayershell.namespace: "angelos-idle"
        WlrLayershell.layer: WlrLayer.Overlay
        // takes input: the screensaver: any key or click ends it
        WlrLayershell.keyboardFocus: primary ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

        // mouse jitter while the surfaces map would end it immediately
        property bool armed: false
        Timer {
            running: true
            interval: 700
            onTriggered: win.armed = true
        }
        function wake() {
            if (armed)
                Idle.stop();
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.BlankCursor
            acceptedButtons: Qt.AllButtons
            property point last: Qt.point(-1, -1)
            onPositionChanged: m => {
                if (Shell.dev)
                    return;   // dev runs sit next to a live session: only clicks end them
                if (last.x >= 0 && Math.abs(m.x - last.x) + Math.abs(m.y - last.y) > 6)
                    win.wake();
                last = Qt.point(m.x, m.y);
            }
            onPressed: win.wake()
            onWheel: win.wake()
        }
        Item {
            focus: true
            Keys.onPressed: e => {
                win.wake();
                e.accepted = true;
            }
            Component.onCompleted: forceActiveFocus()
        }

        AodFace {
            anchors.fill: parent
            visible: win.aod
        }
        // the screensaver itself: not built on an AOD screen (its art and hearts keep moving)
        Loader {
            anchors.fill: parent
            active: !win.aod
            sourceComponent: Component {
                Item {
                    // ---- floating pixel hearts behind the art ----
                    Repeater {
                        model: 14
                        PxIcon {
                            id: heart
                            required property int index
                            property real vy: 0.4 + Math.random() * 0.8
                            name: index % 3 === 0 ? "heartSmall" : index % 3 === 1 ? "heart" : "sparkle"
                            pixel: Theme.u * (1 + index % 3)
                            hollow: index % 2 === 0
                            fill: index % 2 ? Theme.accent : Theme.accent2
                            opacity: 0.18 + (index % 4) * 0.06
                            x: Math.random() * win.width
                            y: Math.random() * win.height
                            Connections {
                                target: art
                                function onTicked() {
                                    heart.y -= heart.vy * Theme.u * 2;
                                    if (heart.y < -heart.height) {
                                        heart.y = win.height + Theme.u * 10;
                                        heart.x = Math.random() * win.width;
                                    }
                                }
                            }
                        }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.u * 12

                    AsciiArt {
                        id: art
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Idle.text
                        maxWidth: win.width * 0.86
                        maxHeight: win.height * 0.6
                        effect: Config.idle.effect
                        palette: Config.idle.colors
                    }

                    Column {
                        visible: Config.idle.clock
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.u * 2
                        SystemClock {
                            id: clock
                            precision: SystemClock.Minutes
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatTime(clock.date, "HH:mm")
                            kind: "big"
                            color: Theme.mix(Theme.text, Theme.accent, 0.3)
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.locale(Config.appearance.language === "en" ? "en_US" : "ru_RU").toString(clock.date, "dddd, d MMMM")
                            kind: "tiny"
                            dim: true
                        }
                    }
                }

                PxText {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: Theme.u * 10
                    text: I18n.t("любая клавиша или мышь — вернуться ♡", "press any key or move the mouse ♡")
                    kind: "tiny"
                    color: Theme.textDim
                    opacity: 0.6
                }
                }
            }
        }

        RightClickGuard {}
    }
}
