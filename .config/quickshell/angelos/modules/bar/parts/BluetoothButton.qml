pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar

// Bluetooth on the bar (issue #19): on/off, connected devices at a glance, and
// a panel to connect or disconnect paired ones, look for new ones and pair
// (the pairing agent and discovery run only while the panel is open).
PxButton {
    id: root

    // screen readers (widgets/A11y.js): what this icon is
    Accessible.name: "Bluetooth"
    Accessible.description: !Bt.enabled ? I18n.t("выключен", "off") : I18n.t("подключено устройств: ", "devices connected: ") + Bt.connectedDevices.length

    property bool above: true

    compact: true
    flat: true
    icon: Bt.enabled ? "bluetooth" : "bluetoothOff"
    text: Bt.enabled && Bt.connectedDevices.length > 0 ? String(Bt.connectedDevices.length) : ""
    checked: panel.visible
    onClicked: panel.toggle()
    onRightClicked: Bt.setEnabled(!Bt.enabled)

    BarPopup {
        id: panel
        panelId: "bluetooth"
        anchorItem: root
        above: root.above
        title: I18n.exe("bluetooth")
        icon: "bluetooth"
        contentWidth: Theme.u * 150
        contentHeight: Math.min(Theme.u * 190, col.implicitHeight)
        property bool looking: false
        onVisibleChanged: {
            if (visible) {
                Bt.users++;
            } else {
                Bt.users = Math.max(0, Bt.users - 1);
                looking = false;
            }
        }
        onLookingChanged: Bt.scan(looking)

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
                        enabled: Bt.available
                        checked: Bt.enabled
                        onToggled: c => Bt.setEnabled(c)
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.u * 40
                        elide: Text.ElideRight
                        font.bold: true
                        text: !Bt.available ? I18n.t("нет адаптера или службы bluetooth", "no adapter or bluetooth service") : !Bt.enabled ? I18n.t("Bluetooth выключен", "Bluetooth is off") : Bt.connectedDevices.length ? I18n.t("подключено: ", "connected: ") + Bt.connectedDevices.length : I18n.t("ничего не подключено", "nothing connected")
                    }
                }
                PxText {
                    visible: Bt.lastError !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: Bt.lastError
                    kind: "tiny"
                    color: Theme.danger
                }

                // the pairing question from the agent
                Column {
                    visible: !!Bt.request
                    width: parent.width
                    spacing: Theme.u * 2
                    readonly property var r: Bt.request || ({})
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: parent.r.kind === "confirm" ? I18n.t("Совпадает код на «", "Does the code on “") + parent.r.device + I18n.t("»?", "” match?") : parent.r.kind === "display" ? I18n.t("Введи код на «", "Type this code on “") + parent.r.device + "”" : parent.r.kind === "authorize" ? I18n.t("Пустить «", "Allow “") + parent.r.device + I18n.t("»?", "”?") : I18n.t("PIN для «", "PIN for “") + parent.r.device + "”"
                    }
                    PxText {
                        visible: !!parent.r.passkey
                        text: parent.r.passkey || ""
                        kind: "big"
                        color: Theme.accent
                    }
                    Row {
                        spacing: Theme.u * 2
                        PxField {
                            id: pin
                            visible: !!Bt.request && (Bt.request.kind === "pin" || Bt.request.kind === "passkey")
                            width: Theme.u * 60
                            keepFocus: true
                            placeholder: "PIN"
                            onAccepted: yes.clicked()
                        }
                        PxButton {
                            id: yes
                            visible: !!Bt.request && Bt.request.kind !== "display"
                            compact: true
                            accent: true
                            text: I18n.t("Да", "Yes")
                            onClicked: {
                                Bt.answer(true, pin.text);
                                pin.text = "";
                            }
                        }
                        PxButton {
                            compact: true
                            text: !!Bt.request && Bt.request.kind === "display" ? "OK" : I18n.t("Нет", "No")
                            onClicked: Bt.answer(false)
                        }
                    }
                }

                // paired: click connects or disconnects
                Repeater {
                    model: Bt.enabled ? Bt.paired : []
                    PxButton {
                        id: dev
                        required property var modelData
                        width: col.width
                        flat: true
                        checked: modelData.connected
                        onClicked: Bt.toggleConnect(dev.modelData)
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.u * 3
                            spacing: Theme.u * 3
                            PxIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: Bt.iconFor(dev.modelData)
                            }
                            PxText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: col.width - Theme.u * 26
                                elide: Text.ElideRight
                                font.bold: dev.modelData.connected
                                text: (dev.modelData.name || dev.modelData.deviceName || dev.modelData.address) + (dev.modelData.connected ? (dev.modelData.batteryAvailable ? "  · " + Math.round(dev.modelData.battery * 100) + "%" : "") : dev.modelData.state === BluetoothDeviceState.Connecting ? I18n.t("  · подключаю…", "  · connecting…") : "")
                            }
                        }
                    }
                }
                PxText {
                    visible: Bt.enabled && Bt.paired.length === 0 && !panel.looking
                    text: I18n.t("пока ничего не сопряжено", "nothing paired yet")
                    dim: true
                }

                // new devices
                PxButton {
                    visible: Bt.enabled
                    compact: true
                    icon: "search"
                    checked: panel.looking
                    text: panel.looking ? I18n.t("Ищу… (стоп)", "Looking… (stop)") : I18n.t("Найти новые", "Find new ones")
                    onClicked: panel.looking = !panel.looking
                }
                Repeater {
                    model: Bt.enabled && panel.looking ? Bt.nearby.slice(0, 10) : []
                    PxButton {
                        id: fresh
                        required property var modelData
                        width: col.width
                        flat: true
                        onClicked: Bt.pair(fresh.modelData)
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.u * 3
                            spacing: Theme.u * 3
                            PxIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: Bt.iconFor(fresh.modelData)
                            }
                            PxText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: col.width - Theme.u * 26
                                elide: Text.ElideRight
                                text: (fresh.modelData.name || fresh.modelData.deviceName) + (fresh.modelData.pairing ? I18n.t("  · сопрягаю…", "  · pairing…") : I18n.t("  · сопрячь", "  · pair"))
                            }
                        }
                    }
                }
                PxButton {
                    compact: true
                    icon: "gear"
                    text: I18n.t("Настройки Bluetooth", "Bluetooth settings")
                    onClicked: {
                        panel.visible = false;
                        Shell.openSettings("bluetooth");
                    }
                }
            }
        }
    }
}
