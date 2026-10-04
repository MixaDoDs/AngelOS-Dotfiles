import QtQuick
import qs.config
import qs.services

Item {
    id: root

    property bool checked: false
    property string text: ""
    signal toggled(bool checked)
    // the Golden Gate skin's System Settings: a Mac checkbox (rounded, the accent with a ✓)
    readonly property bool mac: Theme.settingsSkinFor(root.parent) === "goldengate"

    implicitWidth: box.width + (text !== "" ? label.implicitWidth + Theme.u * 4 : 0)
    implicitHeight: Math.max(box.height, label.implicitHeight)
    opacity: enabled ? 1 : 0.45

    Rectangle {
        visible: root.mac
        anchors.fill: box
        radius: GoldenGate.px(4)
        color: root.checked ? GoldenGate.accent : GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.12) : "#ffffff"
        border.width: root.checked ? 0 : 1
        border.color: GoldenGate.separator
        MacIcon {
            visible: root.checked
            anchors.centerIn: parent
            name: "check"
            size: parent.width * 0.8
            stroke: 3
            color: "#ffffff"
        }
    }
    PxBox {
        id: box
        opacity: root.mac ? 0 : 1
        width: root.mac ? GoldenGate.px(16) : Theme.u * 10
        height: width
        sunken: true
        color: Theme.sunken
        anchors.verticalCenter: parent.verticalCenter
        PxIcon {
            anchors.centerIn: parent
            visible: root.checked
            name: "check"
            pixel: Math.max(1, Theme.u - 1)
            ink: Theme.accent
        }
    }
    PxText {
        id: label
        text: root.text
        anchors.left: box.right
        anchors.leftMargin: Theme.u * 4
        anchors.verticalCenter: parent.verticalCenter
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const next = !root.checked;
            root.toggled(next);
            if (root.checked !== next)
                root.checked = next;
        }
    }
}
