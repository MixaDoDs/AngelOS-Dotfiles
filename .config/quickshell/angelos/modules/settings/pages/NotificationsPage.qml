import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

PxPage {
    heading: I18n.t("Уведомления", "Notifications")

    PxGroup {
        name: "behavior"
        title: I18n.t("Как показывать", "How they show")
        icon: "bell"
        width: parent.width
        SettingRow {
            label: I18n.t("Не беспокоить", "Do not disturb")
            hint: I18n.t("критичные всё равно покажутся", "Critical notifications still appear")
            PxToggle {
                checked: Config.notifications.dnd
                onToggled: c => Config.notifications.dnd = c
            }
        }
        SettingRow {
            label: I18n.t("Сколько висят", "How long they stay")
            PxSlider {
                width: parent.width
                from: 2000
                to: 20000
                stepSize: 500
                value: Config.notifications.timeout
                valueScale: 0.001
                decimals: 1
                suffix: I18n.t(" с", " s")
                onMoved: v => Config.notifications.timeout = v
            }
        }
        SettingRow {
            label: I18n.t("Максимум карточек", "Maximum cards")
            PxSpin {
                from: 1
                to: 8
                value: Config.notifications.maxPopups
                onMoved: v => Config.notifications.maxPopups = v
            }
        }
        SettingRow {
            label: I18n.t("Где показывать", "Show on")
            PxPositionPicker {
                value: Config.notifications.position
                onPicked: v => Config.notifications.position = v
            }
        }
        SettingRow {
            label: I18n.t("Монитор", "Monitor")
            hint: I18n.t("где фокус, на главном экране (страница «Монитор») или на выбранном", "The focused display, the main one (Monitor page) or a fixed one")
            PxCombo {
                width: Theme.u * 100
                model: [
                    {
                        "label": I18n.t("где фокус", "Focused display"),
                        "value": ""
                    },
                    {
                        "label": I18n.t("главный (", "main (") + Shell.primaryName + ")",
                        "value": "primary"
                    }
                ].concat(Quickshell.screens.map(s => ({
                            "label": s.name,
                            "value": s.name
                        })))
                currentValue: Config.notifications.screen
                onActivated: v => Config.notifications.screen = v
            }
        }
    }
    PxGroup {
        name: "history"
        title: I18n.t("История (", "History (") + Notifs.history.length + ")"
        icon: "calendar"
        width: parent.width
        Row {
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Очистить", "Clear")
                icon: "trash"
                onClicked: Notifs.clearHistory()
            }
            PxButton {
                text: I18n.t("Тестовое уведомление", "Test notification")
                icon: "bell"
                onClicked: Quickshell.execDetached(["notify-send", "-a", "angelOS", I18n.t("Привет ♡", "Hello ♡"), I18n.t("Это тестовое уведомление. <b>жирный</b> текст и <i>курсив</i>.", "A test notification with <b>bold</b> and <i>italic</i> text.")])
            }
        }
    }
}
