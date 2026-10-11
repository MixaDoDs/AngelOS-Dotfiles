pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import "../../widgets/Place.js" as Place

// VoxType dictation indicator in the angelOS style ("voice.exe").
Scope {
    id: root

    readonly property string stateFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/voxtype/state"
    property string state: "idle"
    readonly property bool recording: state === "recording" || state === "listening"
    readonly property bool working: state === "transcribing" || state === "processing" || state === "busy"
    readonly property bool shown: Config.voxtype.indicator === "angelos" && (recording || working)
    property bool hasVoxtype: false

    // voxtype rewrites the file on every change: the watch follows it through the renames and a
    // file made again (it polled every 150 ms before — 7 wake-ups a second for nothing); while the
    // file is not there yet (voxtype not started) a slow look every 3 s finds it
    readonly property bool watching: hasVoxtype && Config.voxtype.indicator === "angelos"
    property bool fileThere: false
    Timer {
        interval: 3000
        running: root.watching && !root.fileThere
        repeat: true
        onTriggered: stateView.reload()
    }
    FileView {
        id: stateView
        path: root.watching ? root.stateFile : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.fileThere = true;
            root.state = text().trim() || "idle";
        }
        onLoadFailed: {
            root.fileThere = false;
            root.state = "idle";
        }
    }
    Process {
        running: true
        command: ["sh", "-c", "command -v voxtype || test -x \"$HOME/.local/bin/voxtype\""]
        onExited: code => root.hasVoxtype = code === 0
    }

    // the old GTK indicator steps aside while ours is in charge (and comes back when chosen)
    function syncClassic() {
        if (Shell.dev || !hasVoxtype)
            return;
        Quickshell.execDetached(["systemctl", "--user", Config.voxtype.indicator === "classic" ? "start" : "stop", "voxtype-indicator.service"]);
    }
    onHasVoxtypeChanged: syncClassic()
    Connections {
        target: Config.voxtype
        function onIndicatorChanged() {
            root.syncClassic();
        }
    }

    PanelWindow {
        id: win

        readonly property string pos: Config.voxtype.position || "bottom-center"
        screen: Shell.focusedScreen
        visible: root.shown || fade.running
        anchors.top: Place.top(pos)
        anchors.bottom: Place.bottom(pos)
        anchors.left: Place.left(pos)
        anchors.right: Place.right(pos)
        margins.top: Theme.u * 8
        margins.bottom: Theme.u * 8
        margins.left: Theme.u * 8
        margins.right: Theme.u * 8
        implicitWidth: frame.width + Theme.u * 3
        implicitHeight: frame.height + Theme.u * 3
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "angelos-voxtype"
        WlrLayershell.layer: WlrLayer.Overlay

        BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
        Region {
            id: blurRegion
            item: frame
        }

        PxWindow {
            id: frame
            width: Theme.u * 110
            height: titleHeight + Theme.u * 34
            title: I18n.exe("voice")
            icon: "mic"
            compact: true
            closable: false
            decor: false
            opacity: root.shown ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    id: fade
                    duration: Motion.ms(Theme.fast)
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: Theme.u * 6

                PxIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "mic"
                    pixel: Theme.u * 2
                    fill: root.recording ? Theme.danger : Theme.accent2
                    SequentialAnimation on opacity {
                        running: root.recording && !Motion.still
                        alwaysRunToEnd: true
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.55
                            duration: Motion.ms(700)
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1
                            duration: Motion.ms(700)
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.u * 2
                    PxText {
                        text: root.recording ? I18n.t("Слушаю…", "Listening…") : I18n.t("Распознаю…", "Transcribing…")
                        font.bold: true
                        color: root.recording ? Theme.text : Theme.accent2
                    }

                    // pixel level bars while recording, running dots while transcribing
                    Row {
                        id: bars
                        spacing: Theme.u
                        property int tick: 0
                        Timer {
                            interval: 90
                            running: root.shown
                            repeat: true
                            onTriggered: bars.tick++
                        }
                        Repeater {
                            model: 12
                            Item {
                                required property int index
                                width: Theme.u * 3
                                height: Theme.u * 10
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    // deterministic wobble: cheap and looks like a voice
                                    height: root.recording ? Theme.u * Math.max(1, Math.round(2 + 8 * Math.abs(Math.sin(bars.tick * 0.55 + index * 1.7) * Math.cos(bars.tick * 0.23 + index)))) : (Math.floor(bars.tick / 2) % 12 === index ? Theme.u * 6 : Theme.u * 2)
                                    color: root.recording ? (index % 3 === 0 ? Theme.accent2 : Theme.accent) : Theme.accent2
                                }
                            }
                        }
                    }
                }
            }
        }

        RightClickGuard {}
    }
}
