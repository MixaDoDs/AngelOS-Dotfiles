pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar

// The charge of the mouse, the keyboard, the headphones on the bar: an ampoule a device, as
// tall as the bar (services/Peripherals, widgets/PxAmpouleRack; Settings → Devices → Device
// charge). The panel names them, with the numbers; a right click asks the devices now. Shown
// only where a device reports its charge (BarItem).
PxButton {
    id: root

    // screen readers (widgets/A11y.js): what these are
    Accessible.name: I18n.t("Заряд беспроводных", "Wireless charge")
    Accessible.description: Peripherals.shown.map(d => d.name + " " + d.percent + "%" + (d.charging ? I18n.t(", заряжается", ", charging") : "")).join("; ")

    property bool above: true
    // a taskbar on a side edge (BarItem): one under another
    property bool vertical: false
    // the bar's cell is `height`; the ampoules take what is left of it above the shelf
    readonly property int fit: vertical ? 13 : Math.max(9, Math.min(15, Math.floor(height / Theme.u) - 2))

    compact: true
    flat: true
    icon: ""
    text: ""
    checked: pop.visible
    implicitWidth: rack.implicitWidth + (hpad >= 0 ? hpad : Theme.u * 6)
    implicitHeight: vertical ? rack.implicitHeight + Theme.u * 6 : Theme.u * 15
    onClicked: pop.toggle()
    onRightClicked: Peripherals.refresh()

    PxAmpouleRack {
        id: rack
        anchors.centerIn: parent
        devices: Peripherals.onBar
        rows: root.fit
        vertical: root.vertical
        barInk: root.barInk
    }

    // built when the pointer comes to the button, gone a while after it closed (LazyPopup)
    LazyPopup {
        id: pop
        panelId: "peripherals"
        anchorItem: root
        warm: root.hovered
        BarPopup {
            id: panel
            panelId: "peripherals"
            anchorItem: root
            above: root.above
            title: I18n.t("Заряд беспроводных", "Wireless charge")
            icon: "ampoule"
            contentWidth: Theme.u * 150
            contentHeight: col.implicitHeight
            onVisibleChanged: if (visible)
                Peripherals.refresh()
            Column {
                id: col
                width: parent.width
                spacing: Theme.u * 4
                Repeater {
                    model: Peripherals.shown
                    Item {
                        id: line
                        required property var modelData
                        width: col.width
                        height: Math.max(big.height, words.implicitHeight)
                        PxAmpoule {
                            id: big
                            pixel: Math.max(2, Math.round(Theme.u * 1.5))
                            rows: 13
                            value: line.modelData.percent / 100
                            charging: line.modelData.charging
                            asleep: line.modelData.asleep
                            low: line.modelData.level !== "ok"
                            stops: Peripherals.stops
                            paint: Config.peripherals.paint
                            steps: Config.peripherals.steps
                            glint: Config.peripherals.glint
                            bubbles: Config.peripherals.bubbles
                        }
                        Column {
                            id: words
                            anchors.left: big.right
                            anchors.leftMargin: Theme.u * 5
                            anchors.right: number.left
                            anchors.rightMargin: Theme.u * 3
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.u
                            Row {
                                spacing: Theme.u * 2
                                PxIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: Peripherals.kindIcon(line.modelData.kind)
                                    opacity: line.modelData.asleep ? 0.45 : 1
                                }
                                PxText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, words.width - Theme.u * 18)
                                    elide: Text.ElideRight
                                    font.bold: true
                                    text: line.modelData.name
                                }
                            }
                            PxText {
                                width: parent.width
                                wrapMode: Text.Wrap
                                kind: "tiny"
                                dim: line.modelData.level === "ok" || line.modelData.asleep
                                color: line.modelData.level !== "ok" && !line.modelData.asleep ? Theme.danger : Theme.textDim
                                text: Peripherals.statusText(line.modelData)
                            }
                        }
                        PxText {
                            id: number
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            kind: "title"
                            opacity: line.modelData.asleep ? 0.45 : 1
                            text: line.modelData.percent + " %"
                        }
                    }
                }
                PxText {
                    visible: Peripherals.shown.length === 0
                    width: parent.width
                    wrapMode: Text.Wrap
                    dim: true
                    text: I18n.t("Ни одно устройство не сообщает заряд.", "No device reports its charge.")
                }
                Row {
                    spacing: Theme.u * 3
                    PxButton {
                        compact: true
                        icon: "refresh"
                        text: I18n.t("Опросить", "Ask now")
                        onClicked: Peripherals.refresh()
                    }
                    PxButton {
                        compact: true
                        icon: "gear"
                        text: I18n.t("Настройки", "Settings")
                        onClicked: {
                            panel.visible = false;
                            Shell.openSettings("peripherals");
                        }
                    }
                    // the devices themselves: key travel live, Rapid Trigger (services/Devices)
                    PxButton {
                        compact: true
                        icon: "chip"
                        text: I18n.t("Драйвер", "Driver")
                        onClicked: {
                            panel.visible = false;
                            Shell.openSettings("driver");
                        }
                    }
                }
            }
        }
    }
}
