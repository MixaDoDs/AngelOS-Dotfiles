import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

Column {
    id: root
    property var plugin
    width: parent ? parent.width : 400
    spacing: Theme.u * 5

    PxText {
        width: parent.width
        wrapMode: Text.Wrap
        kind: "tiny"
        color: ScreenTune.error || ScreenTune.anyFailed ? Theme.danger : Theme.textDim
        text: ScreenTune.error ? ScreenTune.error : ScreenTune.anyFailed ? I18n.t("гамму держит другая программа (wlsunset, gammastep?) — закрой её, ночной свет подхватит сам", "Another program holds the gamma (wlsunset, gammastep?): close it and the night light takes over") : ScreenTune.night ? I18n.t("сейчас ", "Now ") + ScreenTune.kelvin + " K" + I18n.t(" · яркость мониторов — Настройки → Экран", " · monitor brightness: Settings → Display") : ""
    }

    PxGroup {
        title: I18n.t("Ночной свет", "Night light")
        icon: "moon"
        width: parent.width
        SettingRow {
            label: I18n.t("Включён", "Enabled")
            PxToggle {
                checked: root.plugin ? root.plugin.get("on", true) : true
                onToggled: c => root.plugin.set("on", c)
            }
        }
        SettingRow {
            label: I18n.t("Днём", "Daytime")
            PxSlider {
                width: parent.width
                from: 4500
                to: 6500
                stepSize: 100
                value: root.plugin ? root.plugin.get("day", 6600) : 6600
                suffix: " K"
                onReleased: v => root.plugin.set("day", v)
            }
        }
        SettingRow {
            label: I18n.t("Ночью", "Nighttime")
            PxSlider {
                width: parent.width
                from: 2500
                to: 5000
                stepSize: 100
                value: root.plugin ? root.plugin.get("night", 3900) : 3900
                suffix: " K"
                onReleased: v => root.plugin.set("night", v)
            }
        }
        SettingRow {
            label: I18n.t("По координатам", "Use coordinates")
            hint: I18n.t("иначе по времени ниже", "Otherwise, use the times below")
            PxToggle {
                checked: root.plugin ? root.plugin.get("useLocation", false) : false
                onToggled: c => root.plugin.set("useLocation", c)
            }
        }
        SettingRow {
            label: I18n.t("Рассвет / закат", "Sunrise / sunset")
            Row {
                spacing: Theme.u * 3
                PxField {
                    width: Theme.u * 40
                    text: root.plugin ? root.plugin.get("sunrise", "07:00") : ""
                    onAccepted: root.plugin.set("sunrise", text)
                }
                PxField {
                    width: Theme.u * 40
                    text: root.plugin ? root.plugin.get("sunset", "20:00") : ""
                    onAccepted: root.plugin.set("sunset", text)
                }
            }
        }
        SettingRow {
            label: I18n.t("Широта / долгота", "Latitude / longitude")
            Row {
                spacing: Theme.u * 3
                PxField {
                    width: Theme.u * 40
                    text: root.plugin ? String(root.plugin.get("lat", 55.75)) : ""
                    onAccepted: root.plugin.set("lat", parseFloat(text))
                }
                PxField {
                    width: Theme.u * 40
                    text: root.plugin ? String(root.plugin.get("lon", 37.62)) : ""
                    onAccepted: root.plugin.set("lon", parseFloat(text))
                }
            }
        }
    }
}
