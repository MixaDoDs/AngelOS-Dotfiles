// The settings once in KeyboardPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

CatPage {
    id: page
    heading: I18n.t("Клавиатура", "Keyboard")
    subtitle: I18n.t("Раскладки и повтор клавиш.", "Layouts and key repeat.")
    readonly property var layoutList: InputConfig.layouts.split(",").filter(l => l)
    readonly property var optionList: InputConfig.options.split(",").filter(o => o)
    readonly property string switchOption: optionList.find(o => o.startsWith("grp:")) || ""
    function setOptions(list) {
        InputConfig.save({
            "options": list.filter(o => o).join(",")
        });
    }
    CatGroup {
        name: "keyboard-layouts"
        title: I18n.t("Раскладки", "Keyboard layouts")
        icon: "keyboard"
        CatCustom {
            label: I18n.t("Сейчас", "Current")
            CatBox {
                PxText {
                    text: Niri.layoutName + "  (" + Niri.layoutShort + ")"
                    kind: "title"
                }
            }
        }
        CatCustom {
            label: I18n.t("Раскладки", "Keyboard layouts")
            hint: I18n.t("порядок = порядок переключения", "Order determines the switching sequence")
            CatBox {
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
        }
        CatChoice {
            label: I18n.t("Переключать", "Switch with")
            combo: true
            model: InputConfig.switchOptions
            currentValue: page.switchOption
            onActivated: v => page.setOptions(page.optionList.filter(o => !o.startsWith("grp:")).concat([v]))
        }
        CatCustom {
            wide: true
            CatBox {
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
        }
    }
    // Win+V (services/Clipboard, issue #61)
    CatGroup {
        name: "clipboard"
        title: I18n.t("Буфер обмена", "Clipboard")
        icon: "package"
        CatToggle {
            label: I18n.t("Win+V вставляет", "Win+V pastes")
            hint: I18n.t("выбранное в истории буфера сразу вставляется в окно, где ты работаешь (Ctrl+V, в терминале Ctrl+Shift+V); выключено — только копируется, вставка — вручную. Shift+Enter всегда только копирует", "the entry picked in the clipboard history goes straight into the window you were in (Ctrl+V, Ctrl+Shift+V in a terminal); off: it is only copied and you paste it yourself. Shift+Enter always only copies")
            checked: Config.launcher.clipboardPaste !== false
            onToggled: c => Config.launcher.clipboardPaste = c
        }
        CatToggle {
            present: Niri.nativeMinimize
            label: I18n.t("Буфер не пропадает", "Clipboard stays")
            hint: I18n.t("скопировал и закрыл программу — текст, ссылки, файлы и картинка всё равно вставляются. Копия только в памяти; то, что копирует менеджер паролей, не хранится", "Copy, close the program, and the text, links, files and picture still paste. The copy lives in memory only; what a password manager copies is never kept")
            checked: Config.windows.clipboardKeep
            onToggled: c => Config.windows.clipboardKeep = c
        }
    }
    CatGroup {
        name: "key-repeat"
        title: I18n.t("Повтор клавиш", "Key repeat")
        advanced: true
        icon: "refresh"
        CatSlider {
            label: I18n.t("Задержка", "Delay")
            from: 150
            to: 800
            stepSize: 10
            value: InputConfig.repeatDelay
            suffix: I18n.t(" мс", " ms")
            onReleased: v => InputConfig.save({
                    "repeatDelay": v
                })
        }
        CatSlider {
            label: I18n.t("Скорость", "Rate")
            from: 10
            to: 80
            stepSize: 1
            value: InputConfig.repeatRate
            suffix: I18n.t("/с", "/s")
            onReleased: v => InputConfig.save({
                    "repeatRate": v
                })
        }
        CatToggle {
            label: I18n.t("NumLock при входе", "NumLock on login")
            hint: InputConfig.numlockState === "noperm" ? I18n.t("включится при следующем входе; сразу не вышло — нет доступа к клавиатуре", "On at the next login; it couldn't switch on right now — no access to the keyboard") : I18n.t("включается при входе", "On at login")
            checked: InputConfig.numlock
            onToggled: c => InputConfig.save({
                    "numlock": c
                })
        }
        CatCustom {
            wide: true
            CatBox {
                PxField {
                    width: parent.width
                    placeholder: I18n.t("поле для проверки — печатай тут ♡", "Type here to test ♡")
                }
            }
        }
    }
    CatNote {
        text: InputConfig.log
        dim: true
    }
}
