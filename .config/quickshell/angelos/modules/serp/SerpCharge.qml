import QtQuick
import qs.services

// serp-skin: a device's charge as a small capsule (services/Peripherals): its liquid in the level's
// colour — the accent while it is fine, peach when low, red when very low — a light running along
// it while it charges (only then: a still capsule draws nothing), a bolt on it then.
Item {
    id: root

    property real percent: 0
    property string level: "ok"          // ok | low | veryLow (Peripherals)
    property bool charging: false
    property bool asleep: false          // it stopped answering: dimmed, its last charge
    property real w: Serp.px(24)
    property real h: Serp.px(11)

    readonly property color liquid: charging ? Serp.green : level === "veryLow" ? Serp.red : level === "low" ? Serp.peach : Serp.accent
    implicitWidth: w + Serp.px(3)
    implicitHeight: h
    opacity: asleep ? 0.5 : 1

    // the shell
    Rectangle {
        id: body
        width: root.w
        height: root.h
        radius: height / 2
        color: Qt.alpha(Serp.text, 0.06)
        border.width: Math.max(1, Serp.px(1.2))
        border.color: Qt.alpha(Serp.text, 0.45)
        clip: true

        // the liquid, inset by the rim
        Rectangle {
            id: fill
            readonly property real pad: Serp.px(2)
            x: pad
            y: pad
            height: parent.height - pad * 2
            width: Math.max(height, (parent.width - pad * 2) * Math.max(0, Math.min(1, root.percent / 100)))
            radius: height / 2
            color: root.liquid
            Behavior on width {
                NumberAnimation {
                    duration: Serp.normal
                    easing.type: Easing.OutCubic
                }
            }

            // charging: a light running along the liquid, born and gone inside it (it used to start
            // left of the liquid and run past its end: over the rim, behind the glass) — clipped to
            // the liquid, faded in and out at its ends so its rounded ends cut nothing sharp
            clip: true
            Rectangle {
                id: shine
                visible: root.charging
                width: Math.min(parent.height * 1.6, parent.width * 0.6)
                height: parent.height
                radius: height / 2
                color: "white"
                property real t: 0       // 0 … 1 along the liquid
                x: -width + t * (parent.width + width)
                opacity: 0.45 * Math.min(1, Math.min(t, 1 - t) * 4)
                NumberAnimation on t {
                    running: root.charging && root.visible
                    from: 0
                    to: 1
                    duration: 1400
                    loops: Animation.Infinite
                }
            }
        }
    }
    // the nub
    Rectangle {
        x: root.w + Serp.px(1)
        anchors.verticalCenter: body.verticalCenter
        width: Serp.px(2)
        height: root.h * 0.42
        radius: width / 2
        color: Qt.alpha(Serp.text, 0.45)
    }
    // the bolt while it charges
    SIcon {
        visible: root.charging
        anchors.centerIn: body
        name: "zap"
        size: root.h * 0.95
        color: Serp.text   // light: on the empty glass as on the liquid (the base colour vanished on an emptyish one)
        filled: true
    }
}
