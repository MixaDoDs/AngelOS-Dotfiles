import QtQuick
import qs.config
import qs.services
import "A11y.js" as A11y

Item {
    id: root
    // inside the P5 settings window: its colours (Theme.tone)
    readonly property bool p5: settingsSkin === "p5"
    readonly property string settingsSkin: Theme.settingsSkinFor(root.parent)

    property bool checked: false
    // the flip just made, shown until the owner's binding answers (as PxSlider): `checked` is
    // never assigned — that cut the binding, and a switch whose service refused or failed
    // stayed flipped as if it were saved. Not taken within 2 s: the truth shows again
    property var _held: undefined
    readonly property bool shown: _held === undefined ? checked : _held
    onCheckedChanged: _held = undefined
    property string text: ""
    signal toggled(bool checked)

    function flip() {
        const next = !shown;
        _held = next;
        letGo.restart();
        toggled(next);
    }
    Accessible.role: Accessible.CheckBox
    Accessible.name: A11y.name(text, root)
    Accessible.checkable: true
    Accessible.checked: shown
    Accessible.focusable: true
    Accessible.onPressAction: flip()
    Accessible.onToggleAction: flip()
    // the Golden Gate skin's System Settings: a Mac checkbox (rounded, the accent with a ✓)
    readonly property bool mac: Theme.settingsSkinFor(root.parent) === "goldengate"

    implicitWidth: box.width + (text !== "" ? label.implicitWidth + Theme.u * 4 : 0)
    implicitHeight: Math.max(box.height, label.implicitHeight)
    opacity: enabled ? 1 : 0.45

    Rectangle {
        visible: root.mac
        anchors.fill: box
        radius: GoldenGate.px(4)
        color: root.shown ? GoldenGate.accent : GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.12) : "#ffffff"
        border.width: root.shown ? 0 : 1
        border.color: GoldenGate.separator
        MacIcon {
            visible: root.shown
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
        color: Theme.toneOf(root.settingsSkin, "sunken")
        anchors.verticalCenter: parent.verticalCenter
        PxIcon {
            anchors.centerIn: parent
            visible: root.shown
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
        onClicked: root.flip()
    }
    Timer {
        id: letGo
        interval: 2000
        onTriggered: root._held = undefined
    }
}
