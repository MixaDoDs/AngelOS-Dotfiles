pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The shake's quick-time event (services/Cobweb.qte) over the window it is about: "shake the web
// off!", the arrows to swipe (done ones dim, the current one big and bouncing), a bar of the
// time left for it, three hearts for the misses. Swipes: the mouse (press and fling, over the
// window) or the arrow keys / WASD; Esc lets it go. Then "Clean! ✦" or "It holds on…".
PxBox {
    id: root

    property var q: Cobweb.qte
    readonly property bool live: !!q && q.phase === "run"
    readonly property real stepMs: Cobweb.qteStepMs
    property real timeLeft: 1                 // share of the current arrow's time left

    width: Math.max(col.implicitWidth, Theme.u * 120) + Theme.u * 16
    height: col.implicitHeight + Theme.u * 14
    shadow: true

    Timer {
        interval: 40
        repeat: true
        running: root.live
        onTriggered: root.timeLeft = Math.max(0, Math.min(1, (root.q.deadline - Date.now()) / root.stepMs))
    }

    Column {
        id: col
        anchors.centerIn: parent
        spacing: Theme.u * 4

        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            font.bold: true
            text: !root.q ? "" : root.q.phase === "won" ? I18n.t("Чисто! ✦", "Clean! ✦") : root.q.phase === "lost" ? I18n.t("Паук держится крепче. Через минуту", "The spider holds on. Try in a minute") : root.q.phase === "intro" ? I18n.t("Стряхни паутину!", "Shake the web off!") : I18n.t("Смахни: ", "Swipe: ") + root.label(root.q.seq[root.q.i])
            color: root.q && root.q.phase === "lost" ? Theme.danger : Theme.text
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 3
            visible: !!root.q && root.q.phase !== "won" && root.q.phase !== "lost"
            Repeater {
                model: root.q ? root.q.seq : []
                Item {
                    id: cellItem
                    required property string modelData
                    required property int index
                    readonly property bool current: !!root.q && index === root.q.i && root.q.phase === "run"
                    readonly property bool done: !!root.q && index < root.q.i
                    width: Theme.u * 16
                    height: Theme.u * 16
                    PxBox {
                        anchors.centerIn: parent
                        width: parent.width * (cellItem.current ? 1 : 0.75)
                        height: width
                        sunken: cellItem.done
                        color: cellItem.current ? Theme.accent : Theme.face
                        opacity: cellItem.done ? 0.45 : 1
                        y: cellItem.current ? bounce.y : 0
                        PxIcon {
                            anchors.centerIn: parent
                            name: "arrow" + cellItem.modelData[0].toUpperCase() + cellItem.modelData.slice(1)
                            pixel: Math.max(1, Math.round(Theme.u * (cellItem.current ? 1.5 : 1)))
                            ink: cellItem.current ? Theme.selectText : Theme.text
                        }
                    }
                }
            }
        }

        // the time this arrow has left
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.live
            width: Theme.u * 100
            height: Theme.u * 3
            color: Theme.sunken
            Rectangle {
                width: parent.width * root.timeLeft
                height: parent.height
                color: root.timeLeft < 0.3 ? Theme.danger : Theme.accent
            }
        }

        // three hearts: one goes with each miss
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 2
            visible: !!root.q && root.q.phase !== "won"
            Repeater {
                model: Cobweb.qteMisses
                PxIcon {
                    required property int index
                    name: root.q && index < Cobweb.qteMisses - root.q.misses ? "heart" : "heartBroken"
                    pixel: Theme.u
                    ink: root.q && index < Cobweb.qteMisses - root.q.misses ? "#ff5cad" : Theme.textDim
                }
            }
        }

        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !!root.q && (root.q.phase === "intro" || root.q.phase === "run")
            text: I18n.t("мышкой рывком или стрелками · Esc — отпустить", "fling the mouse or use the arrows · Esc lets go")
            color: Theme.textDim
        }
    }

    QtObject {
        id: bounce
        property real y: 0
    }
    SequentialAnimation {
        running: root.live && !Motion.calm
        loops: Animation.Infinite
        NumberAnimation {
            target: bounce
            property: "y"
            to: -Theme.u * 2
            duration: 180
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: bounce
            property: "y"
            to: 0
            duration: 220
            easing.type: Easing.InQuad
        }
    }

    function label(d) {
        return ({
                "left": "←",
                "right": "→",
                "up": "↑",
                "down": "↓"
            })[d] || "";
    }
}
