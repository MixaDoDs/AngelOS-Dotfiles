pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The phone's keypad (Phone): the green key (call, answer, send), ◀ OK ▶, the red key (end,
// decline, back), then 1…9 * 0 # with their letters, as on a phone of 2002. Every key goes to
// Phone.key(), which beeps it (PhoneLine.tone) and hands it to the screen; what a key does
// shows on the screen's last line while the pointer is over a soft key. On its side the keys'
// faces turn to stay upright.
Item {
    id: root

    required property var phone
    // flip: the nav row over the digits; brick: the same, the 3310's chunky way; taco: the pad on
    // the left and the digits on the right, the screen between (gapW wide)
    property string layout: "flip"
    property real gapW: 0
    readonly property bool taco: layout === "taco"
    readonly property int k: Theme.u
    readonly property real gap: k * (layout === "brick" ? 2 : 3)
    readonly property real navH: taco ? 0 : k * (layout === "brick" ? 16 : 18)
    readonly property real sideW: taco ? (width - gapW) / 2 : width
    readonly property real keyW: (sideW - gap * 2) / 3
    readonly property real keyH: (height - navH - gap * (taco ? 3 : 5)) / 4

    component Key: Item {
        id: key
        property string icon: ""
        property string digit: ""
        property string letters: ""
        property string label: ""
        property color cap: Theme.mix(root.phone.shellColor, "#ffffff", root.phone.hell ? 0.06 : 0.45)
        property color mark: root.phone.trim
        signal hit()
        readonly property bool down: mouse.pressed
        Rectangle {
            // the key's side, seen under it
            y: root.k
            width: parent.width
            height: parent.height
            color: root.phone.ink
        }
        Rectangle {
            y: key.down ? root.k : 0
            width: parent.width
            height: parent.height
            color: mouse.containsMouse ? Theme.mix(key.cap, root.phone.trim, 0.25) : key.cap
            border.width: root.k
            border.color: root.phone.ink
            Rectangle {
                x: root.k
                y: root.k
                width: parent.width - root.k * 2
                height: root.k
                color: Qt.alpha("#ffffff", 0.5)
            }
            Item {
                anchors.centerIn: parent
                width: root.phone.turn > 0.5 ? parent.height : parent.width
                height: root.phone.turn > 0.5 ? parent.width : parent.height
                rotation: 90 * root.phone.turn
                PxIcon {
                    visible: key.icon !== ""
                    anchors.centerIn: parent
                    name: key.icon
                    fill: key.mark
                    ink: root.phone.ink
                }
                Column {
                    visible: key.digit !== ""
                    anchors.centerIn: parent
                    spacing: -root.k
                    PxText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: key.digit
                        kind: "title"
                        color: root.phone.hell ? Theme.hellText : Theme.mix(root.phone.ink, "#000000", 0.35)
                    }
                    PxText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: key.letters !== ""
                        text: key.letters
                        kind: "tiny"
                        color: root.phone.trim
                    }
                }
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: key.hit()
            onContainsMouseChanged: {
                if (!key.label)
                    return;
                if (containsMouse)
                    root.phone.hint = key.label;
                else if (root.phone.hint === key.label)
                    root.phone.hint = "";
            }
        }
    }

    // ---- green ◀ OK ▶ red (the taco: a cross on its left) ----
    Row {
        id: nav
        visible: !root.taco
        width: parent.width
        height: root.navH
        spacing: root.k * 2
        readonly property real kw: (width - spacing * 4) / 5
        Key {
            width: nav.kw
            height: nav.height
            icon: "phone"
            label: root.phone.soft[0] || I18n.t("Вызов", "Call")
            cap: Theme.mix(Theme.ok, "#ffffff", 0.35)
            mark: "#ffffff"
            onHit: root.phone.key("call")
        }
        Key {
            width: nav.kw
            height: nav.height
            icon: "arrowLeft"
            onHit: root.phone.key("left")
        }
        Key {
            width: nav.kw
            height: nav.height
            icon: "check"
            label: root.phone.soft[1] || "OK"
            onHit: root.phone.key("ok")
        }
        Key {
            width: nav.kw
            height: nav.height
            icon: "arrowRight"
            onHit: root.phone.key("right")
        }
        Key {
            width: nav.kw
            height: nav.height
            icon: "close"
            label: root.phone.soft[2] || I18n.t("Назад", "Back")
            cap: Theme.mix(Theme.danger, "#ffffff", 0.4)
            mark: "#ffffff"
            onHit: root.phone.key("end")
        }
    }

    Item {
        id: cross
        visible: root.taco
        width: root.sideW
        height: root.height
        readonly property real kk: Math.min(width, height) / 3.3
        Key {
            x: (cross.width - width) / 2
            y: 0
            width: cross.kk
            height: cross.kk
            icon: "phone"
            label: root.phone.soft[0] || I18n.t("Вызов", "Call")
            cap: Theme.mix(Theme.ok, "#ffffff", 0.35)
            mark: "#ffffff"
            onHit: root.phone.key("call")
        }
        Key {
            x: (cross.width - width) / 2 - cross.kk * 1.1
            y: (cross.height - height) / 2
            width: cross.kk
            height: cross.kk
            icon: "arrowLeft"
            onHit: root.phone.key("left")
        }
        Key {
            x: (cross.width - width) / 2
            y: (cross.height - height) / 2
            width: cross.kk
            height: cross.kk
            icon: "check"
            label: root.phone.soft[1] || "OK"
            onHit: root.phone.key("ok")
        }
        Key {
            x: (cross.width - width) / 2 + cross.kk * 1.1
            y: (cross.height - height) / 2
            width: cross.kk
            height: cross.kk
            icon: "arrowRight"
            onHit: root.phone.key("right")
        }
        Key {
            x: (cross.width - width) / 2
            y: cross.height - height
            width: cross.kk
            height: cross.kk
            icon: "close"
            label: root.phone.soft[2] || I18n.t("Назад", "Back")
            cap: Theme.mix(Theme.danger, "#ffffff", 0.4)
            mark: "#ffffff"
            onHit: root.phone.key("end")
        }
    }

    // ---- 1…9 * 0 # ----
    readonly property var letters: I18n.english ? ["", "abc", "def", "ghi", "jkl", "mno", "pqrs", "tuv", "wxyz", "", "", ""] : ["", "абвг", "дежз", "ийкл", "мноп", "рсту", "фхцч", "шщъы", "ьэюя", "", "", ""]
    Grid {
        x: root.taco ? root.width - root.sideW : 0
        y: root.taco ? 0 : root.navH + root.gap * 2
        columns: 3
        spacing: root.gap
        Repeater {
            model: root.phone.keyNames
            Key {
                required property string modelData
                required property int index
                width: root.keyW
                height: root.keyH
                digit: modelData
                letters: root.letters[index] || ""
                onHit: root.phone.key(modelData)
            }
        }
    }
}
