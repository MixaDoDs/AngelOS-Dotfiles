import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "."

Column {
    id: root
    property var plugin
    width: parent ? parent.width : 400
    spacing: Skin.px(10)

    PxGroup {
        title: I18n.t("Сейчас", "Current")
        icon: "terminal"
        width: parent.width
        Panel {
            width: parent.width
            plugin: root.plugin
        }
    }

    PxGroup {
        title: I18n.t("Откуда данные", "Where the numbers come from")
        icon: "info"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Из логов самого Codex (~/.codex/sessions): лимиты, которые провайдер прислал с последним ответом, и счётчики токенов. Переписка не читается, сеть не используется. При входе через ChatGPT есть окна 5 ч / неделя и кредиты; по API-ключу или у сторонних провайдеров лимитов может не быть — тогда видны токены за сегодня.", "From Codex's own logs (~/.codex/sessions): the limits the provider sent with its last answer, and token counters. Conversations are not read and nothing goes over the network. A ChatGPT login reports 5-hour / weekly windows and credits; an API key or a third-party provider may report none, then today's tokens are shown.")
        }
        Row {
            spacing: Skin.px(8)
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("вход: ", "login: ") + (CodexState.data.auth === "chatgpt" ? "ChatGPT ♡" : CodexState.data.auth === "apikey" ? I18n.t("API-ключ", "API key") : (CodexState.data.auth || "—"))
            }
            PxButton {
                text: I18n.t("Войти через браузер", "Sign in via browser")
                icon: "lock"
                onClicked: CodexState.login()
            }
        }
    }

    PxGroup {
        title: I18n.t("Вид", "Appearance")
        icon: "sparkle"
        width: parent.width
        SettingRow {
            label: I18n.t("На панели", "In the bar")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Авто", "Auto"),
                        "value": "auto"
                    },
                    {
                        "label": I18n.t("5 ч", "5 h"),
                        "value": "five"
                    },
                    {
                        "label": I18n.t("Неделя", "Week"),
                        "value": "week"
                    },
                    {
                        "label": I18n.t("Токены", "Tokens"),
                        "value": "today"
                    },
                    {
                        "label": I18n.t("Значок", "Icon"),
                        "value": "off"
                    }
                ]
                currentValue: root.plugin ? root.plugin.get("barLimit", "auto") : "auto"
                onActivated: v => root.plugin.set("barLimit", v)
            }
        }
        SettingRow {
            label: I18n.t("Значок на панели всегда", "Always show the bar icon")
            hint: I18n.t("иначе только когда идёт сессия", "Otherwise only while a session runs")
            PxToggle {
                checked: root.plugin ? root.plugin.get("barAlways", true) : true
                onToggled: c => root.plugin.set("barAlways", c)
            }
        }
        SettingRow {
            label: I18n.t("Виджет на столе", "Desktop widget")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Всегда", "Always"),
                        "value": "always"
                    },
                    {
                        "label": I18n.t("Когда активен", "When active"),
                        "value": "active"
                    },
                    {
                        "label": I18n.t("Скрыт", "Hidden"),
                        "value": "off"
                    }
                ]
                currentValue: root.plugin ? root.plugin.get("orb", "always") : "always"
                onActivated: v => root.plugin.set("orb", v)
            }
        }
        SettingRow {
            label: I18n.t("Обновлять каждые", "Refresh every")
            PxSpin {
                from: 15
                to: 600
                stepSize: 15
                value: root.plugin ? root.plugin.get("interval", 60) : 60
                suffix: I18n.t(" с", " s")
                onMoved: v => {
                    root.plugin.set("interval", v);
                    CodexState.intervalSec = v;
                }
            }
        }
    }
}
