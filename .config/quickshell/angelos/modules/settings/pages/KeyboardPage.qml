pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

PxPage {
    id: page

    heading: I18n.t("Клавиатура", "Keyboard")
    subtitle: I18n.t("Раскладки и повтор клавиш. Пишется в ~/.config/niri/cfg/input.kdl точечно (комментарии остаются), с бэкапом и проверкой.", "Layouts and key repeat. Updates input.kdl, preserving comments, with a backup and validation.")

    readonly property var layoutList: InputConfig.layouts.split(",").filter(l => l)
    readonly property var optionList: InputConfig.options.split(",").filter(o => o)
    readonly property string switchOption: optionList.find(o => o.startsWith("grp:")) || ""

    function setOptions(list) {
        InputConfig.save({
            "options": list.filter(o => o).join(",")
        });
    }

    PxGroup {
        name: "keyboard-layouts"
        title: I18n.t("Раскладки", "Keyboard layouts")
        icon: "keyboard"
        width: parent.width

        SettingRow {
            label: I18n.t("Сейчас", "Current")
            PxText {
                text: Niri.layoutName + "  (" + Niri.layoutShort + ")"
                kind: "title"
            }
        }
        SettingRow {
            label: I18n.t("Раскладки", "Keyboard layouts")
            hint: I18n.t("порядок = порядок переключения", "Order determines the switching sequence")
            Flow {
                width: parent.width
                spacing: Theme.u * 3
                Repeater {
                    model: page.layoutList
                    PxButton {
                        required property string modelData
                        required property int index
                        compact: true
                        text: modelData + "  ✕"
                        enabled: page.layoutList.length > 1
                        onClicked: InputConfig.save({
                            "layouts": page.layoutList.filter((l, i) => i !== index).join(",")
                        })
                    }
                }
                PxCombo {
                    width: Theme.u * 60
                    placeholder: I18n.t("+ добавить", "+ add")
                    model: InputConfig.knownLayouts.filter(l => !page.layoutList.includes(l))
                    onActivated: v => InputConfig.save({
                            "layouts": page.layoutList.concat([v]).join(",")
                        })
                }
            }
        }
        SettingRow {
            label: I18n.t("Переключать", "Switch with")
            PxCombo {
                width: Theme.u * 100
                model: InputConfig.switchOptions
                currentValue: page.switchOption
                onActivated: v => page.setOptions(page.optionList.filter(o => !o.startsWith("grp:")).concat([v]))
            }
        }
        Repeater {
            model: InputConfig.extraOptions
            PxCheck {
                required property var modelData
                text: modelData.label
                checked: page.optionList.includes(modelData.value)
                onToggled: c => page.setOptions(page.optionList.filter(o => o !== modelData.value).concat(c ? [modelData.value] : []))
            }
        }
    }

    PxGroup {
        name: "key-repeat"
        title: I18n.t("Повтор клавиш", "Key repeat")

        advanced: true
        icon: "refresh"
        width: parent.width
        SettingRow {
            label: I18n.t("Задержка", "Delay")
            PxSlider {
                width: parent.width
                from: 150
                to: 800
                stepSize: 10
                value: InputConfig.repeatDelay
                suffix: I18n.t(" мс", " ms")
                onReleased: v => InputConfig.save({
                        "repeatDelay": v
                    })
            }
        }
        SettingRow {
            label: I18n.t("Скорость", "Rate")
            PxSlider {
                width: parent.width
                from: 10
                to: 80
                stepSize: 1
                value: InputConfig.repeatRate
                suffix: I18n.t("/с", "/s")
                onReleased: v => InputConfig.save({
                        "repeatRate": v
                    })
            }
        }
        SettingRow {
            label: I18n.t("NumLock при входе", "NumLock on login")
            hint: InputConfig.numlockState === "noperm" ? I18n.t("niri включает его при своём запуске; включить сразу не вышло — нет доступа к /dev/uinput", "niri turns it on when it starts; turning it on right away failed: no access to /dev/uinput") : I18n.t("niri включает его при запуске, angelOS проверяет лампочку после входа и дожимает", "niri turns it on when it starts; angelOS checks the LED after login and makes sure")
            PxToggle {
                checked: InputConfig.numlock
                onToggled: c => InputConfig.save({
                        "numlock": c
                    })
            }
        }
        PxField {
            width: parent.width
            placeholder: I18n.t("поле для проверки — печатай тут ♡", "Type here to test ♡")
        }
    }

    PxText {
        width: parent.width
        wrapMode: Text.Wrap
        text: InputConfig.log
        dim: true
    }
}
