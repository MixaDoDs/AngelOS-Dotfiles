pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The touchpad (laptops, 2026-10-08): niri's `touchpad { }` in cfg/input.kdl (services/InputConfig,
// line edits with a backup and `niri validate`), and the gestures — niri's own and angelOS's
// (services/Gestures, scripts/gesture-watch.py). The tree shows the page where there is a touchpad.
PxPage {
    id: page
    heading: I18n.t("Тачпад", "Touchpad")
    subtitle: I18n.t("Касания, прокрутка, скорость и жесты.", "Taps, scrolling, speed and gestures.")

    component Flag: PxToggle {
        required property string flag
        property bool inverted: false
        checked: InputConfig.tpFlag(flag) !== inverted
        onToggled: v => InputConfig.save({
                "touchpad": {
                    "flags": ({
                            [flag]: v !== inverted
                        })
                }
            })
    }
    function setValue(name, v) {
        const values = {};
        values[name] = v;
        InputConfig.save({
            "touchpad": {
                "values": values
            }
        });
    }

    PxGroup {
        name: "touchpad"
        title: I18n.t("Тачпад", "Touchpad")
        icon: "touchpad"
        width: parent.width
        PxText {
            visible: !Laptop.hasTouchpad
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Тачпад не найден — настройки всё равно запишутся и сработают, когда он появится.", "No touchpad found: the settings are saved anyway and apply once there is one.")
        }
        SettingRow {
            label: I18n.t("Тачпад включён", "Touchpad on")
            hint: I18n.t("его клавиша (Fn) делает то же самое", "Its key (Fn) does the same")
            Flag {
                flag: "off"
                inverted: true
            }
        }
        SettingRow {
            label: I18n.t("Нажатие касанием", "Tap to click")
            Flag {
                flag: "tap"
            }
        }
        SettingRow {
            label: I18n.t("Естественная прокрутка", "Natural scrolling")
            hint: I18n.t("содержимое едет за пальцами, как на телефоне", "The content follows your fingers, like on a phone")
            Flag {
                flag: "natural-scroll"
            }
        }
        SettingRow {
            label: I18n.t("Скорость указателя", "Pointer speed")
            PxSlider {
                width: Theme.u * 110
                from: -1
                to: 1
                stepSize: 0.05
                decimals: 2
                live: false
                value: parseFloat(InputConfig.tpValue("accel-speed", "0"))
                onReleased: v => page.setValue("accel-speed", Math.round(v * 100) / 100)
            }
        }
        SettingRow {
            label: I18n.t("Не мешать при наборе", "Off while typing")
            hint: I18n.t("ладонь на тачпаде не сдвинет курсор, пока печатаешь", "A palm on it won't move the pointer while you type")
            Flag {
                flag: "dwt"
            }
        }
        SettingRow {
            label: I18n.t("Выключать, когда есть мышь", "Off while a mouse is plugged in")
            Flag {
                flag: "disabled-on-external-mouse"
            }
        }
    }

    PxGroup {
        name: "touchpad-more"
        advanced: true
        title: I18n.t("Тонкая настройка тачпада", "Touchpad fine-tuning")
        icon: "gear"
        width: parent.width
        SettingRow {
            label: I18n.t("Правый клик", "Right click")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("угол", "corner"),
                        "value": "button-areas"
                    },
                    {
                        "label": I18n.t("два пальца", "two fingers"),
                        "value": "clickfinger"
                    }
                ]
                currentValue: InputConfig.tpValue("click-method", "button-areas")
                onActivated: v => page.setValue("click-method", v === "button-areas" ? null : v)
            }
        }
        SettingRow {
            label: I18n.t("Касание двумя / тремя пальцами", "Two- / three-finger tap")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("правый / средний", "right / middle"),
                        "value": "left-right-middle"
                    },
                    {
                        "label": I18n.t("средний / правый", "middle / right"),
                        "value": "left-middle-right"
                    }
                ]
                currentValue: InputConfig.tpValue("tap-button-map", "left-right-middle")
                onActivated: v => page.setValue("tap-button-map", v === "left-right-middle" ? null : v)
            }
        }
        SettingRow {
            label: I18n.t("Прокрутка", "Scrolling")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("двумя пальцами", "two fingers"),
                        "value": "two-finger"
                    },
                    {
                        "label": I18n.t("по краю", "edge"),
                        "value": "edge"
                    }
                ]
                currentValue: InputConfig.tpValue("scroll-method", "two-finger")
                onActivated: v => page.setValue("scroll-method", v === "two-finger" ? null : v)
            }
        }
        SettingRow {
            label: I18n.t("Скорость прокрутки", "Scroll speed")
            PxSlider {
                width: Theme.u * 110
                from: 0.2
                to: 3
                stepSize: 0.1
                decimals: 1
                live: false
                suffix: "×"
                value: parseFloat(InputConfig.tpValue("scroll-factor", "1"))
                onReleased: v => page.setValue("scroll-factor", Math.abs(v - 1) < 0.05 ? null : Math.round(v * 10) / 10)
            }
        }
        SettingRow {
            label: I18n.t("Перетаскивание касанием", "Tap and drag")
            hint: I18n.t("двойное касание и тяни", "Tap twice and drag")
            PxToggle {
                checked: InputConfig.tpValue("drag", "true") !== "false"
                onToggled: v => page.setValue("drag", v ? null : false)
            }
        }
        SettingRow {
            label: I18n.t("Ускорение", "Acceleration")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("плавное", "adaptive"),
                        "value": "adaptive"
                    },
                    {
                        "label": I18n.t("ровное", "flat"),
                        "value": "flat"
                    }
                ]
                currentValue: InputConfig.tpValue("accel-profile", "adaptive")
                onActivated: v => page.setValue("accel-profile", v === "adaptive" ? null : v)
            }
        }
        PxText {
            visible: InputConfig.log !== ""
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: InputConfig.log
        }
    }

    PxGroup {
        name: "gestures"
        title: I18n.t("Жесты", "Gestures")
        icon: "sparkle"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Свои у niri: 3 пальца влево-вправо — колонки окон, вверх-вниз — рабочие столы, 4 пальца вверх — обзор. Два пальца щипком — масштаб в приложениях. Остальное — ниже.", "niri's own: three fingers left/right move between columns, up/down between workspaces, four fingers up open the overview. A two-finger pinch zooms in apps. The rest is below.")
        }
        SettingRow {
            label: I18n.t("Жесты angelOS", "angelOS gestures")
            hint: Gestures.status === "ready" ? I18n.t("работают", "on") : Gestures.status === "noperm" ? I18n.t("нужна группа input: sudo usermod -aG input $USER и перезайти", "needs the input group: sudo usermod -aG input $USER, then log in again") : Gestures.status === "notouchpad" ? I18n.t("тачпад не найден", "no touchpad found") : Gestures.status === "error" ? I18n.t("демон упал, перезапускаю", "the watcher failed, restarting") : ""
            PxToggle {
                checked: Config.gestures.enabled
                onToggled: v => Config.gestures.enabled = v
            }
        }
        SettingRow {
            label: I18n.t("Чувствительность", "Sensitivity")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("низкая", "low"),
                        "value": "low"
                    },
                    {
                        "label": I18n.t("обычная", "normal"),
                        "value": "normal"
                    },
                    {
                        "label": I18n.t("высокая", "high"),
                        "value": "high"
                    }
                ]
                currentValue: Config.gestures.sensitivity
                onActivated: v => Config.gestures.sensitivity = v
            }
        }
        PxText {
            visible: Gestures.last !== ""
            width: parent.width
            kind: "tiny"
            color: Theme.accent
            text: I18n.t("Последний жест: ", "Last gesture: ") + Gestures.label(Gestures.last)
        }
        Repeater {
            model: Gestures.gestures
            SettingRow {
                id: gRow
                required property string modelData
                width: parent ? parent.width : 0
                label: Gestures.label(modelData)
                hint: modelData === "tap3" ? I18n.t("это ещё и средний клик libinput (вставка выделенного)", "It is also libinput's middle click (pastes the selection)") : modelData.startsWith("edge") ? I18n.t("одним пальцем с самого края внутрь", "One finger from the very edge inwards") : ""
                PxCombo {
                    model: Gestures.actions
                    currentValue: Gestures.actionOf(gRow.modelData)
                    onActivated: v => Gestures.setAction(gRow.modelData, v)
                }
            }
        }
    }
}
