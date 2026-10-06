import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar
import "."

// Claude on the panel: the mascot, and the limit left when asked. Pixel: the pixel face. Mac
// look (Skin.mac, the Golden Gate menu bar): the "bot" line icon in the bar's ink with a state
// dot, the numbers in the bar's ink (red when the limit runs low); the popup a glass popover.
Item {
    id: root

    property var plugin
    property string screenName
    property var barWindow

    readonly property string limitMode: plugin ? plugin.get("barLimit", "off") : "off"   // five | week | both | off
    // the hell bar draws the mask itself (Breath.barLook) instead of tinting it; the popup
    // open is the state the bar shows
    property bool hellBar: false
    readonly property bool barOpen: popup.visible
    visible: !plugin || plugin.get("barAlways", true) || Pulse.state !== "none"
    readonly property bool mac: Skin.mac
    implicitWidth: visible ? (mac ? row.implicitWidth + Skin.px(4) : Theme.u * (limitMode === "off" ? 14 : limitMode === "both" ? 50 : 32)) : 0
    implicitHeight: mac ? Skin.px(18) : Theme.u * 13

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Skin.px(4)
        Breath {
            anchors.verticalCenter: parent.verticalCenter
            plugin: root.plugin
            barLook: root.hellBar
            pixel: root.mac ? GoldenGate.px(2) : Theme.u
            mono: root.mac
            monoColor: Skin.ink(root.screenName)
        }
        PxText {
            visible: root.limitMode !== "off"
            width: root.mac ? undefined : Theme.u * (root.limitMode === "both" ? 36 : 18)   // natural in the Mac look
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            text: !Usage.ok ? "—" : root.limitMode === "week" ? Usage.weekLeft + "%" : root.limitMode === "both" ? Usage.fiveLeft + "% · " + Usage.weekLeft + "%" : Usage.fiveLeft + "%"
            readonly property real remaining: root.limitMode === "week" ? Usage.weekLeft : Math.min(Usage.fiveLeft, root.limitMode === "both" ? Usage.weekLeft : 100)
            // the hell bar: the text colour, the accent once the limit runs low (a state)
            color: root.mac ? (Usage.ok && remaining < 20 ? Skin.danger : Skin.ink(root.screenName)) : root.hellBar ? (Usage.ok && remaining < 20 ? Theme.hellAccent : Theme.hellText) : Usage.colorFor(remaining, Theme)
            font.bold: !root.mac
        }
        PxText {
            visible: root.limitMode !== "off" && (Pulse.state === "needs_attention" || Pulse.state === "error")
            anchors.verticalCenter: parent.verticalCenter
            width: root.mac ? undefined : Theme.u * 5
            text: "!"
            kind: "tiny"
            color: root.mac ? Skin.danger : root.hellBar ? Theme.hellAccent : Pulse.colorFor(Pulse.state, Theme)
        }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => {
            panel.tab = m.button === Qt.RightButton ? "sessions" : m.button === Qt.MiddleButton ? "ask" : "limits";
            if (!popup.visible)
                Usage.refresh(true);
            popup.toggle();
        }
    }

    BarPopup {
        id: popup
        panelId: "claude"
        anchorItem: root
        above: BarLayout.bottom && !root.mac
        title: Skin.title(Skin.mac ? "Claude" : "claude")
        icon: "bot"
        contentWidth: Skin.px(380)
        contentHeight: Skin.px(410)
        PxScroll {
            anchors.fill: parent
            contentHeight: panel.implicitHeight
            Panel {
                id: panel
                width: parent.width
                plugin: root.plugin
            }
        }
    }
}
