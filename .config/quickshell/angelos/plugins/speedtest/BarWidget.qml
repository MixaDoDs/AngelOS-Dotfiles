import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar
import "."

// The panel button. Pixel: a flat PxButton with the gauge icon. Mac (Skin.mac, the Golden Gate
// menu bar): a monochrome line icon in the bar's ink, like a macOS menu bar extra; "…" while
// a test runs. The popup (BarPopup) frames itself for the look.
Item {
    id: root

    property var plugin
    property string screenName
    property var barWindow
    // the pixel bar's hooks (BarItem): its padding and the hell bar's ink go to the button
    property int hpad: -1
    property bool barInk: false
    readonly property string icon: btn.icon
    readonly property string text: btn.text
    readonly property bool barOpen: popup.visible
    readonly property bool mac: Skin.mac

    implicitWidth: mac ? macRow.implicitWidth : btn.implicitWidth
    implicitHeight: mac ? Skin.px(18) : btn.implicitHeight

    PxButton {
        id: btn
        visible: !root.mac
        anchors.fill: parent
        compact: true
        flat: true
        hpad: root.hpad
        barInk: root.barInk
        icon: "gauge"
        text: Speed.running ? "…" : ""
        checked: popup.visible
        onClicked: popup.toggle()
    }

    Row {
        id: macRow
        visible: root.mac
        anchors.centerIn: parent
        spacing: Skin.px(3)
        MacIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "gauge"
            size: Skin.px(16)
            stroke: 2
            color: Skin.ink(root.screenName)
        }
        MacText {
            visible: Speed.running
            anchors.verticalCenter: parent.verticalCenter
            text: "…"
            color: Skin.ink(root.screenName)
        }
    }
    MouseArea {
        visible: root.mac
        anchors.fill: parent
        onClicked: popup.toggle()
    }

    BarPopup {
        id: popup
        panelId: "speedtest"
        anchorItem: root
        above: BarLayout.bottom && !root.mac
        title: Skin.title(Skin.mac ? I18n.t("Спидтест", "Speedtest") : "speedtest")
        icon: "gauge"
        contentWidth: Skin.px(300)
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
