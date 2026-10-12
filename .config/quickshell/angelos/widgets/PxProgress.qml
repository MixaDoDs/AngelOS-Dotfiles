import QtQuick
import qs.config
import qs.services

// A Win98 progress bar: a sunken trough filled with the accent's blocks, the percent over it.
// `busy` while a step runs: a light sweeps along the filled part (it moves even when the number
// waits for a long download), and with nothing filled yet it walks the empty trough.
//   value 0…1 · busy · text (shown instead of the percent; "" = the percent)
// The Golden Gate skin's System Settings: a thin rounded Mac bar instead.
Item {
    id: root

    property real value: 0
    property bool busy: false
    property string text: ""
    property bool showText: true
    property color fill: Theme.accent
    // what the bar shows: the value, eased (a readonly one can't carry a Behavior)
    property real shown: Math.max(0, Math.min(1, value))
    readonly property bool mac: Theme.settingsSkinFor(root.parent) === "goldengate"

    implicitWidth: Theme.u * 120
    implicitHeight: mac ? GoldenGate.px(6) + (showText ? label.implicitHeight + GoldenGate.px(4) : 0) : Theme.u * 9

    Accessible.role: Accessible.ProgressBar
    Accessible.name: label.text

    Behavior on shown {
        NumberAnimation {
            duration: Motion.ms(450)
            easing.type: Easing.OutCubic
        }
    }

    // ---- the Mac bar ----
    Item {
        visible: root.mac
        anchors.fill: parent
        Rectangle {
            id: macTrack
            width: parent.width
            height: GoldenGate.px(6)
            radius: height / 2
            color: GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)
            clip: true
            Rectangle {
                width: Math.max(macTrack.height, macTrack.width * root.shown)
                visible: root.shown > 0
                height: parent.height
                radius: parent.radius
                color: GoldenGate.accent
            }
            Rectangle {
                visible: root.busy && root.shown <= 0
                width: macTrack.width * 0.25
                height: parent.height
                radius: parent.radius
                color: GoldenGate.accent
                SequentialAnimation on x {
                    running: root.mac && root.busy && root.visible && root.shown <= 0
                    loops: Animation.Infinite
                    NumberAnimation { from: -macTrack.width * 0.25; to: macTrack.width; duration: 1400; easing.type: Easing.InOutQuad }
                }
            }
        }
        MacText {
            visible: root.showText
            y: macTrack.height + GoldenGate.px(4)
            width: parent.width
            horizontalAlignment: Text.AlignRight
            size: GoldenGate.px(11)
            color: GoldenGate.secondaryLabel
            text: label.text
        }
    }

    // ---- the pixel bar ----
    PxBox {
        id: trough
        visible: !root.mac
        anchors.fill: parent
        sunken: true
        color: Theme.sunken
        hell: Theme.hell

        Item {
            id: well
            anchors.fill: parent
            anchors.margins: trough.inset + Math.max(1, Math.round(Theme.u / 2))
            clip: true
            readonly property int block: Math.max(Theme.u * 2, Math.round(height * 0.62))
            readonly property int gap: Math.max(1, Math.round(Theme.u / 2))
            readonly property int blocks: Math.max(1, Math.floor((width + gap) / (block + gap)))
            readonly property int lit: Math.round(blocks * root.shown)

            Row {
                spacing: well.gap
                height: parent.height
                Repeater {
                    model: well.lit
                    Rectangle {
                        required property int index
                        width: well.block
                        height: well.height
                        color: root.fill
                        // the sweep: one brighter block runs over the filled part
                        Rectangle {
                            anchors.fill: parent
                            color: "#ffffff"
                            opacity: root.busy && sweep.at === parent.index ? 0.45 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 160
                                }
                            }
                        }
                    }
                }
            }
            // nothing filled yet but working: three blocks walk the trough
            Row {
                visible: root.busy && well.lit === 0
                spacing: well.gap
                height: parent.height
                x: (sweep.at - 3) * (well.block + well.gap)
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: well.block
                        height: well.height
                        color: root.fill
                        opacity: 0.35 + index * 0.25
                    }
                }
            }
            Timer {
                id: sweep
                property int at: 0
                running: root.busy && root.visible && !root.mac
                repeat: true
                interval: 90
                onTriggered: at = (at + 1) % ((well.lit > 0 ? well.lit : well.blocks + 3) + 4)
            }
        }
        PxText {
            id: label
            visible: root.showText
            anchors.centerIn: parent
            kind: "tiny"
            font.bold: true
            color: root.shown > 0.5 ? Theme.selectText : Theme.text
            style: Text.Outline
            styleColor: root.shown > 0.5 ? Theme.mix(root.fill, "#000000", 0.35) : Theme.sunken
            text: root.text !== "" ? root.text : Math.floor(root.shown * 100) + "%"
        }
    }
}
