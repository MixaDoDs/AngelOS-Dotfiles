pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Networking
import qs.config
import qs.services
import qs.widgets

// Wi-Fi networks and the wired link through NetworkManager.
PxPage {
    id: page

    heading: I18n.t("Сеть и Wi-Fi", "Network and Wi-Fi")
    subtitle: I18n.t("Сети NetworkManager: подключение, пароли, забыть сеть. Список обновляется, пока страница открыта.", "NetworkManager networks: connect, passwords, forget. The list refreshes while this page is open.")

    property string expanded: ""        // network whose password field is open
    Component.onCompleted: Wifi.scanners++
    Component.onDestruction: Wifi.scanners--

    component Bars: Row {
        id: bars
        property int level: 0
        property bool on: true
        spacing: Math.max(1, Theme.u / 2)
        Repeater {
            model: 4
            Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: Theme.u * 2
                height: Theme.u * (2 + index * 2)
                color: index < bars.level ? (bars.on ? Theme.accent : Theme.text) : Qt.alpha(Theme.text, 0.15)
            }
        }
    }

    PxGroup {
        name: "status"
        title: I18n.t("Состояние", "Status")
        icon: "gauge"
        width: parent.width
        PxText {
            visible: !Wifi.available
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: !Wifi.serviceInstalled ? I18n.t("NetworkManager не установлен: установи пакет networkmanager.", "NetworkManager is not installed: install the networkmanager package.") : I18n.t("NetworkManager не запущен — включи службу ниже.", "NetworkManager is not running — start the service below.")
        }
        PxButton {
            visible: !Wifi.available && Wifi.serviceInstalled && !Wifi.serviceActive
            icon: "power"
            accent: true
            text: I18n.t("Включить NetworkManager", "Start NetworkManager")
            onClicked: Wifi.startService()
        }
        SettingRow {
            visible: Wifi.available
            label: I18n.t("Интернет", "Internet")
            PxText {
                text: Wifi.connectivityText
                color: Wifi.online ? Theme.ok : Theme.textDim
            }
        }
        SettingRow {
            visible: !!Wifi.wiredDevice
            label: I18n.t("Кабель", "Ethernet")
            hint: Wifi.wiredDevice ? Wifi.wiredDevice.name : ""
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                text: !Wifi.wiredDevice ? "" : !Wifi.wiredDevice.hasLink ? I18n.t("кабель не подключён", "no cable") : (Wifi.wiredDevice.connected ? I18n.t("подключено", "connected") : I18n.t("есть линк, не подключено", "link up, not connected")) + (Wifi.wiredDevice.linkSpeed ? " · " + Wifi.wiredDevice.linkSpeed + I18n.t(" Мбит/с", " Mb/s") : "") + (Wifi.wiredDevice.address ? " · " + Wifi.wiredDevice.address : "")
            }
        }
    }

    PxGroup {
        name: "wifi"
        visible: Wifi.available
        title: "Wi-Fi"
        icon: Wifi.enabled ? "wifi" : "wifiOff"
        width: parent.width

        PxText {
            visible: !Wifi.hasWifi
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Wi-Fi адаптер не найден. Если он есть — проверь драйвер (ip link) и что он не заблокирован (rfkill list).", "No Wi-Fi adapter found. If there is one, check its driver (ip link) and rfkill list.")
        }
        SettingRow {
            visible: Wifi.hasWifi
            label: I18n.t("Wi-Fi включён", "Wi-Fi on")
            hint: !Wifi.hardwareEnabled ? I18n.t("выключен кнопкой/rfkill на уровне железа", "turned off by a hardware switch / rfkill") : ""
            PxToggle {
                checked: Wifi.enabled
                onToggled: c => Wifi.setEnabled(c)
            }
        }
        PxText {
            visible: Wifi.lastError !== ""
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: "✕ " + Wifi.lastError
        }
        PxText {
            visible: Wifi.hasWifi && Wifi.enabled && Wifi.networks.length === 0
            text: I18n.t("ищу сети… ♡", "Looking for networks… ♡")
            dim: true
        }

        Column {
            visible: Wifi.hasWifi && Wifi.enabled
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: Wifi.networks
                PxBox {
                    id: row
                    required property var modelData
                    readonly property var n: modelData
                    readonly property bool open: page.expanded === n.name
                    readonly property bool busy: n.stateChanging || Wifi.pending === n.name
                    readonly property bool enterprise: [WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap, WifiSecurityType.Wpa3SuiteB192, WifiSecurityType.DynamicWep, WifiSecurityType.Leap].includes(n.security)
                    width: parent.width
                    height: body.implicitHeight + Theme.u * 6
                    sunken: n.connected
                    color: n.connected ? Theme.mix(Theme.sunken, Theme.accent, 0.18) : Qt.alpha(Theme.face, 0.6)

                    Column {
                        id: body
                        x: Theme.u * 4
                        y: Theme.u * 3
                        width: parent.width - Theme.u * 8
                        spacing: Theme.u * 3
                        Item {
                            width: parent.width
                            height: Math.max(nameCol.implicitHeight, actions.implicitHeight)
                            Bars {
                                id: bars
                                anchors.verticalCenter: parent.verticalCenter
                                level: Wifi.bars(row.n.signalStrength)
                                on: row.n.connected
                            }
                            Column {
                                id: nameCol
                                anchors.left: bars.right
                                anchors.leftMargin: Theme.u * 5
                                anchors.right: actions.left
                                anchors.rightMargin: Theme.u * 3
                                anchors.verticalCenter: parent.verticalCenter
                                Row {
                                    spacing: Theme.u * 2
                                    PxText {
                                        text: row.n.name
                                        font.bold: row.n.connected
                                        elide: Text.ElideRight
                                        width: Math.min(implicitWidth, nameCol.width - Theme.u * 12)
                                    }
                                    PxIcon {
                                        visible: Wifi.secured(row.n)
                                        name: "lock"
                                        pixel: Math.max(1, Theme.u - 1)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                PxText {
                                    kind: "tiny"
                                    dim: true
                                    text: (row.busy ? I18n.t("подключаюсь…", "connecting…") : row.n.connected ? I18n.t("подключено", "connected") : row.n.known ? I18n.t("сохранена", "saved") : Wifi.secured(row.n) ? Wifi.securityName(row.n) : I18n.t("открытая", "open")) + " · " + Math.round(row.n.signalStrength * 100) + "%"
                                }
                            }
                            Row {
                                id: actions
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.u * 2
                                PxButton {
                                    compact: true
                                    visible: !row.n.connected
                                    enabled: !row.busy
                                    accent: true
                                    text: I18n.t("Подключить", "Connect")
                                    onClicked: {
                                        if (Wifi.needsPassword(row.n))
                                            page.expanded = row.open ? "" : row.n.name;
                                        else
                                            Wifi.connect(row.n);
                                    }
                                }
                                PxButton {
                                    compact: true
                                    visible: row.n.connected
                                    text: I18n.t("Отключить", "Disconnect")
                                    onClicked: Wifi.disconnect(row.n)
                                }
                                PxButton {
                                    compact: true
                                    visible: row.n.known
                                    icon: "trash"
                                    onClicked: Wifi.forget(row.n)
                                }
                            }
                        }
                        PxText {
                            visible: row.open && row.enterprise
                            width: parent.width
                            wrapMode: Text.Wrap
                            dim: true
                            text: I18n.t("Корпоративная сеть (802.1X) требует логин и сертификат — подключись через nmtui или nm-connection-editor, потом она появится здесь как сохранённая.", "An enterprise (802.1X) network needs a login and certificates — connect once with nmtui or nm-connection-editor, then it shows up here as saved.")
                        }
                        Row {
                            visible: row.open && !row.enterprise
                            width: parent.width
                            spacing: Theme.u * 3
                            PxField {
                                id: psk
                                width: parent.width - go.width - Theme.u * 3
                                password: true
                                icon: "lock"
                                placeholder: I18n.t("пароль сети", "network password")
                                onAccepted: go.clicked()
                            }
                            PxButton {
                                id: go
                                text: "OK"
                                accent: true
                                enabled: psk.text.length >= 8 || row.n.security === WifiSecurityType.StaticWep   // WEP keys can be shorter
                                onClicked: {
                                    Wifi.connect(row.n, psk.text);
                                    psk.text = "";
                                    page.expanded = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
