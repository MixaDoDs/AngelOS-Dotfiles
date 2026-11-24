import QtQuick
import qs.config
import qs.services
import qs.widgets
import "Frames.js" as Frames

// The privacy eye on the bar: open while privacy (Mod+Shift+X, services/Privacy) is off, asleep
// while it is on. Switching plays a short pixel animation (Frames.close / Frames.wake); click:
// the privacy settings (Stream mode → Privacy on stream), right click: switch the mode.
//   pixel  the 11×8 eye of the built-in icon, frame by frame
//   mac    a monochrome line eye in the bar's ink, struck through while privacy is on
Item {
    id: root

    property var plugin
    property string screenName
    property var barWindow
    property bool barInk: false

    readonly property bool mac: Skin.mac
    readonly property bool on: Privacy.on

    // the sequence playing (or played: its last frame is the rest) and the step in it
    property var seq: Frames.wake
    property int step: Frames.wake.length - 1

    Component.onCompleted: {
        seq = on ? Frames.close : Frames.wake;
        step = seq.length - 1;
    }
    onOnChanged: {
        seq = on ? Frames.close : Frames.wake;
        // "Motion: off" goes straight to the rest
        step = Motion.ms(1) > 0 ? 0 : seq.length - 1;
    }

    // runs only while a sequence plays
    Timer {
        id: tick
        running: !root.mac && root.step < root.seq.length - 1
        // seq and step change one after the other: guard the moment step is past the new seq
        interval: Math.max(16, root.seq[Math.min(root.step, root.seq.length - 1)][1])
        onTriggered: root.step += 1
    }

    implicitWidth: mac ? Skin.px(22) : eye.width + Theme.u * 4
    implicitHeight: mac ? Skin.px(18) : Theme.u * 13

    PxButton {
        anchors.fill: parent
        flat: true
        compact: true
        barInk: root.barInk
        onClicked: Shell.openSettings("stream", "stream-privacy")
        onRightClicked: Privacy.set(root.on ? "off" : "on")
        Accessible.name: "Приватность"
    }

    PxIcon {
        id: eye
        visible: !root.mac
        anchors.centerIn: parent
        bitmap: root.seq[Math.min(root.step, root.seq.length - 1)][0]
        pixel: Theme.u
    }

    Item {
        visible: root.mac
        anchors.centerIn: parent
        width: Skin.px(16)
        height: Skin.px(16)
        MacIcon {
            anchors.centerIn: parent
            name: "eye"
            size: Skin.px(15)
            stroke: 2
            color: Skin.ink(root.screenName)
        }
        // the slash draws itself across the eye as privacy comes on
        Rectangle {
            anchors.centerIn: parent
            width: root.on ? Skin.px(19) : 0
            height: Skin.px(2)
            radius: height / 2
            rotation: -45
            color: Skin.ink(root.screenName)
            visible: width > 0
            Behavior on width {
                NumberAnimation {
                    duration: Motion.ms(220)
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

}
