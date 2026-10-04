pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.widgets

// Bluetooth devices through BlueZ; pairing questions come from scripts/bt-agent.py.
PxPage {
    id: page

    heading: "Bluetooth"
    subtitle: I18n.t("Наушники, геймпады, клавиатуры, телефоны. Поиск идёт, пока страница открыта и включён переключатель.", "Headphones, gamepads, keyboards, phones. Discovery runs while this page is open and the switch is on.")

    Component.onCompleted: Bt.users++
    Component.onDestruction: Bt.users--

    component DeviceRow: PxBox {
        id: dev
        required property var modelData
        readonly property var d: modelData
        readonly property bool busy: d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting
        width: parent ? parent.width : 0
        height: Theme.u * 18
        sunken: d.connected
        color: d.connected ? Theme.mix(Theme.sunken, Theme.accent, 0.18) : Qt.alpha(Theme.face, 0.6)
        PxIcon {
            id: ico
            x: Theme.u * 4
            anchors.verticalCenter: parent.verticalCenter
            name: Bt.iconFor(dev.d)
        }
        Column {
            anchors.left: ico.right
            anchors.leftMargin: Theme.u * 4
            anchors.right: acts.left
            anchors.rightMargin: Theme.u * 3
            anchors.verticalCenter: parent.verticalCenter
            PxText {
                width: parent.width
                elide: Text.ElideRight
                text: dev.d.name || dev.d.deviceName || dev.d.address
                font.bold: dev.d.connected
            }
            PxText {
                kind: "tiny"
                dim: true
                text: (dev.d.pairing ? I18n.t("сопрягаю…", "pairing…") : dev.busy ? I18n.t("подключаюсь…", "connecting…") : dev.d.connected ? I18n.t("подключено", "connected") : dev.d.paired ? I18n.t("сопряжено", "paired") : dev.d.address) + (dev.d.batteryAvailable ? " · ♥ " + Math.round(dev.d.battery * 100) + "%" : "")
            }
        }
        Row {
            id: acts
            anchors.right: parent.right
            anchors.rightMargin: Theme.u * 3
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.u * 2
            PxButton {
                compact: true
                visible: !dev.d.paired && !dev.d.bonded
                enabled: !dev.d.pairing
                accent: true
                text: I18n.t("Сопрячь", "Pair")
                onClicked: Bt.pair(dev.d)
            }
            PxButton {
                compact: true
                visible: dev.d.paired || dev.d.bonded
                enabled: !dev.busy
                text: dev.d.connected ? I18n.t("Отключить", "Disconnect") : I18n.t("Подключить", "Connect")
                accent: !dev.d.connected
                onClicked: Bt.toggleConnect(dev.d)
            }
            PxButton {
                compact: true
                visible: dev.d.paired || dev.d.bonded
                icon: "trash"
                onClicked: Bt.forget(dev.d)
            }
        }
    }

    // ---- no adapter / service off ----
    PxGroup {
        name: "adapter"
        visible: !Bt.available
        title: I18n.t("Адаптер", "Adapter")
        icon: "bluetooth"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: !Bt.serviceInstalled ? I18n.t("BlueZ не установлен: sudo pacman -S bluez bluez-utils", "BlueZ is not installed: sudo pacman -S bluez bluez-utils") : !Bt.serviceActive ? I18n.t("Служба bluetooth выключена.", "The bluetooth service is off.") : I18n.t("Bluetooth-адаптер не найден. Проверь, что он есть и не заблокирован (rfkill list).", "No Bluetooth adapter found. Check that there is one and it is not blocked (rfkill list).")
        }
        PxButton {
            visible: Bt.serviceInstalled && !Bt.serviceActive
            icon: "power"
            accent: true
            text: I18n.t("Включить службу bluetooth", "Start the bluetooth service")
            onClicked: Bt.startService()
        }
    }

    PxGroup {
        name: "power"
        visible: Bt.available
        title: Bt.adapter ? Bt.adapter.name || "Bluetooth" : "Bluetooth"
        icon: "bluetooth"
        width: parent.width
        SettingRow {
            label: I18n.t("Bluetooth включён", "Bluetooth on")
            hint: Bt.blocked ? I18n.t("заблокирован rfkill", "blocked by rfkill") : ""
            PxToggle {
                checked: Bt.enabled
                onToggled: c => Bt.setEnabled(c)
            }
        }
        SettingRow {
            visible: Bt.enabled
            label: I18n.t("Искать устройства", "Look for devices")
            hint: I18n.t("переведи устройство в режим сопряжения", "put the device into pairing mode")
            PxToggle {
                checked: Bt.discovering
                onToggled: c => Bt.scan(c)
            }
        }
        PxText {
            visible: Bt.lastError !== ""
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: "✕ " + Bt.lastError
        }
    }

    // ---- a pairing question from the agent ----
    PxGroup {
        name: "pairing"
        visible: !!Bt.request
        title: I18n.t("Сопряжение", "Pairing")
        icon: "lock"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            readonly property var r: Bt.request || ({})
            text: r.kind === "confirm" ? I18n.t("Совпадает ли код на устройстве «", "Does the code on “") + r.device + I18n.t("»?", "” match?") : r.kind === "display" ? I18n.t("Введи этот код на устройстве «", "Type this code on “") + r.device + "”" : r.kind === "authorize" ? I18n.t("Разрешить «", "Allow “") + r.device + I18n.t("» подключаться?", "” to connect?") : I18n.t("Введи PIN для «", "Enter the PIN for “") + r.device + "”"
        }
        PxText {
            visible: !!Bt.request && !!Bt.request.passkey
            text: Bt.request ? Bt.request.passkey : ""
            kind: "big"
            color: Theme.accent
        }
        Row {
            spacing: Theme.u * 3
            PxField {
                id: pin
                visible: !!Bt.request && (Bt.request.kind === "pin" || Bt.request.kind === "passkey")
                width: Theme.u * 60
                placeholder: "PIN"
                onAccepted: yes.clicked()
            }
            PxButton {
                id: yes
                visible: !!Bt.request && Bt.request.kind !== "display"
                accent: true
                text: I18n.t("Да", "Yes")
                onClicked: {
                    Bt.answer(true, pin.text);
                    pin.text = "";
                }
            }
            PxButton {
                text: !!Bt.request && Bt.request.kind === "display" ? "OK" : I18n.t("Нет", "No")
                onClicked: Bt.answer(false)
            }
        }
    }

    PxGroup {
        name: "my-devices"
        visible: Bt.available && Bt.enabled
        title: I18n.t("Мои устройства", "My devices")
        icon: "heart"
        width: parent.width
        PxText {
            visible: Bt.paired.length === 0
            text: I18n.t("пока ничего не сопряжено", "Nothing paired yet")
            dim: true
        }
        Column {
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: Bt.paired
                DeviceRow {}
            }
        }
    }

    PxGroup {
        name: "nearby"
        visible: Bt.available && Bt.enabled && (Bt.discovering || Bt.nearby.length > 0)
        title: I18n.t("Рядом", "Nearby")
        icon: "search"
        width: parent.width
        PxText {
            visible: Bt.nearby.length === 0
            text: I18n.t("ищу… ♡", "Searching… ♡")
            dim: true
        }
        Column {
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: Bt.nearby
                DeviceRow {}
            }
        }
    }
}
