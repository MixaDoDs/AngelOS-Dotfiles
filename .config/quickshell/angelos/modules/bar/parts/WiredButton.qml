pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar

// The wired connection on the bar (issue #19): cable in or not, internet or
// only a link, and the way to the connection settings.
PxButton {
    id: root

    // screen readers (widgets/A11y.js): what this icon is
    Accessible.name: I18n.t("Проводная сеть", "Wired network")

    property bool above: true
    readonly property var dev: Wifi.wiredDevice
    readonly property bool linked: !!dev && dev.hasLink
    readonly property bool up: !!dev && dev.connected

    compact: true
    flat: true
    icon: "ethernet"
    opacity: up ? 1 : 0.55
    checked: panel.visible
    onClicked: panel.toggle()

    BarPopup {
        id: panel
        panelId: "wired"
        anchorItem: root
        above: root.above
        title: I18n.exe("ethernet")
        icon: "ethernet"
        contentWidth: Theme.u * 130
        contentHeight: col.implicitHeight
        Column {
            id: col
            width: parent.width
            spacing: Theme.u * 3
            Row {
                spacing: Theme.u * 4
                PxIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "ethernet"
                    pixel: Theme.u * 2
                    opacity: root.up ? 1 : 0.5
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    PxText {
                        font.bold: true
                        text: !root.dev ? I18n.t("нет сетевой карты", "no wired adapter") : !root.linked ? I18n.t("кабель не подключён", "cable unplugged") : root.up ? I18n.t("подключено", "connected") : I18n.t("кабель есть, соединения нет", "cable in, not connected")
                    }
                    PxText {
                        visible: root.up
                        text: Wifi.connectivityText
                        kind: "tiny"
                        color: Wifi.online ? Theme.textDim : Theme.danger
                    }
                    PxText {
                        visible: !!root.dev
                        text: root.dev ? root.dev.name || "" : ""
                        kind: "tiny"
                        dim: true
                    }
                }
            }
            PxButton {
                compact: true
                icon: "gear"
                text: I18n.t("Настройки сети", "Network settings")
                onClicked: {
                    panel.visible = false;
                    Shell.openSettings("network");
                }
            }
        }
    }
}
