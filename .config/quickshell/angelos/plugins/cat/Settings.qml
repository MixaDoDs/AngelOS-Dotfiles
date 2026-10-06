import QtQuick
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
        title: I18n.t("Котик", "Cat")
        icon: "heart"
        width: parent.width

        CatSprite {
            plugin: root.plugin
            pixel: Theme.u * 3
        }
        SettingRow {
            label: I18n.t("Размер на панели", "Bar size")
            PxSegmented {
                model: [
                    {
                        "label": "×1",
                        "value": 1
                    },
                    {
                        "label": "×1.5",
                        "value": 1.5
                    },
                    {
                        "label": "×2",
                        "value": 2
                    }
                ]
                currentValue: root.plugin ? root.plugin.get("size", 1) : 1
                onActivated: v => root.plugin.set("size", v)
            }
        }
        SettingRow {
            label: I18n.t("Показывать % CPU", "Show CPU %")
            PxToggle {
                checked: root.plugin ? root.plugin.get("showPercent", false) : false
                onToggled: c => root.plugin.set("showPercent", c)
            }
        }
        SettingRow {
            label: I18n.t("Начинает гулять с", "Walk above")
            PxSlider {
                width: parent.width
                from: 0
                to: 100
                stepSize: 1
                value: root.plugin ? root.plugin.get("walk", 15) : 15
                suffix: "%"
                onReleased: v => root.plugin.set("walk", v)
            }
        }
        SettingRow {
            label: I18n.t("Бежит с", "Run above")
            PxSlider {
                width: parent.width
                from: 0
                to: 100
                stepSize: 1
                value: root.plugin ? root.plugin.get("run", 60) : 60
                suffix: "%"
                onReleased: v => root.plugin.set("run", v)
            }
        }
        SettingRow {
            label: I18n.t("Опрос CPU", "CPU polling")
            PxSpin {
                from: 1
                to: 10
                value: Cpu.intervalMs / 1000
                suffix: I18n.t(" с", " s")
                onMoved: v => {
                    Cpu.intervalMs = v * 1000;
                    root.plugin.set("poll", v);
                }
            }
        }
        SettingRow {
            label: I18n.t("Цвет шёрстки", "Fur color")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Из темы", "From theme"),
                        "value": "theme"
                    },
                    {
                        "label": I18n.t("Свой", "Custom"),
                        "value": "custom"
                    }
                ]
                currentValue: root.plugin ? root.plugin.get("colorMode", "theme") : "theme"
                onActivated: v => root.plugin.set("colorMode", v)
            }
        }
        SettingRow {
            visible: root.plugin && root.plugin.get("colorMode", "theme") === "custom"
            label: I18n.t("Цвет (#hex)", "Color (#hex)")
            PxField {
                width: Skin.px(100)
                text: root.plugin ? root.plugin.get("color", "#e8a24c") : ""
                onAccepted: root.plugin.set("color", text)
            }
        }
    }
}
