pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar

// The laptop's battery on the bar as hit points: five hearts (coals while the demon rules,
// Theme.realm), pulsing while it charges, red and blinking low. The percentage next to them
// when asked (Settings → Battery), always in the tooltip and the panel. The panel: the charge,
// the time left, the battery's wear, the power profile, the eco mode and the charge limit.
// Shown only where there is a laptop battery (BarItem).
PxButton {
    id: root

    property bool above: true
    readonly property bool hell: Theme.realm === "hell"
    readonly property bool low: Power.discharging && Power.percent <= Config.power.lowAt
    readonly property bool blink: Power.discharging && Power.percent <= Config.power.veryLowAt && !Motion.calm

    compact: true
    flat: true
    icon: ""
    text: ""
    checked: panel.visible
    implicitWidth: hearts.width + (pct.visible ? pct.implicitWidth + Theme.u * 2 : 0) + (bolt.visible ? bolt.width + Theme.u * 2 : 0) + (hpad >= 0 ? hpad : Theme.u * 6)
    onClicked: panel.toggle()
    onRightClicked: Power.toggleEco()

    Row {
        anchors.centerIn: parent
        spacing: Theme.u * 2
        PxHearts {
            id: hearts
            anchors.verticalCenter: parent.verticalCenter
            count: 5
            pixel: Math.max(1, Theme.u - 1)
            value: Power.percent / 100
            icon: root.hell ? "coal" : "heart"
            fill: root.low ? Theme.danger : root.hell ? Theme.hellAccent : root.barInk ? Theme.hellBarIcon : Theme.accent
            opacity: root.blink ? blinker.value : 1
            scale: Power.charging && !Motion.still ? pulse.value : 1
        }
        PxIcon {
            id: bolt
            visible: Power.charging || Power.holding
            anchors.verticalCenter: parent.verticalCenter
            name: "bolt"
            pixel: Math.max(1, Theme.u - 1)
            fill3: root.barInk ? Theme.hellAccent : Theme.accent3
            opacity: Power.holding ? 0.5 : 1
        }
        PxText {
            id: pct
            visible: Config.power.barPercent
            anchors.verticalCenter: parent.verticalCenter
            text: Power.percent + "%"
            kind: "body"
            color: root.low ? Theme.danger : root.barInk ? Theme.hellText : Theme.text
        }
    }
    // the hearts beat while charging, blink when it is very low (calm motion: neither)
    QtObject {
        id: pulse
        property real value: 1
    }
    SequentialAnimation {
        running: Power.charging && !Motion.still && root.visible
        loops: Animation.Infinite
        onRunningChanged: if (!running)
            pulse.value = 1
        NumberAnimation {
            target: pulse
            property: "value"
            to: 1.12
            duration: 260
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: pulse
            property: "value"
            to: 1
            duration: 420
            easing.type: Easing.InQuad
        }
        PauseAnimation {
            duration: 1300
        }
    }
    QtObject {
        id: blinker
        property real value: 1
    }
    SequentialAnimation {
        running: root.blink && root.visible
        loops: Animation.Infinite
        onRunningChanged: if (!running)
            blinker.value = 1
        NumberAnimation {
            target: blinker
            property: "value"
            to: 0.25
            duration: 500
        }
        NumberAnimation {
            target: blinker
            property: "value"
            to: 1
            duration: 500
        }
        PauseAnimation {
            duration: 700
        }
    }

    BarPopup {
        id: panel
        panelId: "battery"
        anchorItem: root
        above: root.above
        title: I18n.t("Батарея", "Battery")
        icon: "battery"
        contentWidth: Theme.u * 150
        contentHeight: col.implicitHeight
        Column {
            id: col
            width: parent.width
            spacing: Theme.u * 4
            Row {
                spacing: Theme.u * 4
                PxHearts {
                    anchors.verticalCenter: parent.verticalCenter
                    count: 10
                    pixel: Theme.u
                    value: Power.percent / 100
                    icon: root.hell ? "coal" : "heart"
                    fill: root.low ? Theme.danger : root.hell ? Theme.hellAccent : Theme.accent
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Power.percent + " %"
                    kind: "title"
                }
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                text: Power.statusText
            }
            PxText {
                visible: Power.health > 0 || Power.cycles > 0
                width: parent.width
                wrapMode: Text.Wrap
                kind: "tiny"
                dim: true
                text: [Power.health > 0 ? I18n.t("ёмкость " + Power.health + " % от новой", "capacity " + Power.health + "% of new") : "", Power.cycles > 0 ? I18n.t(Power.cycles + " циклов", Power.cycles + " cycles") : "", Power.watts > 0.5 ? Power.watts.toFixed(1) + I18n.t(" Вт", " W") : ""].filter(s => s).join(" · ")
            }
            PxSegmented {
                visible: Power.profilesAvailable
                width: parent.width
                model: [
                    {
                        "label": I18n.t("Эконом", "Saver"),
                        "value": "power-saver"
                    },
                    {
                        "label": I18n.t("Баланс", "Balanced"),
                        "value": "balanced"
                    },
                    {
                        "label": I18n.t("Макс", "Max"),
                        "value": "performance"
                    }
                ]
                currentValue: Power.profile
                onActivated: v => Power.setProfile(v)
            }
            Row {
                spacing: Theme.u * 3
                PxIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "leaf"
                }
                PxToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("Режим экономии", "Eco mode") + (Power.eco && Config.power.eco === "auto" ? " · " + Power.ecoWhy : "")
                    checked: Power.eco
                    onToggled: Power.toggleEco()
                }
            }
            Row {
                visible: Laptop.limitSupported
                spacing: Theme.u * 3
                PxIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "heartSmall"
                    pixel: Theme.u * 2
                }
                PxToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("Заряжать до 80 %", "Charge to 80%")
                    checked: Config.power.chargeLimit < 100
                    onToggled: c => Config.power.chargeLimit = c ? 80 : 100
                }
            }
            PxText {
                visible: Laptop.limitStatus !== ""
                width: parent.width
                wrapMode: Text.Wrap
                kind: "tiny"
                color: Theme.danger
                text: Laptop.limitStatus === "nohelper" ? I18n.t("нужен помощник лимита: Настройки → Батарея", "the limit's helper is missing: Settings → Battery") : Laptop.limitStatus
            }
            PxButton {
                compact: true
                icon: "gear"
                text: I18n.t("Настройки батареи", "Battery settings")
                onClicked: {
                    panel.visible = false;
                    Shell.openSettings("battery");
                }
            }
        }
    }
}
