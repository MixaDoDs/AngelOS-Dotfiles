import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar
import "."

// The small face on the panel; in the Golden Gate menu bar one colour, the bar's ink. A click
// opens limits and sessions, as Claude Companion did; the limit left can stand beside her.
Item {
    id: root
    property var plugin
    property string screenName
    property var barWindow
    property bool hellBar: false
    readonly property bool barOpen: popup.visible
    readonly property string limitMode: plugin ? plugin.get("barLimit", "off") : "off"
    readonly property bool mac: Skin.mac

    implicitWidth: row.implicitWidth + (mac ? Skin.px(4) : 0)
    implicitHeight: mac ? Skin.px(23) : Theme.u * 13

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Skin.px(4)
        Face {
            width: root.mac ? Skin.px(23) : Theme.u * 13
            height: width
            anchors.verticalCenter: parent.verticalCenter
            plugin: root.plugin
            screenName: root.screenName
            look: "bar"
            mono: root.mac
            monoColor: Skin.ink(root.screenName)
        }
        PxText {
            visible: root.limitMode !== "off"
            anchors.verticalCenter: parent.verticalCenter
            text: !Usage.ok ? "—" : root.limitMode === "week" ? Usage.weekLeft + "%" : root.limitMode === "both" ? Usage.fiveLeft + "·" + Usage.weekLeft : Usage.fiveLeft + "%"
            readonly property real remaining: root.limitMode === "week" ? Usage.weekLeft : Math.min(Usage.fiveLeft, Usage.weekLeft)
            color: root.mac ? (Usage.ok && remaining < 20 ? Skin.danger : Skin.ink(root.screenName)) : root.hellBar ? (remaining < 20 ? Theme.hellAccent : Theme.hellText) : Usage.colorFor(remaining, Theme)
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
        panelId: "celestia"
        anchorItem: root
        above: BarLayout.bottom && !root.mac
        title: Skin.title(Skin.mac ? "Селестия" : "celestia")
        icon: "heart"
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
