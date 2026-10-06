import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar
import "."

// The cat on the panel. Pixel: the pixel cat (the Cerberus while the demon rules). Mac look
// (Skin.mac: the Golden Gate menu bar): a smooth one-colour cat in the bar's ink, like a menu
// bar extra, and its popup a glass popover (BarPopup). Sizes and colours: the Theme API (Skin).
Item {
    id: root

    property var plugin
    property string screenName
    property var barWindow
    readonly property bool showPercent: plugin ? plugin.get("showPercent", false) : false
    // the hell bar draws the Cerberus as he is (his colours are made for the dark plates)
    // instead of tinting him; the popup open is the state the bar shows
    property bool hellBar: false
    readonly property bool barOpen: popup.visible

    Component.onCompleted: if (plugin)
        Cpu.intervalMs = plugin.get("poll", 2) * 1000
    readonly property bool mac: Skin.mac
    implicitWidth: row.implicitWidth + (mac ? Skin.px(4) : Theme.u * 4)
    implicitHeight: mac ? Skin.px(18) : Theme.u * 13

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Skin.px(4)
        CatSprite {
            anchors.verticalCenter: parent.verticalCenter
            plugin: root.plugin
            // the Mac cat is 8 × this tall: 16 pt at size ×1, like the menu bar's icons
            pixel: root.mac ? Math.max(1, GoldenGate.px(2) * (root.plugin ? root.plugin.get("size", 1) : 1)) : Math.max(1, Math.round(Theme.u * (root.plugin ? root.plugin.get("size", 1) : 1)))
            ink: root.mac ? Skin.ink(root.screenName) : fur
        }
        PxText {
            visible: root.showPercent
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Cpu.percent) + "%"
            kind: "tiny"
            color: root.mac ? Skin.ink(root.screenName) : root.hellBar ? Theme.hellText : Theme.text
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.toggle()
    }

    BarPopup {
        id: popup
        panelId: "cat"
        anchorItem: root
        above: BarLayout.bottom
        title: Skin.title(Angel.demon && !root.mac ? I18n.t("цербер", "cerberus") : root.mac ? I18n.t("Котик", "Cat") : I18n.t("котик", "cat"))
        icon: "heart"
        contentWidth: Skin.px(240)
        contentHeight: Skin.px(140)

        Column {
            anchors.centerIn: parent
            spacing: Skin.px(8)
            CatSprite {
                anchors.horizontalCenter: parent.horizontalCenter
                plugin: root.plugin
                pixel: root.mac ? GoldenGate.px(6) : Theme.u * 4
            }
            PxText {
                anchors.horizontalCenter: parent.horizontalCenter
                kind: "title"
                text: "CPU " + Math.round(Cpu.percent) + "%"
            }
            PxText {
                anchors.horizontalCenter: parent.horizontalCenter
                dim: true
                readonly property int pace: Cpu.percent < (root.plugin ? root.plugin.get("walk", 15) : 15) ? 0 : Cpu.percent < (root.plugin ? root.plugin.get("run", 60) : 60) ? 1 : 2
                text: root.mac ? [I18n.t("Спит", "Sleeping"), I18n.t("Гуляет", "Walking"), I18n.t("Бежит", "Running")][pace] : Angel.demon ? [I18n.t("дремлет… zzz ×3", "Dozing… zzz ×3"), I18n.t("рыщет по процессам", "Prowling the processes"), I18n.t("ГОНИТСЯ ЗА ДУШАМИ!!", "CHASING SOULS!!")][pace] : [I18n.t("спит… zzz", "Sleeping… zzz"), I18n.t("гуляет ♡", "Walking ♡"), I18n.t("БЕЖИТ!!", "RUNNING!!")][pace]
            }
        }
    }
}
