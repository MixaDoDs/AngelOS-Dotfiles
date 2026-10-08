pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar

// Wi-Fi on the bar (issue #19): signal bars, and a panel to switch Wi-Fi,
// pick a network (password right there), disconnect. Scans only while open.
PxButton {
    id: root

    // screen readers (widgets/A11y.js): what this icon is
    Accessible.name: "Wi-Fi"
    Accessible.description: !Wifi.enabled ? I18n.t("выключен", "off") : !Wifi.connected ? I18n.t("не подключён", "not connected") : I18n.t("подключён", "connected")

    property bool above: true

    compact: true
    flat: true
    icon: !Wifi.enabled ? "wifiOff" : !Wifi.connected ? "wifiOff" : ["wifi1", "wifi1", "wifi2", "wifi", "wifi"][Wifi.bars(Wifi.strength)]
    checked: panel.visible
    onClicked: panel.toggle()
    onRightClicked: Wifi.setEnabled(!Wifi.enabled)

    BarPopup {
        id: panel
        panelId: "wifi"
        anchorItem: root
        above: root.above
        title: I18n.exe("wi-fi")
        icon: "wifi"
        contentWidth: Theme.u * 150
        contentHeight: Math.min(Theme.u * 190, col.implicitHeight)
        onVisibleChanged: {
            if (visible)
                Wifi.scanners++;
            else
                Wifi.scanners = Math.max(0, Wifi.scanners - 1);
            asking = null;
        }
        property var asking: null           // the secured network waiting for its password

        Flickable {
            anchors.fill: parent
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: col
                width: parent.width
                spacing: Theme.u * 3

                Row {
                    width: parent.width
                    spacing: Theme.u * 3
                    PxToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Wifi.enabled
                        onToggled: c => Wifi.setEnabled(c)
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.u * 40
                        PxText {
                            width: parent.width
                            elide: Text.ElideRight
                            font.bold: true
                            text: !Wifi.hardwareEnabled ? I18n.t("выключен кнопкой / в BIOS", "switched off in hardware") : !Wifi.enabled ? I18n.t("Wi-Fi выключен", "Wi-Fi is off") : Wifi.connected ? Wifi.connected.name : I18n.t("не подключено", "not connected")
                        }
                        PxText {
                            visible: Wifi.enabled && !!Wifi.connected
                            text: Wifi.connectivityText + " · " + Math.round(Wifi.strength * 100) + "%"
                            kind: "tiny"
                            dim: true
                        }
                    }
                }
                PxText {
                    visible: Wifi.lastError !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: Wifi.lastError
                    kind: "tiny"
                    color: Theme.danger
                }

                // password for the picked network
                Column {
                    visible: !!panel.asking
                    width: parent.width
                    spacing: Theme.u * 2
                    PxText {
                        width: parent.width
                        elide: Text.ElideRight
                        text: I18n.t("Пароль для «", "Password for “") + (panel.asking ? panel.asking.name : "") + I18n.t("»", "”")
                    }
                    Row {
                        spacing: Theme.u * 2
                        PxField {
                            id: psk
                            width: col.width - Theme.u * 30
                            password: true
                            keepFocus: true
                            placeholder: "••••••••"
                            onAccepted: join.clicked()
                        }
                        PxButton {
                            id: join
                            compact: true
                            accent: true
                            icon: "check"
                            onClicked: {
                                Wifi.connect(panel.asking, psk.text);
                                psk.text = "";
                                panel.asking = null;
                            }
                        }
                    }
                }

                Repeater {
                    model: Wifi.enabled ? Wifi.networks.slice(0, 12) : []
                    PxButton {
                        id: net
                        required property var modelData
                        width: col.width
                        flat: true
                        checked: modelData.connected
                        onClicked: {
                            if (net.modelData.connected)
                                return;
                            if (Wifi.needsPassword(net.modelData)) {
                                panel.asking = net.modelData;
                                Qt.callLater(() => psk.focusField());
                            } else {
                                Wifi.connect(net.modelData);
                            }
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.u * 3
                            spacing: Theme.u * 3
                            PxIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: ["wifi1", "wifi1", "wifi2", "wifi", "wifi"][Wifi.bars(net.modelData.signalStrength)]
                            }
                            PxText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: col.width - Theme.u * 58
                                elide: Text.ElideRight
                                text: net.modelData.name + (Wifi.pending === net.modelData.name ? I18n.t("  · подключаю…", "  · connecting…") : "")
                                font.bold: net.modelData.connected
                            }
                            PxIcon {
                                visible: Wifi.secured(net.modelData)
                                anchors.verticalCenter: parent.verticalCenter
                                name: "lock"
                                pixel: Math.max(1, Theme.u - 1)
                            }
                        }
                        // the connected one: disconnect
                        PxButton {
                            visible: net.modelData.connected
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.u * 2
                            anchors.verticalCenter: parent.verticalCenter
                            compact: true
                            icon: "close"
                            onClicked: Wifi.disconnect(net.modelData)
                        }
                    }
                }
                PxText {
                    visible: Wifi.enabled && Wifi.networks.length === 0
                    text: I18n.t("ищу сети…", "looking for networks…")
                    dim: true
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
}
