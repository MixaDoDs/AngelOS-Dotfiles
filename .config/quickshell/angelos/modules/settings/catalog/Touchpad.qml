// The settings once in TouchpadPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// The touchpad (laptops, 2026-10-08): niri's `touchpad { }` in cfg/input.kdl (services/InputConfig,
// line edits with a backup and `niri validate`), and the gestures — niri's own and angelOS's
// (services/Gestures, scripts/gesture-watch.py). The tree shows the page where there is a touchpad.
CatPage {
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
    CatGroup {
        name: "touchpad"
        title: I18n.t("Тачпад", "Touchpad")
        icon: "touchpad"
        CatNote {
            present: !Laptop.hasTouchpad
            dim: true
            text: I18n.t("Тачпад не найден — настройки всё равно запишутся и сработают, когда он появится.", "No touchpad found: the settings are saved anyway and apply once there is one.")
        }
        CatCustom {
            label: I18n.t("Тачпад включён", "Touchpad on")
            hint: I18n.t("его клавиша (Fn) делает то же самое", "Its key (Fn) does the same")
            CatBox {
                Flag {
                    flag: "off"
                    inverted: true
                }
            }
        }
        CatCustom {
            label: I18n.t("Нажатие касанием", "Tap to click")
            hint: I18n.t("Лёгкое касание — как щелчок, без нажатия.", "A light touch counts as a click, no press needed.")
            CatBox {
                Flag {
                    flag: "tap"
                }
            }
        }
        CatCustom {
            label: I18n.t("Естественная прокрутка", "Natural scrolling")
            hint: I18n.t("содержимое едет за пальцами, как на телефоне", "The content follows your fingers, like on a phone")
            CatBox {
                Flag {
                    flag: "natural-scroll"
                }
            }
        }
        CatSlider {
            label: I18n.t("Скорость указателя", "Pointer speed")
            from: -1
            to: 1
            stepSize: 0.05
            decimals: 2
            live: false
            value: parseFloat(InputConfig.tpValue("accel-speed", "0"))
            onReleased: v => page.setValue("accel-speed", Math.round(v * 100) / 100)
        }
        CatCustom {
            label: I18n.t("Не мешать при наборе", "Off while typing")
            hint: I18n.t("ладонь на тачпаде не сдвинет курсор, пока печатаешь", "A palm on it won't move the pointer while you type")
            CatBox {
                Flag {
                    flag: "dwt"
                }
            }
        }
        CatCustom {
            label: I18n.t("Выключать, когда есть мышь", "Off while a mouse is plugged in")
            CatBox {
                Flag {
                    flag: "disabled-on-external-mouse"
                }
            }
        }
    }
    CatGroup {
        name: "touchpad-more"
        advanced: true
        title: I18n.t("Тонкая настройка тачпада", "Touchpad fine-tuning")
        icon: "gear"
        CatChoice {
            label: I18n.t("Правый клик", "Right click")
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
        CatChoice {
            label: I18n.t("Касание двумя / тремя пальцами", "Two- / three-finger tap")
            hint: I18n.t("Какой щелчок дают касания двумя и тремя пальцами.", "Which click a two- and a three-finger tap give.")
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
        CatChoice {
            label: I18n.t("Прокрутка", "Scrolling")
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
        CatSlider {
            label: I18n.t("Скорость прокрутки", "Scroll speed")
            from: 0.2
            to: 3
            stepSize: 0.1
            decimals: 1
            live: false
            suffix: "×"
            value: parseFloat(InputConfig.tpValue("scroll-factor", "1"))
            onReleased: v => page.setValue("scroll-factor", Math.abs(v - 1) < 0.05 ? null : Math.round(v * 10) / 10)
        }
        CatToggle {
            label: I18n.t("Перетаскивание касанием", "Tap and drag")
            hint: I18n.t("двойное касание и тяни", "Tap twice and drag")
            checked: InputConfig.tpValue("drag", "true") !== "false"
            onToggled: v => page.setValue("drag", v ? null : false)
        }
        CatChoice {
            label: I18n.t("Ускорение", "Acceleration")
            hint: I18n.t("Плавное — быстрое движение уносит дальше. Ровное — курсор идёт точно за пальцем.", "Adaptive: a quick swipe goes further. Flat: the pointer follows your finger exactly.")
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
        CatNote {
            present: InputConfig.log !== ""
            textKind: "tiny"
            dim: true
            text: InputConfig.log
        }
    }
    CatGroup {
        name: "gestures"
        title: I18n.t("Жесты", "Gestures")
        icon: "sparkle"
        CatNote {
            dim: true
            text: I18n.t("Уже есть: 3 пальца вбок — колонки, вверх-вниз — столы, 4 вверх — обзор, щипок — масштаб.", "Built in: 3 fingers sideways for columns, up/down for desks, 4 up for overview, pinch to zoom.")
        }
        CatToggle {
            label: I18n.t("Жесты angelOS", "angelOS gestures")
            hint: Gestures.status === "ready" ? I18n.t("работают", "on") : Gestures.status === "noperm" ? I18n.t("нужна группа input: sudo usermod -aG input $USER и перезайти", "needs the input group: sudo usermod -aG input $USER, then log in again") : Gestures.status === "notouchpad" ? I18n.t("тачпад не найден", "no touchpad found") : Gestures.status === "error" ? I18n.t("демон упал, перезапускаю", "the watcher failed, restarting") : ""
            checked: Config.gestures.enabled
            onToggled: v => Config.gestures.enabled = v
        }
        CatChoice {
            label: I18n.t("Чувствительность", "Sensitivity")
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
        CatNote {
            present: Gestures.last !== ""
            textKind: "tiny"
            text: I18n.t("Последний жест: ", "Last gesture: ") + Gestures.label(Gestures.last)
        }
        CatRepeat {
            model: Gestures.gestures
            delegate: Component {
                CatCustom {
                    id: gRow
                    required property string modelData
                    label: Gestures.label(modelData)
                    hint: modelData === "tap3" ? I18n.t("это ещё и средний клик libinput (вставка выделенного)", "It is also libinput's middle click (pastes the selection)") : modelData.startsWith("edge") ? I18n.t("одним пальцем с самого края внутрь", "One finger from the very edge inwards") : ""
                    CatBox {
                        PxCombo {
                            model: Gestures.actions
                            currentValue: Gestures.actionOf(gRow.modelData)
                            onActivated: v => Gestures.setAction(gRow.modelData, v)
                        }
                    }
                }
            }
        }
    }
}
