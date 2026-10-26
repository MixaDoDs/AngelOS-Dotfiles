// The settings once in BluetoothPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// Bluetooth devices through BlueZ; pairing questions come from scripts/bt-agent.py.
CatPage {
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
        color: d.connected ? Theme.mix(Theme.toneFor("sunken", parent), Theme.accent, 0.18) : Qt.alpha(Theme.toneFor("face", parent), 0.6)
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
    CatGroup {
        name: "adapter"
        title: I18n.t("Адаптер", "Adapter")
        icon: "bluetooth"
        present: !Bt.available
        CatNote {
            dim: true
            text: !Bt.serviceInstalled ? I18n.t("BlueZ не установлен: sudo pacman -S bluez bluez-utils", "BlueZ is not installed: sudo pacman -S bluez bluez-utils") : !Bt.serviceActive ? I18n.t("Служба bluetooth выключена.", "The bluetooth service is off.") : I18n.t("Bluetooth-адаптер не найден. Проверь, что он есть и не выключен кнопкой на ноутбуке.", "No Bluetooth adapter found. Check it is there and not switched off by a laptop key.")
        }
        CatCustom {
            wide: true
            CatBox {
                PxButton {
                    visible: Bt.serviceInstalled && !Bt.serviceActive
                    icon: "power"
                    accent: true
                    text: I18n.t("Включить службу bluetooth", "Start the bluetooth service")
                    onClicked: Bt.startService()
                }
            }
        }
    }
    CatGroup {
        name: "power"
        title: Bt.adapter ? Bt.adapter.name || "Bluetooth" : "Bluetooth"
        icon: "bluetooth"
        present: Bt.available
        CatToggle {
            label: I18n.t("Bluetooth включён", "Bluetooth on")
            hint: Bt.blocked ? I18n.t("выключен кнопкой на ноутбуке", "Switched off by a laptop key") : ""
            checked: Bt.enabled
            onToggled: c => Bt.setEnabled(c)
        }
        CatToggle {
            present: Bt.enabled
            label: I18n.t("Искать устройства", "Look for devices")
            hint: I18n.t("переведи устройство в режим сопряжения", "put the device into pairing mode")
            checked: Bt.discovering
            onToggled: c => Bt.scan(c)
        }
        CatNote {
            present: Bt.lastError !== ""
            text: "✕ " + Bt.lastError
        }
    }
    // ---- a pairing question from the agent ----
    CatGroup {
        name: "pairing"
        title: I18n.t("Сопряжение", "Pairing")
        icon: "lock"
        present: !!Bt.request
        CatCustom {
            wide: true
            CatBox {
                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    readonly property var r: Bt.request || ({})
                    text: r.kind === "confirm" ? I18n.t("Совпадает ли код на устройстве «", "Does the code on “") + r.device + I18n.t("»?", "” match?") : r.kind === "display" ? I18n.t("Введи этот код на устройстве «", "Type this code on “") + r.device + "”" : r.kind === "authorize" ? I18n.t("Разрешить «", "Allow “") + r.device + I18n.t("» подключаться?", "” to connect?") : I18n.t("Введи PIN для «", "Enter the PIN for “") + r.device + "”"
                }
            }
        }
        CatNote {
            present: !!Bt.request && !!Bt.request.passkey
            text: Bt.request ? Bt.request.passkey : ""
            textKind: "big"
        }
        CatCustom {
            wide: true
            CatBox {
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
        }
    }
    CatGroup {
        name: "my-devices"
        title: I18n.t("Мои устройства", "My devices")
        icon: "heart"
        present: Bt.available && Bt.enabled
        CatNote {
            present: Bt.paired.length === 0
            text: I18n.t("пока ничего не сопряжено", "Nothing paired yet")
            dim: true
        }
        CatCustom {
            wide: true
            CatBox {
                Column {
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: Bt.paired
                        DeviceRow {}
                    }
                }
            }
        }
    }
    CatGroup {
        name: "nearby"
        title: I18n.t("Рядом", "Nearby")
        icon: "search"
        present: Bt.available && Bt.enabled && (Bt.discovering || Bt.nearby.length > 0)
        CatNote {
            present: Bt.nearby.length === 0
            text: I18n.t("ищу… ♡", "Searching… ♡")
            dim: true
        }
        CatCustom {
            wide: true
            CatBox {
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
    }
}
