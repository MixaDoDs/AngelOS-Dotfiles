// The settings once in MousePage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// The mouse (niri's input.kdl, like the keyboard) and the lens at the pointer.
CatPage {
    id: page
    heading: I18n.t("Мышь и лупа", "Mouse and lens")
    subtitle: I18n.t("Скорость и ускорение мыши. Ниже — лупа у курсора.", "Mouse speed and acceleration. Below: the lens at the pointer.")
    CatGroup {
        name: "mouse"
        title: I18n.t("Мышь", "Mouse")
        icon: "mouse"
        CatChoice {
            label: I18n.t("Ускорение", "Acceleration")
            hint: I18n.t("Плоское — курсор идёт ровно за рукой. Адаптивное — быстрый взмах уносит дальше.", "Flat: the pointer follows your hand evenly. Adaptive: a quick flick goes further.")
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
        CatSlider {
            label: I18n.t("Чувствительность", "Sensitivity")
            from: -1
            to: 1
            stepSize: 0.05
            decimals: 2
            value: InputConfig.accelSpeed
            onReleased: v => InputConfig.save({
                    "accelSpeed": v
                })
        }
        // set where the windows are laid out (Windows → Layout); here a link to it
        CatLink {
            // angel-niri's Desktop: focus follows clicks only, the setting is hidden there
            present: !(Niri.nativeMinimize && WindowConfig.floatAll)
            label: I18n.t("Фокус следует за мышью", "Focus follows mouse")
            hint: InputConfig.focusFollowsMouse ? I18n.t("включено", "on") : I18n.t("выключено", "off")
            page: "windows"
            group: "layout"
        }
    }
    // a fast mouse in games (.local/bin/mouse-coalesce, while niri-game-mode sees a game)
    CatGroup {
        name: "games"
        title: I18n.t("Мышь в играх", "The mouse in games")
        icon: "gamepad"
        CatChoice {
            label: I18n.t("Частота в играх", "Rate in games")
            hint: I18n.t("Мышь на 4–8 кГц тормозит тяжёлые игры. В игре движение прореживается до этой частоты.", "A 4–8 kHz mouse slows heavy games. In a game, motion is thinned to this rate.")
            model: [
                {"label": I18n.t("как есть", "as is"), "value": 0},
                {"label": "1000", "value": 1000},
                {"label": "2000", "value": 2000},
                {"label": "4000", "value": 4000}
            ]
            currentValue: Config.gaming.mouseRate || 0
            onActivated: v => {
                Config.gaming.mouseRate = v;
                if (v > 0)
                    Quickshell.execDetached(["sh", "-c", 'python3 "$1" set mouse on >/dev/null; exit 0', "sh", Quickshell.shellDir + "/scripts/features.py"]);
            }
        }
        CatField {
            label: I18n.t("Какая мышь", "Which mouse")
            hint: I18n.t("пусто — первая USB-мышь; если не та, впиши часть её названия", "Empty: the first USB mouse; if it's the wrong one, type a part of its name")
            text: Config.gaming.mouseDevice || ""
            placeholder: I18n.t("первая мышь", "the first mouse")
            onEditingFinished: Config.gaming.mouseDevice = text.trim()
        }
    }
    // the lens at the pointer (services/Lens)
    CatGroup {
        name: "lens-at-pointer"
        title: I18n.t("Лупа у курсора", "Lens at the pointer")
        icon: "search"
        CatNote {
            dim: true
            text: Config.lens.mode === "snapshot" ? I18n.t("Лупа едет за мышью и увеличивает снимок экрана: клик или R — новый снимок. Колесо — ближе/дальше, Shift+колесо — размер, ПКМ или Esc — убрать.", "The lens follows the mouse over a snapshot of the screen: click or R for a new one. Wheel: closer/further, Shift+wheel: size, right click or Esc: away.") : I18n.t("Стекло рядом с курсором показывает, что вокруг него, вживую. Колесо — ближе/дальше, Shift+колесо — размер, ПКМ или Esc — убрать.", "A glass beside the pointer shows what is around it, live. Wheel: closer/further, Shift+wheel: size, right click or Esc: away.")
        }
        CatChoice {
            label: I18n.t("Как увеличивает", "How it magnifies")
            hint: I18n.t("Живая — окошко рядом с курсором. Снимок — замирает картинка, её можно рассмотреть.", "Live: a window beside the pointer. A picture: the screen freezes for a close look.")
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
        CatToggle {
            label: I18n.t("Клавиши", "Keys")
            hint: Lens.log !== "" ? Lens.log : I18n.t("Win+Alt+= ближе (и открыть), Win+Alt+- дальше, Win+Alt+0 убрать", "Win+Alt+= closer (and open), Win+Alt+- further, Win+Alt+0 away")
            checked: Config.lens.keys
            onToggled: c => Config.lens.keys = c
            CatButton {
                compact: true
                icon: "search"
                text: I18n.t("Попробовать", "Try it")
                onClicked: Lens.cmd("toggle", "")
            }
        }
        CatChoice {
            label: I18n.t("Увеличение", "Magnification")
            hint: I18n.t("с каким открывается; дальше — клавишами и колесом", "What it opens with; the keys and the wheel change it")
            model: [1.5, 2, 3, 4, 6].map(z => ({
                        "label": "×" + z,
                        "value": z
                    }))
            currentValue: Config.lens.zoom
            onActivated: v => Config.lens.zoom = v
        }
        CatSlider {
            label: I18n.t("Размер лупы", "Magnifier size")
            from: 160
            to: 700
            stepSize: 20
            suffix: " px"
            value: Config.lens.size
            live: false
            onReleased: v => Config.lens.size = v
        }
        CatChoice {
            label: I18n.t("Форма", "Shape")
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
        CatToggle {
            label: I18n.t("Чёткие пиксели", "Sharp pixels")
            hint: I18n.t("выключи — будет сглаживание, как в KDE", "Off: smoothed, like KDE")
            checked: Config.lens.crisp
            onToggled: c => Config.lens.crisp = c
        }
        CatChoice {
            present: Config.lens.mode === "snapshot"
            label: I18n.t("Обновлять снимок", "Retake the picture")
            hint: I18n.t("лупа на миг прячется и снимает экран заново", "The lens hides for a moment and takes the screen again")
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
    CatNote {
        text: InputConfig.log
        dim: true
    }
}
