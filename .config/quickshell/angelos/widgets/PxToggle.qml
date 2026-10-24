import QtQuick
import qs.config
import qs.services
import "A11y.js" as A11y

// Pixel switch with a heart knob.
Item {
    id: root

    property bool checked: false
    // the flip just made, shown until the owner's binding answers (as PxSlider): `checked` is
    // never assigned — that cut the binding, and a switch whose service refused or failed
    // stayed flipped as if it were saved. Not taken within 2 s: the truth shows again
    property var _held: undefined
    readonly property bool shown: _held === undefined ? checked : _held
    onCheckedChanged: _held = undefined
    property string text: ""
    readonly property string settingsSkin: Theme.settingsSkinFor(root.parent)
    readonly property bool mac: settingsSkin === "goldengate"
    // the P5 settings window: two plates, ВКЛ and ВЫКЛ, the one that holds black
    readonly property bool p5: settingsSkin === "p5"
    signal toggled(bool checked)

    function flip() {
        const next = !shown;
        _held = next;
        letGo.restart();
        toggled(next);
        Sounds.play("toggle");
    }
    Accessible.role: Accessible.CheckBox
    Accessible.name: A11y.name(text, root)
    Accessible.checkable: true
    Accessible.checked: shown
    Accessible.focusable: true
    Accessible.onPressAction: flip()
    Accessible.onToggleAction: flip()

    // Long labels wrap instead of running off a narrow page (the grimoire's right
    // page): inside a box marked `fixedWidth` (SettingRow's control slot, PxGroup's
    // column) the switch is no wider than what is left of that box.
    readonly property real room: {
        let dx = 0;
        for (let p = root; p && p.parent; p = p.parent) {
            dx += p.x;
            if (p.parent.fixedWidth === true)
                return p.parent.width - dx;
        }
        return Infinity;
    }

    implicitWidth: track.width + (label.visible ? label.implicitWidth + Theme.u * 5 : 0)
    implicitHeight: Math.max(track.height, label.implicitHeight)
    width: Math.max(track.width, Math.min(implicitWidth, room))
    opacity: enabled ? 1 : 0.45

    // the Golden Gate skin's System Settings: a Mac switch — the accent when on, a white knob
    Rectangle {
        visible: root.mac
        width: track.width
        height: track.height
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: root.shown ? GoldenGate.accent : GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.1)
        Behavior on color {
            ColorAnimation {
                duration: Motion.ms(150)
            }
        }
        Rectangle {
            width: parent.height - GoldenGate.px(4)
            height: width
            radius: width / 2
            y: GoldenGate.px(2)
            x: root.shown ? parent.width - width - GoldenGate.px(2) : GoldenGate.px(2)
            color: "#ffffff"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.08)
            Behavior on x {
                NumberAnimation {
                    duration: Motion.ms(160)
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    PxBox {
        id: track
        visible: root.settingsSkin === "classic"
        width: root.mac ? GoldenGate.px(38) : root.p5 ? p5Row.implicitWidth : Theme.u * 26
        height: root.mac ? GoldenGate.px(22) : root.p5 ? p5Row.implicitHeight : Theme.u * 13
        anchors.verticalCenter: parent.verticalCenter
        sunken: true
        color: root.shown ? Theme.mix(Theme.sunken, Theme.accent, 0.55) : Theme.sunken

        PxBox {
            id: knob
            width: parent.height
            height: width
            y: 0
            x: root.shown ? parent.width - width : 0
            color: root.shown ? Theme.accent : Theme.face
            Behavior on x {
                NumberAnimation {
                    duration: Motion.ms(Theme.fast)
                    easing.type: Easing.OutBack
                }
            }
            PxIcon {
                anchors.centerIn: parent
                name: "heartSmall"
                pixel: Math.max(1, Theme.u - 1)
                fill: root.shown ? "#ffffff" : Theme.lo
                ink: root.shown ? Theme.edge : Theme.textDim
            }
        }
    }

    Row {
        id: p5Row
        visible: root.p5
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.u * 2
        Repeater {
            model: [true, false]
            Item {
                id: sw
                required property bool modelData
                readonly property bool on: root.shown === modelData
                width: swText.implicitWidth + Theme.u * 8
                height: swText.implicitHeight + Theme.u * 3
                P5Slant {
                    anchors.fill: parent
                    color: sw.on ? Theme.p5Black : Theme.p5Paper2
                }
                PxText {
                    id: swText
                    anchors.centerIn: parent
                    text: sw.modelData ? I18n.t("ВКЛ", "ON") : I18n.t("ВЫКЛ", "OFF")
                    color: sw.on ? Theme.p5Paper : Theme.p5Black
                    font.bold: true
                }
            }
        }
    }
    Rectangle {
        visible: root.settingsSkin !== "classic" && !root.mac && !root.p5
        width: track.width
        height: track.height
        anchors.verticalCenter: parent.verticalCenter
        radius: root.settingsSkin === "windose" ? height / 2 : Theme.u * 2
        color: root.shown ? Theme.mix(Theme.face, Theme.accent, 0.36) : Theme.sunken
        border.width: Math.max(1, Theme.u / 2)
        border.color: root.settingsSkin === "windose" ? Theme.windoseLine : Theme.streamLive
        Rectangle {
            width: parent.height - Theme.u * 2
            height: width
            y: Theme.u
            x: root.shown ? parent.width - width - Theme.u : Theme.u
            radius: root.settingsSkin === "windose" ? width / 2 : Theme.u * 2
            color: root.shown ? Theme.accent : Theme.faceAlt
            border.width: Math.max(1, Theme.u / 2)
            border.color: root.settingsSkin === "windose" ? Theme.windoseLine : Theme.streamLive
            Behavior on x { NumberAnimation { duration: Theme.fast } }
            PxIcon {
                visible: root.settingsSkin === "windose"
                anchors.centerIn: parent
                name: "heartSmall"
                pixel: Math.max(1, Theme.u - 1)
                ink: root.shown ? Theme.selectText : Theme.text
            }
        }
    }

    PxText {
        id: label
        visible: root.text !== ""
        text: root.text
        width: Math.min(implicitWidth, Math.max(0, root.width - track.width - Theme.u * 5))
        wrapMode: Text.Wrap
        anchors.left: track.right
        anchors.leftMargin: Theme.u * 5
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
