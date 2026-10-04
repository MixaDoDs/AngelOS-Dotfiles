pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The mouse (niri's input.kdl, like the keyboard) and the lens at the pointer.
PxPage {
    id: page

    heading: I18n.t("Мышь и лупа", "Mouse and lens")
    subtitle: I18n.t("Скорость и ускорение мыши пишутся в ~/.config/niri/cfg/input.kdl точечно, с бэкапом и проверкой. Ниже — лупа у курсора.", "Mouse speed and acceleration go to input.kdl, with a backup and validation. Below: the lens at the pointer.")

    PxGroup {
        name: "mouse"
        title: I18n.t("Мышь", "Mouse")
        icon: "mouse"
        width: parent.width
        SettingRow {
            label: I18n.t("Ускорение", "Acceleration")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Плоское", "Flat"),
                        "value": "flat"
                    },
                    {
                        "label": I18n.t("Адаптивное", "Adaptive"),
                        "value": "adaptive"
                    }
                ]
                currentValue: InputConfig.accelProfile
                onActivated: v => InputConfig.save({
                        "accelProfile": v
                    })
            }
        }
        SettingRow {
            label: I18n.t("Чувствительность", "Sensitivity")
            PxSlider {
                width: parent.width
                from: -1
                to: 1
                stepSize: 0.05
                decimals: 2
                value: InputConfig.accelSpeed
                onReleased: v => InputConfig.save({
                        "accelSpeed": v
                    })
            }
        }
        // set where the windows are laid out (Windows → Layout); here a link to it
        SettingLink {
            label: I18n.t("Фокус следует за мышью", "Focus follows mouse")
            hint: InputConfig.focusFollowsMouse ? I18n.t("включено", "on") : I18n.t("выключено", "off")
            page: "windows"
            group: "layout"
        }
    }

    // the lens at the pointer (services/Lens)
    PxGroup {
        name: "lens-at-pointer"
        width: parent.width
        title: I18n.t("Лупа у курсора", "Lens at the pointer")
        icon: "search"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: Config.lens.mode === "snapshot" ? I18n.t("Круглая лупа едет за мышкой и увеличивает то, что под ней, — по снимку экрана: клик или R — новый снимок, остальной экран живой. Внутри: колесо — ближе/дальше, Shift+колесо — размер, ПКМ или Esc — убрать.", "A round lens follows the mouse and magnifies what is under it from a picture of the screen: a click or R takes a new one, the rest of the screen stays live. Inside: wheel — closer/farther, Shift+wheel — size, right click or Esc — away.") : I18n.t("Живая лупа: стекло рядом с курсором показывает то, что вокруг него, кадр за кадром — видео, текст, всё живое. Рядом, а не поверх: niri отдаёт кадр экрана вместе с самой лупой, и стекло над тем же местом показывало бы само себя. У края экрана стекло перебегает на другую сторону. Внутри: колесо — ближе/дальше, Shift+колесо — размер, ПКМ или Esc — убрать.", "A live lens: a glass beside the pointer shows what is around it frame by frame — video, text, everything live. Beside, not on top: niri's frame of the screen has the lens in it too, so a glass over the same spot would show itself. Near an edge it hops to the other side. Inside: wheel — closer/farther, Shift+wheel — size, right click or Esc — away.")
        }
        SettingRow {
            label: I18n.t("Как увеличивает", "How it magnifies")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Живая, сбоку", "Live, beside"),
                        "value": "live"
                    },
                    {
                        "label": I18n.t("Снимок", "A picture"),
                        "value": "snapshot"
                    }
                ]
                currentValue: Config.lens.mode || "live"
                onActivated: v => Config.lens.mode = v
            }
        }
        SettingRow {
            label: I18n.t("Клавиши", "Keys")
            hint: Lens.log !== "" ? Lens.log : I18n.t("Meta+Alt+= ближе (и открыть), Meta+Alt+- дальше, Meta+Alt+0 убрать; Meta+= и Meta+- у niri заняты шириной колонки", "Meta+Alt+= closer (and open), Meta+Alt+- farther, Meta+Alt+0 away; niri uses Meta+= and Meta+- for the column width")
            Row {
                spacing: Theme.u * 3
                PxToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Config.lens.keys
                    onToggled: c => Config.lens.keys = c
                }
                PxButton {
                    anchors.verticalCenter: parent.verticalCenter
                    compact: true
                    icon: "search"
                    text: I18n.t("Попробовать", "Try it")
                    onClicked: Lens.cmd("toggle", "")
                }
            }
        }
        SettingRow {
            label: I18n.t("Увеличение", "Magnification")
            hint: I18n.t("с каким открывается; дальше — клавишами и колесом", "What it opens with; the keys and the wheel change it")
            PxSegmented {
                model: [1.5, 2, 3, 4, 6].map(z => ({
                            "label": "×" + z,
                            "value": z
                        }))
                currentValue: Config.lens.zoom
                onActivated: v => Config.lens.zoom = v
            }
        }
        SettingRow {
            label: I18n.t("Размер", "Size")
            PxSlider {
                width: parent.width
                from: 160
                to: 700
                stepSize: 20
                suffix: " px"
                value: Config.lens.size
                live: false
                onReleased: v => Config.lens.size = v
            }
        }
        SettingRow {
            label: I18n.t("Форма", "Shape")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Круг", "Circle"),
                        "value": "circle"
                    },
                    {
                        "label": I18n.t("Квадрат", "Square"),
                        "value": "square"
                    }
                ]
                currentValue: Config.lens.shape
                onActivated: v => Config.lens.shape = v
            }
        }
        SettingRow {
            label: I18n.t("Чёткие пиксели", "Sharp pixels")
            hint: I18n.t("выключи — будет сглаживание, как в KDE", "Off: smoothed, like KDE")
            PxToggle {
                checked: Config.lens.crisp
                onToggled: c => Config.lens.crisp = c
            }
        }
        SettingRow {
            visible: Config.lens.mode === "snapshot"
            label: I18n.t("Обновлять снимок", "Retake the picture")
            hint: I18n.t("лупа на миг прячется и снимает экран заново", "The lens hides for a moment and takes the screen again")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("по клику", "on a click"),
                        "value": 0
                    },
                    {
                        "label": I18n.t("раз в 1 с", "every 1 s"),
                        "value": 1
                    },
                    {
                        "label": I18n.t("раз в 3 с", "every 3 s"),
                        "value": 3
                    }
                ]
                currentValue: Config.lens.refresh
                onActivated: v => Config.lens.refresh = v
            }
        }
    }

    PxText {
        width: parent.width
        wrapMode: Text.Wrap
        text: InputConfig.log
        dim: true
    }
}
