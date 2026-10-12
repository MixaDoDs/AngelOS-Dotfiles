pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// «Что нового» after an update to a big release (Updates.paperShown: the author ticked the paper
// and wrote its lines, owner Dotfiles → «ВАЖНО»): a rolled-up paper comes down a wire from the
// top of the main screen's desktop and sways a little. Pull its handle (drag it down, or click)
// and it unrolls into the list; «Прочитано» rolls it up and the wire takes it away for good
// (Config.updates.paperSeen). Only the paper takes the pointer: the desktop around it stays the
// desktop. `angelos paper` hangs it again.
Item {
    id: root

    property string screenName: ""

    readonly property real u: Theme.u
    readonly property bool wanted: Updates.paperShown && screenName === Shell.primaryName
    property bool leaving: false
    visible: wanted || leaving || drop > 0

    // 0 above the screen … 1 hanging; 0 rolled … 1 open
    property real drop: 0
    property real pull: 0
    Behavior on drop {
        NumberAnimation {
            duration: Motion.still ? 0 : 900
            easing.type: root.leaving ? Easing.InCubic : Easing.OutBack
        }
    }
    Behavior on pull {
        enabled: !handleDrag.active
        NumberAnimation {
            duration: Motion.still ? 0 : 420
            easing.type: Easing.OutCubic
        }
    }
    onWantedChanged: if (wanted) {
        leaving = false;
        drop = 1;
    }
    Component.onCompleted: if (wanted)
        drop = 1
    function putAway() {
        leaving = true;
        pull = 0;
        rollUp.start();
    }
    Timer {
        id: rollUp
        interval: Motion.still ? 0 : 450
        onTriggered: root.drop = 0
    }
    onDropChanged: if (drop === 0 && leaving) {
        leaving = false;
        Updates.putPaperAway();
    }

    readonly property var release: Updates.release
    readonly property color paper: "#f3ead6"
    readonly property color paperShade: "#d9cdb2"
    readonly property color ink: "#3b2f48"
    readonly property color wire: "#2b2433"

    // under the bar when it is on top, in the right third (the angel keeps the bottom corners)
    readonly property real hangTop: BarLayout.edge === "top" ? Theme.barHeight : 0
    readonly property real wireLen: u * 34
    readonly property real paperW: u * 150
    readonly property real rollH: head.implicitHeight + u * 12
    readonly property real sheetH: rollH + list.implicitHeight + u * 10
    readonly property real paperH: rollH + (sheetH - rollH) * pull

    Item {
        id: rig
        x: Math.round(root.width * 0.74)
        y: root.hangTop - (1 - root.drop) * (root.wireLen + root.sheetH + root.u * 40)
        // the hang point is the origin: the whole thing swings from the wire's top
        transform: Rotation {
            id: swing
            angle: 0
        }
        SequentialAnimation {
            running: root.visible && !Motion.calm && !handleDrag.active
            loops: Animation.Infinite
            NumberAnimation {
                target: swing
                property: "angle"
                to: 1.6
                duration: 2300
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: swing
                property: "angle"
                to: -1.6
                duration: 2300
                easing.type: Easing.InOutSine
            }
        }

        // the wire and its clip
        Rectangle {
            x: -root.u
            width: root.u * 2
            height: root.wireLen
            color: root.wire
        }
        Rectangle {
            x: -root.u * 5
            y: root.wireLen - root.u * 2
            width: root.u * 10
            height: root.u * 5
            color: "#8c8496"
            border.width: root.u
            border.color: root.wire
        }

        Item {
            id: sheet
            x: -root.paperW / 2
            y: root.wireLen + root.u * 2
            width: root.paperW
            height: root.paperH

            // a hard pixel shadow, no blur
            Rectangle {
                x: root.u * 3
                y: root.u * 3
                width: parent.width
                height: parent.height
                color: "#000000"
                opacity: 0.28
            }
            Rectangle {
                anchors.fill: parent
                color: root.paper
                border.width: root.u
                border.color: root.paperShade
                clip: true

                Column {
                    id: head
                    x: root.u * 8
                    y: root.u * 7
                    width: parent.width - root.u * 16
                    spacing: root.u
                    PxText {
                        kind: "title"
                        color: root.ink
                        text: I18n.t("Что нового", "What's new")
                    }
                    PxText {
                        kind: "tiny"
                        color: Theme.mix(root.ink, root.paper, 0.35)
                        text: root.release ? "angelOS " + root.release.number + (root.release.codename ? " «" + root.release.codename + "»" : "") : ""
                    }
                }

                Column {
                    id: list
                    x: root.u * 8
                    y: root.rollH
                    width: parent.width - root.u * 16
                    spacing: root.u * 4
                    opacity: root.pull
                    Repeater {
                        model: Updates.paperNotes
                        Row {
                            id: line
                            required property string modelData
                            spacing: root.u * 3
                            Rectangle {
                                y: root.u * 4
                                width: root.u * 3
                                height: root.u * 3
                                color: Theme.accent
                            }
                            PxText {
                                width: list.width - root.u * 6
                                wrapMode: Text.Wrap
                                color: root.ink
                                text: line.modelData
                            }
                        }
                    }
                    PxButton {
                        text: I18n.t("Прочитано", "Got it")
                        icon: "check"
                        compact: true
                        enabled: root.pull > 0.9 && !root.leaving
                        onClicked: root.putAway()
                    }
                }
            }
            // the rolled-up rest of the paper, at its lower edge
            Rectangle {
                y: parent.height - root.u * 3
                x: -root.u * 2
                width: parent.width + root.u * 4
                height: root.u * 6
                color: root.paperShade
                border.width: root.u
                border.color: Theme.mix(root.paperShade, root.ink, 0.4)
            }
            // a click on the rolled paper opens it too
            MouseArea {
                width: parent.width
                height: root.rollH
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pull = root.pull > 0.5 ? 0 : 1
            }

            // the handle on its cord: drag it down to unroll
            Rectangle {
                id: cord
                x: parent.width / 2 - root.u
                y: parent.height + root.u * 3
                width: root.u * 2
                height: root.u * 12
                color: root.wire
            }
            Rectangle {
                id: handle
                x: parent.width / 2 - root.u * 6
                y: cord.y + cord.height
                width: root.u * 12
                height: root.u * 8
                color: Theme.accent
                border.width: root.u
                border.color: root.wire
                Rectangle {
                    anchors.centerIn: parent
                    width: root.u * 4
                    height: root.u * 2
                    color: root.wire
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -root.u * 4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pull = root.pull > 0.5 ? 0 : 1
                }
                DragHandler {
                    id: handleDrag
                    target: null
                    xAxis.enabled: false
                    property real from: 0
                    onActiveChanged: {
                        if (active)
                            from = root.pull;
                        else
                            root.pull = root.pull > 0.3 ? 1 : 0;
                    }
                    onTranslationChanged: if (active)
                        root.pull = Math.max(0, Math.min(1, from + translation.y / Math.max(1, root.sheetH - root.rollH)))
                }
            }
        }
    }
}
