pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.widgets

// What is left of one of the call's little people when they leave it (DiscordCrewStage): they
// burst into pixel blood and scraps of the coat, the head tumbles away; it all falls to the
// floor, lies there a moment and fades. The item is a point on the floor under their feet
// (everything in it goes up from y = 0); `done` when nothing is left.
Item {
    id: burst

    required property real u             // their art pixel
    required property color coat
    property real alt: 0                 // how high their feet were
    property string avatar: ""
    property string initial: "?"

    signal done

    readonly property var reds: ["#e8203f", "#c4142e", "#9a0e22", "#e8203f", "#6b0a17"]
    readonly property real g: u * 520    // px/s²

    Timer {
        interval: 5200
        running: true
        onTriggered: burst.done()
    }

    // the flash: one white frame or two (not in calm motion)
    Rectangle {
        id: flash
        visible: !Motion.calm
        width: burst.u * 22
        height: burst.u * 22
        x: -width / 2
        y: -burst.alt - burst.u * 14 - height / 2
        color: "#ffffff"
        Timer {
            interval: 70
            running: true
            onTriggered: flash.visible = false
        }
    }

    // the puddle under them: spreads in whole art pixels
    Rectangle {
        id: puddle
        property real spread: 0
        width: Math.round(spread / 2) * 2 * burst.u
        height: burst.u
        x: -width / 2
        y: -height
        color: burst.reds[2]
        SequentialAnimation {
            running: true
            PauseAnimation {
                duration: 350 + Math.sqrt(2 * burst.alt / burst.g) * 1000
            }
            NumberAnimation {
                target: puddle
                property: "spread"
                to: 20
                duration: 900
                easing.type: Easing.OutQuad
            }
            PauseAnimation {
                duration: 2200
            }
            OpacityAnimator {
                target: puddle
                from: 1
                to: 0
                duration: 900
            }
        }
    }

    // the drops and the scraps: thrown up and out, each on its own arc down to the floor
    Repeater {
        model: Motion.calm ? 30 : 84
        Rectangle {
            id: drop
            required property int index
            readonly property bool scrap: index % 9 === 0
            readonly property real side: burst.u * (scrap ? 3 : index % 7 === 3 ? 3 : index % 2 ? 2 : 1)
            readonly property real vx: (Math.random() * 2 - 1) * burst.u * (scrap ? 70 : 130)
            readonly property real vy: burst.u * (30 + Math.random() * 150)
            readonly property real start: burst.alt + burst.u * (5 + Math.random() * 20)
            readonly property real peak: start + vy * vy / (2 * burst.g)
            readonly property int up: vy / burst.g * 1000
            readonly property int down: Math.sqrt(2 * peak / burst.g) * 1000
            readonly property int lie: 1200 + Math.random() * 1800
            width: side
            height: side
            color: scrap ? burst.coat : burst.reds[index % burst.reds.length]
            x: -side / 2
            y: -start - side
            XAnimator {
                target: drop
                running: true
                from: -drop.side / 2
                to: -drop.side / 2 + drop.vx * (drop.up + drop.down) / 1000
                duration: drop.up + drop.down
                easing.type: Easing.Linear
            }
            SequentialAnimation {
                running: true
                YAnimator {
                    target: drop
                    from: -drop.start - drop.side
                    to: -drop.peak - drop.side
                    duration: drop.up
                    easing.type: Easing.OutQuad
                }
                YAnimator {
                    target: drop
                    from: -drop.peak - drop.side
                    to: -drop.side
                    duration: drop.down
                    easing.type: Easing.InQuad
                }
                PauseAnimation {
                    duration: drop.lie
                }
                OpacityAnimator {
                    target: drop
                    from: 1
                    to: 0
                    duration: 600
                }
            }
        }
    }

    // the head: up and away, turning by quarters, then it lies where it fell
    Rectangle {
        id: head
        readonly property real vx: (Math.random() < 0.5 ? -1 : 1) * burst.u * (25 + Math.random() * 45)
        readonly property real vy: burst.u * (150 + Math.random() * 50)
        readonly property real start: burst.alt + burst.u * 13
        readonly property real peak: start + vy * vy / (2 * burst.g)
        readonly property int up: vy / burst.g * 1000
        readonly property int down: Math.sqrt(2 * peak / burst.g) * 1000
        property bool flying: true
        width: burst.u * 14
        height: burst.u * 14
        x: -width / 2
        y: -start - height
        color: "#2b2433"
        Rectangle {
            x: burst.u
            y: burst.u
            width: parent.width - burst.u * 2
            height: parent.height - burst.u * 2
            color: burst.coat
            PxText {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                color: "#2b2433"
                text: burst.initial
            }
            Image {
                id: face
                anchors.fill: parent
                source: burst.avatar ? "file://" + burst.avatar : ""
                sourceSize.width: 24
                sourceSize.height: 24
                fillMode: Image.PreserveAspectCrop
                smooth: false
                asynchronous: true
            }
        }
        Timer {
            interval: 110
            repeat: true
            running: head.flying && !Motion.calm
            onTriggered: head.rotation += head.vx < 0 ? -90 : 90
        }
        XAnimator {
            target: head
            running: true
            from: -head.width / 2
            to: -head.width / 2 + head.vx * (head.up + head.down) / 1000
            duration: head.up + head.down
            easing.type: Easing.Linear
        }
        SequentialAnimation {
            running: true
            YAnimator {
                target: head
                from: -head.start - head.height
                to: -head.peak - head.height
                duration: head.up
                easing.type: Easing.OutQuad
            }
            YAnimator {
                target: head
                from: -head.peak - head.height
                to: -head.height
                duration: head.down
                easing.type: Easing.InQuad
            }
            ScriptAction {
                script: head.flying = false
            }
            PauseAnimation {
                duration: 2000
            }
            OpacityAnimator {
                target: head
                from: 1
                to: 0
                duration: 700
            }
        }
    }
}
