import QtQuick
import qs.config
import qs.services
import "MacIcons.js" as MacIcons

Item {
    id: root

    property string text: ""
    property string icon: ""
    property bool checked: false
    property bool checkable: false
    property bool accent: false
    property bool danger: false
    property bool flat: false
    property bool compact: false
    property bool hell: false              // hell's palette (Theme.realm): obsidian, blood, bone text
    // the hell bar (BarItem sets it): no face of its own — a flat plate only while the pointer
    // is on it (Theme.hellBarHover) or it is open / on (hellBarActive), as tall as the bar's
    // cell; the icon is its outline in the icon colour, the accent only for a state (open, on,
    // the strike of "off")
    property bool barInk: false
    // the face while pressed or on (classic skin): unset = the accent-tinted one; the Start
    // button sets a darker face so its accent-coloured logo still reads when it is pushed in
    property color downColor: "transparent"
    readonly property string settingsSkin: root.hell ? "classic" : Theme.settingsSkinFor(root.parent)
    // the Golden Gate skin's System Settings: a Mac push button (white, a hairline, the accent when
    // it is the default or picked), line icons where angelOS's pixel ones have a match
    readonly property bool mac: settingsSkin === "goldengate" && !root.barInk
    readonly property string macIcon: mac && icon !== "" ? MacIcons.fromPixel(icon) : ""
    property int iconPixel: Theme.u
    property bool middleButton: false      // also report middle clicks (task buttons close windows with them)
    property string kind: "body"
    property alias hovered: mouse.containsMouse
    property alias pressed: mouse.pressed
    readonly property bool down: mouse.pressed || checked
    signal clicked
    signal rightClicked
    signal middleClicked

    // left + right padding; -1 = by `compact` (the bar's dense right side sets it)
    property real hpad: -1
    implicitWidth: row.implicitWidth + (hpad >= 0 ? hpad : mac ? GoldenGate.px(compact ? 16 : 24) : compact ? Theme.u * 6 : Theme.pad * 2 + Theme.u * 2)
    implicitHeight: mac ? Math.max(row.implicitHeight + GoldenGate.px(10), GoldenGate.px(compact ? 24 : 28)) : Math.max(row.implicitHeight + Theme.u * (compact ? 5 : 8), Theme.u * (compact ? 11 : 15))
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        visible: root.barInk && (mouse.containsMouse || root.checked)
        color: root.checked ? Theme.hellBarActive : Theme.hellBarHover
    }
    PxBox {
        anchors.fill: parent
        visible: !root.barInk && root.settingsSkin === "classic" && (!root.flat || mouse.containsMouse || root.checked)
        sunken: root.down
        hell: root.hell
        color: root.down && root.downColor.a > 0 && !root.hell && !root.accent && !root.danger ? root.downColor : root.hell ? (root.accent ? (mouse.containsMouse ? Qt.lighter(Theme.hellBlood, 1.15) : Theme.hellBlood) : root.checked ? Theme.mix(Theme.hellFace, Theme.hellBlood, 0.45) : mouse.containsMouse ? Theme.mix(Theme.hellFace, Theme.hellEmber, 0.2) : Theme.hellFace) : root.accent ? (mouse.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent) : root.danger && mouse.containsMouse ? Theme.danger : root.checked ? Theme.mix(Theme.face, Theme.accent, Theme.dark ? 0.4 : 0.3) : mouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.12) : Theme.face
    }

    Rectangle {
        visible: root.mac && (!root.flat || mouse.containsMouse || root.checked)
        anchors.fill: parent
        radius: GoldenGate.px(7)
        color: root.accent || root.checked ? (mouse.pressed ? Qt.darker(GoldenGate.accent, 1.12) : GoldenGate.accent) : mouse.pressed ? GoldenGate.hoverBg : GoldenGate.dark ? Qt.rgba(1, 1, 1, mouse.containsMouse ? 0.18 : 0.12) : mouse.containsMouse ? "#fafafa" : "#ffffff"
        border.width: root.accent || root.checked ? 0 : 1
        border.color: GoldenGate.separator
    }
    Rectangle {
        visible: root.settingsSkin === "windose" && !root.barInk
        x: Theme.u
        y: Theme.u
        width: parent.width - Theme.u
        height: parent.height - Theme.u
        radius: height / 2
        color: Qt.alpha(Theme.shadow, Theme.dark ? 0.25 : 0.12)
    }
    Rectangle {
        visible: root.settingsSkin === "windose" && !root.barInk
        x: root.down ? Theme.u : 0
        y: root.down ? Theme.u : 0
        width: parent.width - Theme.u
        height: parent.height - Theme.u
        radius: height / 2
        color: root.danger ? Theme.danger : root.accent || root.checked ? Theme.windoseRose : mouse.containsMouse ? Theme.mix(Theme.windoseSticker, Theme.windoseLavender, 0.24) : Theme.windoseSticker
        border.width: Math.max(1, Theme.u / 2)
        border.color: Theme.windoseLine
    }
    Rectangle {
        visible: root.settingsSkin === "stream" && !root.barInk
        anchors.fill: parent
        anchors.margins: root.down ? Theme.u : 0
        radius: Theme.u * 2
        color: root.danger ? Theme.danger : root.accent || root.checked ? Theme.streamLive : mouse.containsMouse ? Theme.mix(Theme.streamPanel, Theme.streamLive, 0.2) : Theme.streamPanel
        border.width: Math.max(1, Theme.u / 2)
        border.color: root.danger ? Theme.danger : Theme.streamLive
        Rectangle {
            width: Theme.u * 2
            height: parent.height
            radius: Theme.u
            color: root.danger ? Theme.danger : Theme.streamLive
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.down && !root.barInk && !root.mac ? Theme.u : 0
        anchors.verticalCenterOffset: root.down && !root.barInk && !root.mac ? Theme.u : 0
        spacing: root.mac ? GoldenGate.px(6) : Theme.u * 3

        MacIcon {
            visible: root.macIcon !== ""
            name: root.macIcon || "circle-help"
            size: GoldenGate.px(15)
            stroke: 1.9
            anchors.verticalCenter: parent.verticalCenter
            color: root.accent || root.checked ? "#ffffff" : root.danger ? GoldenGate.lights[0] : GoldenGate.label
        }
        PxIcon {
            visible: root.icon !== "" && root.macIcon === ""
            name: root.icon || "heart"
            pixel: root.iconPixel
            anchors.verticalCenter: parent.verticalCenter
            ink: root.barInk ? (root.checked ? Theme.hellAccent : Theme.hellBarIcon) : root.hell ? Theme.hellText : root.settingsSkin !== "classic" ? (root.accent || root.checked ? Theme.selectText : Theme.text) : root.accent ? Theme.selectText : (Theme.dark ? Theme.text : Theme.edge)
            bad: root.barInk ? Theme.hellAccent : Theme.danger
            // the hell bar: the outline only, fills dropped (one weight for every icon)
            palette: root.barInk ? ({
                    "o": "none",
                    "x": "none",
                    "y": "none",
                    "w": "none",
                    "f": "none"
                }) : ({})
        }
        PxText {
            visible: root.text !== ""
            text: root.text
            kind: root.kind
            anchors.verticalCenter: parent.verticalCenter
            color: root.barInk ? (root.checked ? Theme.hellAccent : Theme.hellText) : root.hell ? Theme.hellText : root.mac ? (root.accent || root.checked ? "#ffffff" : root.danger ? GoldenGate.lights[0] : GoldenGate.label) : root.settingsSkin !== "classic" ? (root.danger ? "#ffffff" : root.accent || root.checked ? Theme.selectText : Theme.text) : root.accent ? Theme.selectText : root.danger && mouse.containsMouse ? "#ffffff" : Theme.text
            font.bold: root.checked && !root.mac
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton | (root.middleButton ? Qt.MiddleButton : 0)
        cursorShape: Qt.PointingHandCursor
        onClicked: e => {
            if (e.button === Qt.RightButton) {
                root.rightClicked();
                return;
            }
            if (e.button === Qt.MiddleButton) {
                root.middleClicked();
                return;
            }
            if (root.checkable)
                root.checked = !root.checked;
            root.clicked();
        }
    }
}
