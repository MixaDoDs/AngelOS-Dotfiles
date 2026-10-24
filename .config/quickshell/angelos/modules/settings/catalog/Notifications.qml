// The settings once in NotificationsPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

CatPage {
    heading: I18n.t("Уведомления", "Notifications")
    CatGroup {
        name: "behavior"
        title: I18n.t("Как показывать", "How they show")
        icon: "bell"
        CatToggle {
            label: I18n.t("Не беспокоить", "Do not disturb")
            hint: I18n.t("критичные всё равно покажутся", "Critical notifications still appear")
            checked: Config.notifications.dnd
            onToggled: c => Config.notifications.dnd = c
        }
        // one place for where they show: the Halo's pill (services/Halo: halo.notify) or the corner
        CatChoice {
            present: !!Config.halo.enabled
            label: I18n.t("Окошком или в Нимбе", "A popup or the Halo")
            hint: I18n.t("в Нимбе — 3 секунды в капсуле; важные всё равно в углу", "In the Halo: 3 seconds in the pill; urgent ones still in the corner")
            model: [{
                    "label": I18n.t("В углу", "In the corner"),
                    "value": "corner"
                }, {
                    "label": I18n.t("В Нимбе", "In the Halo"),
                    "value": "halo"
                }]
            currentValue: Config.halo.notify !== false ? "halo" : "corner"
            onActivated: v => Config.halo.notify = v === "halo"
        }
        CatSlider {
            label: I18n.t("Сколько висят", "How long they stay")
            from: 2000
            to: 20000
            stepSize: 500
            value: Config.notifications.timeout
            valueScale: 0.001
            decimals: 1
            suffix: I18n.t(" с", " s")
            onMoved: v => Config.notifications.timeout = v
        }
        CatSpin {
            label: I18n.t("Максимум карточек", "Maximum cards")
            from: 1
            to: 8
            value: Config.notifications.maxPopups
            onMoved: v => Config.notifications.maxPopups = v
        }
        CatCustom {
            label: I18n.t("Где показывать", "Show on")
            CatBox {
                PxPositionPicker {
                    value: Config.notifications.position
                    onPicked: v => Config.notifications.position = v
                }
            }
        }
        CatChoice {
            label: I18n.t("Монитор", "Monitor")
            hint: I18n.t("где фокус, на главном экране (страница «Экраны») или на выбранном", "The focused display, the main one (Displays page) or a fixed one")
            combo: true
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
    CatGroup {
        name: "history"
        title: I18n.t("История (", "History (") + Notifs.history.length + ")"
        icon: "calendar"
        CatButton {
            text: I18n.t("Очистить", "Clear")
            icon: "trash"
            onClicked: Notifs.clearHistory()
            CatButton {
                text: I18n.t("Тестовое уведомление", "Test notification")
                icon: "bell"
                onClicked: Quickshell.execDetached(["notify-send", "-a", "angelOS", I18n.t("Привет ♡", "Hello ♡"), I18n.t("Это тестовое уведомление. <b>жирный</b> текст и <i>курсив</i>.", "A test notification with <b>bold</b> and <i>italic</i> text.")])
            }
        }
    }
}
