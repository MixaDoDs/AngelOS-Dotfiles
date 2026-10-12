pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.widgets

// How one of the call's little people looks (DiscordCrewStage keeps `who` — where they are and
// what they do; this only draws them, feet on the bottom edge): a coat of their colour, their
// avatar for a head, the name above. The head swells while they speak, with a «…» over it; a
// muted one has a red sign with a crossed-out microphone at the head, a deafened one (away
// from the call) headphones; one you muted for yourself is dimmed.
// Drawn twice while in the hand or in the air: on the stage and in the window over the whole
// screen (DiscordCrew), one over the other.
Item {
    id: look

    required property var who
    // the window over the screen shows them at once, no letter first
    property bool eager: false
    property bool names: true

    readonly property real u: who.u
    readonly property color coat: who.coat
    readonly property bool kicking: who.kicking
    readonly property int step: who.step
    // the head while speaking: two art pixels bigger, then two more
    property real swell: who.speaking ? 1 : 0
    Behavior on swell {
        NumberAnimation {
            duration: Motion.ms(110)
        }
    }
    readonly property real headSide: u * (14 + 2 * Math.round(swell * 2))

    width: u * 18
    height: u * 32

    // the legs: apart and together as they walk (and kick in the air)
    Rectangle {
        x: look.u * 5 + (look.kicking && look.step % 2 === 0 ? -look.u : 0)
        y: look.height - look.u * 5
        width: look.u * 3
        height: look.u * 5
        color: "#2b2433"
    }
    Rectangle {
        x: look.u * 10 + (look.kicking && look.step % 2 === 1 ? look.u : 0)
        y: look.height - look.u * 5
        width: look.u * 3
        height: look.u * 5
        color: "#2b2433"
    }
    // the coat
    Rectangle {
        x: look.u * 4
        y: look.height - look.u * 13
        width: look.u * 10
        height: look.u * 8
        color: look.coat
        border.width: look.u
        border.color: Qt.darker(look.coat, 1.6)
    }
    // the arms: one up while waving, both up in the hand and in the air
    Rectangle {
        x: look.u * 2
        y: look.who.up ? look.height - look.u * 19 + (look.step % 2) * look.u : look.height - look.u * 12 + (look.who.walking && look.step % 2 === 1 ? look.u : 0)
        width: look.u * 2
        height: look.u * 6
        color: Qt.darker(look.coat, 1.25)
    }
    Rectangle {
        x: look.u * 14
        y: look.who.waving || look.who.up ? look.height - look.u * 19 + (look.step % 2) * look.u : look.height - look.u * 12 + (look.who.walking && look.step % 2 === 0 ? look.u : 0)
        width: look.u * 2
        height: look.u * 6
        color: Qt.darker(look.coat, 1.25)
    }
    // the head: their avatar, pixel-sharp; it stands on the coat and swells up and to the sides
    Rectangle {
        id: head
        x: (look.width - width) / 2
        y: look.height - look.u * 13 - height
        width: look.headSide
        height: look.headSide
        color: "#2b2433"
        Rectangle {
            x: look.u
            y: look.u
            width: parent.width - look.u * 2
            height: parent.height - look.u * 2
            color: look.coat
            PxText {
                anchors.centerIn: parent
                visible: pic.status !== Image.Ready
                color: "#2b2433"
                text: look.who.name.charAt(0).toUpperCase()
            }
            Image {
                id: pic
                anchors.fill: parent
                source: look.who.avatar ? "file://" + look.who.avatar : ""
                sourceSize.width: look.who.me ? 36 : 24
                sourceSize.height: look.who.me ? 36 : 24
                fillMode: Image.PreserveAspectCrop
                smooth: false
                asynchronous: !look.eager
                mirror: look.who.facingLeft
                // muted by you, for yourself: dimmed
                opacity: look.who.quiet ? 0.35 : 1
            }
        }
        // muted: a red sign at the head's corner — a microphone, crossed out
        Rectangle {
            visible: look.who.muted && !look.who.deaf
            x: parent.width - look.u * 5
            y: -look.u * 7
            width: look.u * 11
            height: look.u * 11
            color: "#e04848"
            border.width: look.u
            border.color: "#2b2433"
            Rectangle {
                x: look.u * 4
                y: look.u * 2
                width: look.u * 3
                height: look.u * 4
                color: "#ffffff"
            }
            Rectangle {
                x: look.u * 3
                y: look.u * 7
                width: look.u * 5
                height: look.u
                color: "#ffffff"
            }
            Rectangle {
                x: look.u * 5
                y: look.u * 8
                width: look.u
                height: look.u
                color: "#ffffff"
            }
            Repeater {
                model: 9
                Rectangle {
                    required property int index
                    x: look.u * (1 + index)
                    y: look.u * (8 - index)
                    width: look.u
                    height: look.u * 2
                    color: "#2b2433"
                }
            }
        }
        // deafened — not listening, away: headphones, a band over the head and a red cup on each ear
        Item {
            visible: look.who.deaf
            anchors.fill: parent
            Rectangle {
                x: -look.u
                y: -look.u * 2
                width: parent.width + look.u * 2
                height: look.u * 2
                color: "#2b2433"
            }
            Rectangle {
                x: -look.u * 2
                y: -look.u
                width: look.u * 2
                height: parent.height / 2
                color: "#2b2433"
            }
            Rectangle {
                x: parent.width
                y: -look.u
                width: look.u * 2
                height: parent.height / 2
                color: "#2b2433"
            }
            Rectangle {
                x: -look.u * 3
                y: parent.height / 2 - look.u * 3
                width: look.u * 4
                height: look.u * 7
                color: "#e04848"
                border.width: look.u
                border.color: "#2b2433"
            }
            Rectangle {
                x: parent.width - look.u
                y: parent.height / 2 - look.u * 3
                width: look.u * 4
                height: look.u * 7
                color: "#e04848"
                border.width: look.u
                border.color: "#2b2433"
            }
        }
    }
    // «…» over whoever speaks
    Rectangle {
        visible: look.who.speaking
        x: look.u * 12
        y: head.y - look.u * 8
        width: dots.implicitWidth + look.u * 4
        height: look.u * 7
        color: "#ffffff"
        border.width: look.u
        border.color: "#2b2433"
        PxText {
            id: dots
            anchors.centerIn: parent
            kind: "tiny"
            color: "#2b2433"
            text: "…"
        }
    }
    // the name, over the head (never mirrored)
    Item {
        visible: look.names
        x: (look.width - nameText.implicitWidth) / 2
        y: head.y - nameText.implicitHeight - look.u * (look.who.speaking ? 10 : look.who.muted && !look.who.deaf ? 9 : look.who.deaf ? 4 : 2)
        width: nameText.implicitWidth + 1
        height: nameText.implicitHeight + 1
        PxText {
            x: 1
            y: 1
            kind: nameText.kind
            color: "#000000"
            opacity: 0.55
            text: nameText.text
        }
        PxText {
            id: nameText
            kind: look.who.me ? "body" : "tiny"
            color: "#ffffff"
            text: look.who.name.length > 14 ? look.who.name.slice(0, 13) + "…" : look.who.name
        }
    }
}
