import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar
import "."

// Codex on the panel. Pixel: the pixel mascot. Mac look (Skin.mac, the Golden Gate menu bar):
// the "terminal" line icon and the numbers in the bar's ink, the popup a glass popover.
Item {
    id: root

    property var plugin
    property string screenName
    property var barWindow

    readonly property string mode: plugin ? plugin.get("barLimit", "auto") : "auto"   // auto | five | week | today | off
    readonly property string label: {
        if (mode === "off" || CodexState.status !== "ok")
            return "";
        if (mode === "today" || (mode === "auto" && !CodexState.hasLimits))
            return CodexState.tokens(CodexState.today.total_tokens);
        if (mode === "week")
            return CodexState.weekLeft >= 0 ? CodexState.weekLeft + "%" : "—";
        return CodexState.fiveLeft >= 0 ? CodexState.fiveLeft + "%" : (CodexState.weekLeft >= 0 ? CodexState.weekLeft + "%" : "—");
    }
    visible: !plugin || plugin.get("barAlways", true) || CodexState.state !== "none"
    readonly property bool mac: Skin.mac
    implicitWidth: visible ? row.implicitWidth + (mac ? Skin.px(4) : Theme.u * 4) : 0
    implicitHeight: mac ? Skin.px(18) : Theme.u * 13

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Skin.px(4)
        Mascot {
            anchors.verticalCenter: parent.verticalCenter
            pixel: root.mac ? GoldenGate.px(2) : Theme.u
            mono: root.mac
            monoColor: Skin.ink(root.screenName)
        }
        PxText {
            visible: root.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            readonly property real remaining: root.mode === "week" ? CodexState.weekLeft : CodexState.fiveLeft
            color: root.mac ? (CodexState.hasLimits && root.mode !== "today" && remaining >= 0 && remaining < 20 ? Skin.danger : Skin.ink(root.screenName)) : CodexState.hasLimits && root.mode !== "today" ? CodexState.colorFor(remaining, Theme) : Theme.text
            font.bold: !root.mac
        }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => {
            panel.tab = m.button === Qt.RightButton ? "sessions" : m.button === Qt.MiddleButton ? "ask" : "limits";
            if (!popup.visible)
                CodexState.refresh();
            popup.toggle();
        }
    }

    BarPopup {
        id: popup
        panelId: "codex"
        anchorItem: root
        above: BarLayout.bottom && !root.mac
        title: Skin.title(Skin.mac ? "Codex" : "codex")
        icon: "terminal"
        contentWidth: Skin.px(380)
        contentHeight: Skin.px(380)
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
