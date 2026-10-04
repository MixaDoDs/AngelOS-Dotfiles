import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

PxPage {
    id: page
    // the Start looks that fill the screen (no position, no size)
    readonly property bool startFull: ["fullscreen", "xmb", "wii"].includes(Config.bar.startStyle)
    heading: I18n.t("Панель и «Пуск»", "Bar and Start")
    subtitle: I18n.t("Шесть видов: таскбар как в Win98, полоса сверху, остров, док, капсулы и Windose. Всё остальное — по ссылкам ниже.", "Six styles: a Win98 taskbar, a strip on top, an island, a dock, capsules and Windose. Everything else is behind the links below.")

    PxGroup {
        name: "style"
        title: I18n.t("Стиль", "Style")
        icon: "window"
        width: parent.width
        SettingRow {
            id: barStyleRow
            preview: "BarStyle"
            label: I18n.t("Вид панели", "Bar style")
            PxCombo {
                width: Math.min(parent.width, Theme.u * 140)
                model: [
                    {
                        "label": I18n.t("Таскбар", "Taskbar"),
                        "value": "taskbar"
                    },
                    {
                        "label": I18n.t("Полоса", "Strip"),
                        "value": "top"
                    },
                    {
                        "label": I18n.t("Остров", "Island"),
                        "value": "island"
                    },
                    {
                        "label": I18n.t("Док", "Dock"),
                        "value": "dock"
                    },
                    {
                        "label": I18n.t("Капсулы", "Capsules"),
                        "value": "capsules"
                    },
                    {
                        "label": "Windose",
                        "value": "windose"
                    }
                ]
                currentValue: Config.bar.style
                onActivated: v => {
                    Config.bar.style = v;
                    barStyleRow.show(v, ({
                            "taskbar": I18n.t("таскбар", "taskbar"),
                            "top": I18n.t("полоса", "strip"),
                            "island": I18n.t("остров", "island"),
                            "dock": I18n.t("док", "dock"),
                            "capsules": I18n.t("капсулы", "capsules"),
                            "windose": "Windose"
                        })[v]);
                }
            }
        }
        SettingRow {
            visible: Config.bar.style === "taskbar"
            label: I18n.t("Автоскрытие", "Auto-hide")
            hint: I18n.t("панель уезжает вниз и оставляет тонкую линию; подведи мышь к нижнему краю — вернётся. Окна получают весь экран", "The bar slides down leaving a thin line; move the pointer to the bottom edge to bring it back. Windows get the whole screen")
            PxToggle {
                checked: Config.bar.autoHide
                onToggled: c => Config.bar.autoHide = c
            }
        }
        SettingRow {
            visible: Config.bar.style === "taskbar" && Config.bar.autoHide
            label: I18n.t("Прятать через", "Hide after")
            PxSlider {
                width: Math.min(parent.width, Theme.u * 120)
                from: 200
                to: 3000
                stepSize: 100
                value: Config.bar.autoHideMs
                valueScale: 0.001
                decimals: 1
                suffix: I18n.t(" с", " s")
                onMoved: v => Config.bar.autoHideMs = Math.round(v)
            }
        }
        SettingRow {
            label: I18n.t("Подписывать окна", "Show window titles")
            hint: I18n.t("подписи видны, пока хватает места; дальше только иконки, потом прокрутка. Выключи — всегда иконки", "Titles show while there is room, then icons only, then scrolling. Off: always icons")
            PxToggle {
                checked: Config.bar.taskLabels
                onToggled: c => Config.bar.taskLabels = c
            }
        }
        SettingRow {
            visible: Config.bar.taskLabels
            label: I18n.t("Ширина кнопок окон", "Window button width")
            hint: I18n.t("мин и макс: кнопки сужаются, когда окон много", "min and max: buttons shrink when many windows are open")
            Column {
                width: parent.width
                spacing: Theme.u * 2
                PxSlider {
                    width: parent.width
                    from: 16
                    to: 120
                    stepSize: 2
                    value: Config.bar.taskMinWidth
                    valueScale: Theme.u
                    suffix: " px ↓"
                    onMoved: v => {
                        Config.bar.taskMinWidth = v;
                        if (Config.bar.taskMaxWidth < v)
                            Config.bar.taskMaxWidth = v;
                    }
                }
                PxSlider {
                    width: parent.width
                    from: 30
                    to: 200
                    stepSize: 2
                    value: Config.bar.taskMaxWidth
                    valueScale: Theme.u
                    suffix: " px ↑"
                    onMoved: v => {
                        Config.bar.taskMaxWidth = v;
                        if (Config.bar.taskMinWidth > v)
                            Config.bar.taskMinWidth = v;
                    }
                }
            }
        }
        SettingRow {
            label: I18n.t("Воркспейсы на панели", "Workspaces on the bar")
            hint: I18n.t("сердечки, иконки открытых приложений или всё вместе", "hearts, icons of open apps, or both")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Сердечки", "Hearts"),
                        "value": "hearts",
                        "icon": "heart"
                    },
                    {
                        "label": I18n.t("Иконки", "Icons"),
                        "value": "icons",
                        "icon": "window"
                    },
                    {
                        "label": I18n.t("Оба", "Both"),
                        "value": "both"
                    }
                ]
                currentValue: Config.bar.workspaceStyle
                onActivated: v => Config.bar.workspaceStyle = v
            }
        }
        SettingRow {
            visible: Config.bar.workspaceStyle !== "hearts"
            label: I18n.t("Иконок на воркспейс", "Icons per workspace")
            PxSpin {
                from: 1
                to: 6
                value: Config.bar.workspaceIcons
                onMoved: v => Config.bar.workspaceIcons = v
            }
        }
        SettingRow {
            label: I18n.t("Мониторы", "Monitors")
            hint: I18n.t("ничего не выбрано = на всех", "No selection = all displays")
            Flow {
                width: parent.width
                spacing: Theme.u * 6
                Repeater {
                    model: Quickshell.screens
                    PxCheck {
                        required property var modelData
                        text: modelData.name
                        checked: (Config.bar.screens || []).includes(modelData.name)
                        onToggled: c => {
                            const l = (Config.bar.screens || []).filter(s => s !== modelData.name);
                            if (c)
                                l.push(modelData.name);
                            Config.bar.screens = l;
                        }
                    }
                }
            }
        }
    }

    PxGroup {
        name: "contents"
        title: I18n.t("Содержимое", "Contents")

        advanced: true
        icon: "layers"
        width: parent.width
        SettingRow {
            label: I18n.t("Кнопки окон", "Window buttons")
            PxToggle {
                checked: Config.bar.showWindows
                onToggled: c => Config.bar.showWindows = c
            }
        }
        SettingRow {
            label: I18n.t("Окна со всех воркспейсов", "Windows from all workspaces")
            PxToggle {
                checked: Config.bar.allWindows
                onToggled: c => Config.bar.allWindows = c
            }
        }
        SettingRow {
            label: I18n.t("Мини-плеер", "Mini player")
            PxToggle {
                checked: Config.bar.showMedia
                onToggled: c => Config.bar.showMedia = c
            }
        }
        SettingRow {
            label: I18n.t("Формат часов", "Clock format")
            hint: I18n.t("«Авто»: 12 часов (AM/PM) на английском, 24 — на русском", "“Auto”: 12-hour (AM/PM) in English, 24-hour in Russian")
            PxSegmented {
                model: [
                    {
                        "value": "auto",
                        "label": I18n.t("Авто", "Auto")
                    },
                    {
                        "value": "24",
                        "label": I18n.t("24 ч", "24 h")
                    },
                    {
                        "value": "12",
                        "label": "12 AM/PM"
                    }
                ]
                currentValue: Config.bar.clockFormat
                onActivated: v => Config.bar.clockFormat = v
            }
        }
        SettingRow {
            label: I18n.t("Секунды в часах", "Show seconds")
            PxToggle {
                checked: Config.bar.showSeconds
                onToggled: c => Config.bar.showSeconds = c
            }
        }
        SettingRow {
            label: I18n.t("Компактно на вертикальных", "Compact on portrait displays")
            hint: I18n.t("узкие экраны: без плеера, окна иконками", "Narrow screens: compact player and window icons")
            PxToggle {
                checked: Config.bar.compactOnVertical
                onToggled: c => Config.bar.compactOnVertical = c
            }
        }
    }

    PxGroup {
        name: "layout"
        title: I18n.t("Раскладка", "Layout")

        advanced: true
        icon: "layers"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: I18n.t("Перетаскивай элементы между частями панели. «Окна» растягиваются на свободное место слева (или по содержимому — настройка ниже), «Лирика» лучше всего смотрится в центре. Виджеты новых плагинов сами появляются справа.", "Drag widgets between sections. Windows use the free space on the left (or only what they need — below); lyrics fit best in the center. New plugin widgets appear on the right.")
            dim: true
        }
        BarLayoutEditor {
            width: parent.width
        }
        SettingRow {
            label: I18n.t("Ширина «Окон»", "“Windows” width")
            hint: Config.bar.tasksWidth === "compact" ? I18n.t("по кнопкам открытых окон — то, что после «Окон», встаёт сразу за ними", "As wide as the open windows' buttons: whatever comes after “Windows” sits right next to them") : I18n.t("занимает всё свободное место слева", "Takes all the free room on the left")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Растягивать", "Fill"),
                        "value": "fill"
                    },
                    {
                        "label": I18n.t("По содержимому", "Compact"),
                        "value": "compact"
                    }
                ]
                currentValue: Config.bar.tasksWidth || "fill"
                onActivated: v => Config.bar.tasksWidth = v
            }
        }
        PxButton {
            text: I18n.t("Как было", "Reset")
            icon: "refresh"
            onClicked: BarLayout.reset()
        }
    }

    PxGroup {
        name: "icons"
        title: I18n.t("Иконки", "Icons")

        advanced: true
        icon: "palette"
        width: parent.width
        SettingRow {
            label: I18n.t("Цвет иконок в трее", "Tray icon colors")
            hint: I18n.t("перекрасить под тему, чтобы не было радуги", "Use the current theme for a consistent tray")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Как есть", "Original"),
                        "value": "off"
                    },
                    {
                        "label": I18n.t("Моно", "Monochrome"),
                        "value": "mono"
                    },
                    {
                        "label": I18n.t("Акцент", "Accent"),
                        "value": "accent"
                    }
                ]
                currentValue: Config.bar.trayTint
                onActivated: v => Config.bar.trayTint = v
            }
        }
        SettingRow {
            label: I18n.t("Плотность трея", "Tray density")
            hint: ({
                    "compact": I18n.t("6 в ряд, мелкие иконки впритык", "6 per row, small icons close together"),
                    "normal": I18n.t("5 в ряд, как было", "5 per row, as before"),
                    "airy": I18n.t("4 в ряд, иконки крупнее и с отступами", "4 per row, bigger icons with room around them"),
                    "spacious": I18n.t("3 в ряд, крупно и просторно — легко попасть мышкой", "3 per row, big and roomy — easy to hit")
                })[Config.bar.trayDensity] || ""
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Плотно", "Compact"),
                        "value": "compact"
                    },
                    {
                        "label": I18n.t("Обычно", "Normal"),
                        "value": "normal"
                    },
                    {
                        "label": I18n.t("Свободно", "Airy"),
                        "value": "airy"
                    },
                    {
                        "label": I18n.t("Просторно", "Spacious"),
                        "value": "spacious"
                    }
                ]
                currentValue: Config.bar.trayDensity || "normal"
                onActivated: v => Config.bar.trayDensity = v
            }
        }
        SettingRow {
            label: I18n.t("Правая часть панели", "Right side of the bar")
            hint: ({
                    "compact": I18n.t("значки вплотную, кнопки уже — больше места окнам и лирике", "icons packed close, narrower buttons — more room for windows and lyrics"),
                    "normal": I18n.t("как было", "as before"),
                    "airy": I18n.t("с большими промежутками — легче попасть мышкой", "wide gaps — easier to hit")
                })[Config.bar.rightDensity || "normal"] || ""
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Плотно", "Compact"),
                        "value": "compact"
                    },
                    {
                        "label": I18n.t("Обычно", "Normal"),
                        "value": "normal"
                    },
                    {
                        "label": I18n.t("Свободно", "Airy"),
                        "value": "airy"
                    }
                ]
                currentValue: Config.bar.rightDensity || "normal"
                onActivated: v => Config.bar.rightDensity = v
            }
        }
        SettingRow {
            label: I18n.t("Красить и кнопки окон", "Tint window icons")
            hint: I18n.t("активное окно остаётся в своих цветах", "The focused window keeps its original colors")
            PxToggle {
                checked: Config.bar.tintTasks
                onToggled: c => Config.bar.tintTasks = c
            }
        }
    }

    PxGroup {
        name: "sidebar-experimental"
        title: I18n.t("Сайдбар (эксперимент)", "Sidebar (experimental)")

        advanced: true
        icon: "layers"
        width: parent.width
        SettingRow {
            label: I18n.t("Включить сайдбар", "Enable the sidebar")
            hint: I18n.t("закладка на краю экрана: клик — открыть, перетащи — переставить (прилипает к ближайшему краю)", "A tab on the screen edge: click to open, drag to move — it snaps to the nearest edge")
            PxToggle {
                checked: Config.sidebar.enabled
                onToggled: c => Config.sidebar.enabled = c
            }
        }
        SettingRow {
            visible: Config.sidebar.enabled
            label: I18n.t("Экран", "Screen")
            PxCombo {
                width: Theme.u * 100
                model: [{
                        "label": I18n.t("Основной", "Primary"),
                        "value": ""
                    }].concat(Quickshell.screens.map(s => ({
                            "label": s.name,
                            "value": s.name
                        })))
                currentValue: Config.sidebar.screen
                onActivated: v => Config.sidebar.screen = v
            }
        }
        SettingRow {
            visible: Config.sidebar.enabled
            label: I18n.t("Разделы", "Sections")
            Flow {
                width: parent.width
                spacing: Theme.u * 5
                Repeater {
                    model: [["toggles", I18n.t("Переключатели", "Toggles")], ["media", I18n.t("Музыка", "Media")], ["sound", I18n.t("Звук", "Sound")], ["system", I18n.t("Система", "System")], ["ai", I18n.t("AI-лимиты", "AI limits")]]
                    PxCheck {
                        required property var modelData
                        text: modelData[1]
                        checked: Sidebar.has(modelData[0])
                        onToggled: c => Sidebar.setSection(modelData[0], c)
                    }
                }
            }
        }
        Row {
            visible: Config.sidebar.enabled
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Открыть", "Open")
                icon: "layers"
                onClicked: {
                    Shell.settingsOpen = false;
                    Sidebar.open = true;
                }
            }
            PxButton {
                text: I18n.t("Закладку — на место", "Reset tab position")
                icon: "refresh"
                onClicked: {
                    Config.sidebar.edge = "right";
                    Config.sidebar.offset = 0.5;
                }
            }
        }
    }

    PxGroup {
        name: "start-button"
        title: I18n.t("Кнопка «Пуск»", "Start button")
        advanced: true
        icon: "pill"
        width: parent.width
        SettingRow {
            id: startStyleRow
            readonly property var styles: [
                {
                    "label": I18n.t("Классика", "Classic"),
                    "value": "classic",
                    "hint": I18n.t("список как в Win98 у кнопки", "A Win98 list next to the button")
                },
                {
                    "label": "Windows 11",
                    "value": "win11",
                    "hint": I18n.t("по центру: поиск, закреплённые (ПКМ — закрепить), все приложения, питание", "Centred: search, pinned apps (right-click pins), all apps, power")
                },
                {
                    "label": I18n.t("Как iPhone", "iPhone-like"),
                    "value": "fullscreen",
                    "hint": I18n.t("на весь экран, как на iPhone: страницы иконок, док, колесо листает", "Full screen like an iPhone: pages of icons, a dock, the wheel flips pages")
                },
                {
                    "label": "PSP XMB",
                    "value": "xmb",
                    "hint": I18n.t("на весь экран, как PSP: разделы в строку, пункты столбиком, волна на фоне; ←→ ↑↓, печатай — поиск", "Full screen like a PSP: sections in a row, items in a column, the wave behind; ←→ ↑↓, type to search")
                },
                {
                    "label": "Windose ♡",
                    "value": "windose",
                    "hint": I18n.t("розовое окно NEEDY GIRL OVERDOSE у кнопки: закреплённые наклейками, все программы с сердечками", "A pink NEEDY GIRL OVERDOSE window by the button: pinned apps as stickers, every program with hearts")
                },
                {
                    "label": I18n.t("Wii «Каналы»", "Wii channels"),
                    "value": "wii",
                    "hint": I18n.t("на весь экран, как Wii: каналы 4×3, часы на дуге внизу, кнопки настроек и питания", "Full screen like a Wii: 4×3 channels, the clock on the curved band, settings and power buttons")
                },
                {
                    "label": "Spotlight",
                    "value": "spotlight",
                    "hint": I18n.t("только строка поиска посередине: приложения, настройки, папки, действия, калькулятор", "Just a search pill in the middle: apps, settings, folders, actions, the calculator")
                }
            ]
            preview: "StartMenu"
            label: I18n.t("Вид меню", "Menu style")
            hint: (styles.find(s => s.value === (Config.bar.startStyle || "classic")) || styles[0]).hint
            Flow {
                width: parent.width
                spacing: Theme.u * 2
                Repeater {
                    model: startStyleRow.styles
                    PxButton {
                        required property var modelData
                        text: modelData.label
                        checked: (Config.bar.startStyle || "classic") === modelData.value
                        onClicked: {
                            Config.bar.startStyle = modelData.value;
                            startStyleRow.show(modelData.value, modelData.label);
                        }
                    }
                }
            }
        }
        SettingRow {
            id: taskbarAlignRow
            visible: Config.bar.style !== "island"
            label: I18n.t("Панель задач", "Taskbar alignment")
            hint: Config.bar.taskbarAlign === "center" ? I18n.t("как в Windows 11: «Пуск» и окна посередине, лирика — слева; меню выезжает снизу", "Like Windows 11: Start and windows in the middle, lyrics on the left; the menu slides up") : I18n.t("«Пуск» и окна у левого края", "Start and windows at the left edge")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Слева", "Left"),
                        "value": "left"
                    },
                    {
                        "label": I18n.t("По центру", "Center"),
                        "value": "center"
                    }
                ]
                currentValue: Config.bar.taskbarAlign || "left"
                onActivated: v => Config.bar.taskbarAlign = v
            }
        }
        SettingRow {
            id: startPosRow
            preview: "StartMenu"
            visible: !page.startFull && Config.bar.startStyle !== "spotlight"
            label: I18n.t("Где открывать", "Position")
            hint: I18n.t("«Авто»: классика — у кнопки, Windows 11 — посередине", "Auto: classic at the button, Windows 11 in the middle")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Авто", "Auto"),
                        "value": "auto"
                    },
                    {
                        "label": I18n.t("Слева", "Left"),
                        "value": "left"
                    },
                    {
                        "label": I18n.t("Посередине", "Center"),
                        "value": "center"
                    },
                    {
                        "label": I18n.t("Справа", "Right"),
                        "value": "right"
                    }
                ]
                currentValue: Config.bar.startAlign || "auto"
                onActivated: v => {
                    Config.bar.startAlign = v;
                    startPosRow.show(v, ({
                            "auto": I18n.t("авто", "auto"),
                            "left": I18n.t("слева", "left"),
                            "center": I18n.t("посередине", "center"),
                            "right": I18n.t("справа", "right")
                        })[v]);
                }
            }
        }
        SettingRow {
            label: I18n.t("Поиск", "Search")
            hint: I18n.t("что ещё находит поиск «Пуска» и Win+Space, кроме приложений", "what Start's search and Win+Space find besides apps")
            Column {
                width: parent.width
                spacing: Theme.u * 3
                PxToggle {
                    text: I18n.t("Настройки — вперемешку с приложениями", "Settings, mixed with apps")
                    checked: Config.launcher.settings !== false
                    onToggled: v => Config.launcher.settings = v
                }
                PxToggle {
                    text: I18n.t("Калькулятор: 2+2·3, 15% от 200, 10 км в милях, 100 usd в rub", "Calculator: 2+2·3, 15% of 200, 10 km in mi, 100 usd in rub")
                    checked: Config.launcher.calc !== false
                    onToggled: v => Config.launcher.calc = v
                }
            }
        }
        SettingRow {
            label: I18n.t("Открывать по нажатию Meta", "Open with a Meta tap")
            hint: I18n.t("короткое нажатие Super — меню «Пуск», как в Windows. Зажатая клавиша и сочетания (Mod+…) меню не открывают.", "A short Super tap opens Start, like on Windows. Holding it or shortcuts (Mod+…) never do.")
            PxToggle {
                checked: Config.bar.metaTap
                onToggled: c => Config.bar.metaTap = c
            }
        }
        SettingRow {
            visible: Config.bar.metaTap
            label: I18n.t("Самое долгое нажатие", "Longest tap")
            hint: I18n.t("дольше — это уже удержание", "Anything longer counts as a hold")
            PxSlider {
                width: parent.width
                from: 150
                to: 1000
                stepSize: 50
                value: Config.bar.metaTapMs
                suffix: I18n.t(" мс", " ms")
                onReleased: v => Config.bar.metaTapMs = v
            }
        }
        SettingRow {
            visible: Config.bar.metaTap
            label: I18n.t("Поверх полноэкранных окон", "Over fullscreen windows")
            hint: I18n.t("выключено — игры и видео на весь экран не прерываются", "Off: fullscreen games and video are never interrupted")
            PxToggle {
                checked: Config.bar.metaTapFullscreen
                onToggled: c => Config.bar.metaTapFullscreen = c
            }
        }
        PxText {
            visible: Config.bar.metaTap && MetaTap.status !== "ready"
            width: parent.width
            wrapMode: Text.Wrap
            color: MetaTap.status === "noperm" || MetaTap.status === "noevdev" || MetaTap.status === "error" ? Theme.danger : Theme.textDim
            text: ({
                    "noperm": I18n.t("Нет доступа к клавиатурам. Добавь себя в группу input: sudo usermod -aG input $USER и перезайди.", "No access to keyboards. Join the input group: sudo usermod -aG input $USER, then log in again."),
                    "noevdev": I18n.t("Нужен python-evdev: sudo pacman -S python-evdev", "python-evdev is required: sudo pacman -S python-evdev"),
                    "error": I18n.t("Слушатель клавиши остановился, перезапускаю…", "The key listener stopped; restarting…"),
                    "off": Shell.dev ? I18n.t("В dev-режиме выключено (ANGELOS_DEV_TAP=1 включит)", "Off in dev mode (set ANGELOS_DEV_TAP=1)") : "",
                    "starting": "…"
                })[MetaTap.status] || ""
        }
        PxText {
            visible: Config.bar.metaTap
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("niri не умеет назначать действие на одиночный модификатор, поэтому angelOS слушает клавиатуры сам (только чтение). Запоминается лишь «Meta нажата» и «было что-то ещё» — какие клавиши нажимались, никуда не пишется.", "niri cannot bind a bare modifier, so angelOS reads keyboards itself (read-only). It only tracks “Meta is down” and “something else happened”; which keys you press is never stored.")
        }
    }

    // the avatar and the deep settings of every Start look (StartTuner, services/StartPrefs)
    PxGroup {
        name: "start-avatar-fine"
        title: I18n.t("«Пуск»: аватарка и тонкая настройка", "Start: avatar and fine-tuning")
        advanced: true
        icon: "star"
        width: parent.width
        StartTuner {
            width: parent.width
        }
    }

    PxGroup {
        name: "angelos-logo"
        title: I18n.t("Логотип angelOS", "angelOS logo")

        advanced: true
        icon: "heart"
        width: parent.width
        // one choice, as pictures with their names (issue #15: buttons and pictures disagreed)
        SettingRow {
            label: I18n.t("Надпись", "Wordmark")
            hint: I18n.t("на кнопке «Пуск», в меню, на загрузке, экране блокировки и в настройках", "on the Start button, in Start, on the boot and lock screens and in Settings")
            Flow {
                width: parent.width
                spacing: Theme.u * 6
                Repeater {
                    // Hell is hell's own: offered only while the demon rules (or while it
                    // is the wordmark in use — the portal lets it stay in heaven)
                    model: [
                        {
                            "value": "classic",
                            "label": "Classic 95"
                        },
                        {
                            "value": "angel",
                            "label": "Angel +"
                        },
                        {
                            "value": "windose",
                            "label": "Windose"
                        },
                        {
                            "value": "hell",
                            "label": "Hell"
                        },
                        {
                            "value": "chrome",
                            "label": "Y2K Chrome"
                        }
                    ].filter(v => v.value !== "hell" || Angel.hellShown || (Config.bar.logoStyle === "hell" && Angel.hellAllowed))
                    PxButton {
                        id: logoCard
                        required property var modelData
                        width: Math.max(preview.implicitWidth, caption.implicitWidth) + Theme.u * 12
                        height: preview.implicitHeight + caption.implicitHeight + Theme.u * 14
                        checked: Config.bar.logoStyle === modelData.value
                        onClicked: Config.bar.logoStyle = modelData.value
                        AngelLogo {
                            id: preview
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Theme.u * 5
                            variant: logoCard.modelData.value
                        }
                        PxText {
                            id: caption
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.u * 4
                            text: (logoCard.checked ? "♡ " : "") + logoCard.modelData.label
                            kind: "tiny"
                            font.bold: logoCard.checked
                        }
                    }
                }
            }
        }
        SettingRow {
            label: I18n.t("Значок", "Emblem")
            hint: Angel.hellShown ? I18n.t("пока правит демоница, нимб становится рожками", "while the demon rules, the halo turns into horns") : ""
            Flow {
                width: parent.width
                spacing: Theme.u * 6
                Repeater {
                    model: [
                        {
                            "value": "heart",
                            "label": I18n.t("Сердце", "Heart")
                        },
                        {
                            "value": "pill",
                            "label": I18n.t("Таблетка", "Pill")
                        },
                        {
                            "value": "star",
                            "label": I18n.t("Звезда", "Star")
                        },
                        {
                            "value": "cd",
                            "label": "CD"
                        },
                        {
                            "value": "kitty",
                            "label": I18n.t("Котик", "Kitty")
                        }
                    ]
                    PxButton {
                        id: emblemCard
                        required property var modelData
                        width: Math.max(emblemPreview.implicitWidth, emblemCaption.implicitWidth) + Theme.u * 12
                        height: emblemPreview.implicitHeight + emblemCaption.implicitHeight + Theme.u * 14
                        checked: Config.bar.logoEmblem === modelData.value
                        onClicked: Config.bar.logoEmblem = modelData.value
                        AngelLogo {
                            id: emblemPreview
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Theme.u * 5
                            emblemOnly: true
                            emblemName: emblemCard.modelData.value
                        }
                        PxText {
                            id: emblemCaption
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.u * 4
                            text: (emblemCard.checked ? "♡ " : "") + emblemCard.modelData.label
                            kind: "tiny"
                            font.bold: emblemCard.checked
                        }
                    }
                }
            }
        }
        PxToggle {
            text: I18n.t("Надпись на кнопке «Пуск» (выключи — останется только значок)", "Wordmark on the Start button (off leaves the emblem)")
            checked: Config.bar.logoText !== false
            onToggled: c => Config.bar.logoText = c
        }
        PxToggle {
            text: I18n.t("fastfetch рисует этот значок", "fastfetch draws this emblem")
            checked: Config.bar.logoFastfetch
            onToggled: v => Config.bar.logoFastfetch = v
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: Angel.hellShown ? I18n.t("Classic 95 и Angel + — шрифтом темы, Windose, Hell и Y2K Chrome — пиксельные буквы. Цвета следуют теме (Hell всегда кровавый). Сердце в fastfetch — прежний рисунок с нимбом и таблеткой.", "Classic 95 and Angel + use the theme font; Windose, Hell and Y2K Chrome are pixel letters. Colours follow the theme (Hell is always blood red). The heart in fastfetch keeps the original drawing with the halo and pill.") : I18n.t("Classic 95 и Angel + — шрифтом темы, Windose и Y2K Chrome — пиксельные буквы. Цвета следуют теме. Сердце в fastfetch — прежний рисунок с нимбом и таблеткой.", "Classic 95 and Angel + use the theme font; Windose and Y2K Chrome are pixel letters. Colours follow the theme. The heart in fastfetch keeps the original drawing with the halo and pill.")
        }
    }
}
