import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

Column {
    property var plugin
    width: parent ? parent.width : 400
    spacing: Skin.px(10)

    PxGroup {
        title: I18n.t("Стрим-статы", "Stream stats")
        icon: "heart"
        width: parent.width
        SettingRow {
            label: I18n.t("Монитор для окошка", "Popup display")
            hint: I18n.t("пусто = на всех", "Empty = all displays")
            PxCombo {
                width: Skin.px(200)
                model: [
                    {
                        "label": I18n.t("все", "all"),
                        "value": ""
                    }
                ].concat(Quickshell.screens.map(s => ({
                            "label": s.name,
                            "value": s.name
                        })))
                currentValue: plugin ? plugin.get("screen", "") : ""
                onActivated: v => plugin.set("screen", v)
            }
        }
        SettingRow {
            label: I18n.t("Ныть при стрессе 100%", "Notify at 100% stress")
            PxToggle {
                checked: plugin ? plugin.get("nag", true) : true
                onToggled: c => plugin.set("nag", c)
            }
        }
    }
}
