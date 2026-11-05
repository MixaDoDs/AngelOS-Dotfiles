// The settings once in MacPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import qs.modules.mac
import qs.modules.settings.kit

// The Golden Gate skin's own settings (services/GoldenGate, modules/mac): its pages in Settings
// while the skin is on are put together from these groups (tree.json "mac": Dock, Appearance,
// Wallpaper, Widgets, Keyboard and mouse, Windows). The pixel skins' pages are not in that tree.
// Every number has the range GoldenGate.limits holds and every choice a list in GoldenGate.choices
// (a value out of them from the file is put back there too: both are watched by their keys);
// "Reset the theme" puts GoldenGate.themeKeys back to their defaults. A new setting: its key in
// limits or choices and in themeKeys, a line of its own each.
CatPage {
    id: page
    heading: "Golden Gate"
    subtitle: I18n.t("Рабочий стол как в macOS 27: Dock, строка меню, окна со светофором.", "The desktop as in macOS 27: the Dock, the menu bar, windows with traffic lights.")
    readonly property var lim: GoldenGate.limits
    // ---- Dock ----
    CatGroup {
        name: "dock"
        title: "Dock"
        icon: "grid"
        CatSlider {
            label: I18n.t("Размер значков", "Icon size")
            from: page.lim["mac.dockSize"][0]
            to: page.lim["mac.dockSize"][1]
            stepSize: 4
            value: Config.mac.dockSize
            suffix: " px"
            onMoved: v => {
                Config.mac.dockSize = v;
                if (Config.mac.dockMagnifySize < v)
                    Config.mac.dockMagnifySize = v;
            }
        }
        CatToggle {
            label: I18n.t("Увеличение", "Magnification")
            hint: I18n.t("значки под указателем растут, соседние — чуть меньше", "icons under the pointer grow, their neighbours a little less")
            checked: Config.mac.dockMagnify
            onToggled: v => Config.mac.dockMagnify = v
        }
        CatSlider {
            present: Config.mac.dockMagnify
            label: I18n.t("Размер при увеличении", "Magnified size")
            hint: I18n.t("До какого размера растёт значок под курсором.", "How big an icon grows under the pointer.")
            from: Math.max(page.lim["mac.dockMagnifySize"][0], Config.mac.dockSize)
            to: page.lim["mac.dockMagnifySize"][1]
            stepSize: 4
            value: Math.max(Config.mac.dockSize, Config.mac.dockMagnifySize)
            suffix: " px"
            onMoved: v => Config.mac.dockMagnifySize = v
        }
        CatChoice {
            label: I18n.t("Положение на экране", "Position on screen")
            model: [
                {
                    "label": I18n.t("Слева", "Left"),
                    "value": "left"
                },
                {
                    "label": I18n.t("Снизу", "Bottom"),
                    "value": "bottom"
                },
                {
                    "label": I18n.t("Справа", "Right"),
                    "value": "right"
                }
            ]
            currentValue: GoldenGate.dockEdge
            onActivated: v => Config.mac.dockPosition = v
        }
        CatToggle {
            label: I18n.t("Автоматически скрывать и показывать Dock", "Automatically hide and show the Dock")
            hint: I18n.t("появляется, когда указатель у края экрана", "it comes back when the pointer reaches the screen's edge")
            checked: Config.mac.dockAutohide
            onToggled: v => Config.mac.dockAutohide = v
        }
        CatChoice {
            label: I18n.t("Убирать окна в Dock с эффектом", "Minimise windows using")
            hint: I18n.t("«Джин» — окно изгибается и втекает в значок, «Масштаб» — уменьшается в него; с движением «выкл» — сразу", "Genie — the window bends and pours into its icon, Scale — it shrinks into it; with Motion off — at once")
            model: [
                {
                    "label": I18n.t("Джин", "Genie"),
                    "value": "genie"
                },
                {
                    "label": I18n.t("Масштаб", "Scale"),
                    "value": "scale"
                }
            ]
            currentValue: Config.mac.minimizeEffect === "scale" ? "scale" : "genie"
            onActivated: v => Config.mac.minimizeEffect = v
        }
        CatToggle {
            label: I18n.t("Клик по активной программе сворачивает её", "Click the app in front to minimize it")
            hint: I18n.t("как на пиксельной панели: её окно в фокусе уходит в Dock. Выключено, как на Mac: клик переходит к её следующему окну", "as on the pixel taskbar: its focused window goes to the Dock. Off, as on a Mac: the click goes to its next window")
            checked: Config.mac.dockClickMinimizes
            onToggled: v => Config.mac.dockClickMinimizes = v
        }
        CatCustom {
            label: I18n.t("Значки как в macOS", "Mac-style icons")
            hint: DockIcons.busy ? I18n.t("скачиваются…", "downloading…") : DockIcons.error ? I18n.t("не скачались: ", "not downloaded: ") + DockIcons.error : I18n.t("свободная тема MacTahoe (GPL-3.0), скачивается один раз; выключено — значки вашей темы", "the free MacTahoe theme (GPL-3.0), downloaded once; off — your theme's icons")
            CatBox {
                Row {
                    spacing: Theme.u * 2
                    PxToggle {
                        checked: Config.mac.dockMacIcons
                        onToggled: v => Config.mac.dockMacIcons = v
                    }
                    PxButton {
                        visible: Config.mac.dockMacIcons && !!DockIcons.error && !DockIcons.busy
                        text: I18n.t("Повторить", "Try again")
                        icon: "refresh"
                        onClicked: DockIcons.install()
                    }
                }
            }
        }
        CatCustom {
            label: I18n.t("Свои значки", "Your own icons")
            hint: I18n.t("файл <имя>.svg или .png в этой папке важнее значков macOS и темы: имя значка программы, её id или последняя часть id (org.gnome.Nautilus → nautilus)", "an <name>.svg or .png in this folder comes before the Mac icons and the theme: the app's icon name, its id or the id's last part (org.gnome.Nautilus → nautilus)")
            CatBox {
                PxButton {
                    text: I18n.t("Открыть папку", "Open the folder")
                    icon: "folder"
                    onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "sh", DockIcons.ownDir])
                }
            }
        }
    }
    // ---- the apps kept in the Dock, in order (the same as dragging them in the Dock) ----
    CatGroup {
        name: "dock-apps"
        id: keptGroup
        title: I18n.t("Порядок значков", "Icon order")
        icon: "grid"
        readonly property var kept: MacDockModel.apps.filter(a => a.kept)
        function move(i, d) {
            const ids = kept.map(a => a.id);
            const j = i + d;
            if (j < 0 || j >= ids.length)
                return;
            ids.splice(j, 0, ids.splice(i, 1)[0]);
            MacDockModel.setOrder(ids);
        }
        CatNote {
            dim: true
            text: I18n.t("Значки перетаскиваются в Dock; вытащи вверх — уберётся. Запущенную оставит её меню: «Оставить в Dock», любую – её меню в Spotlight.", "Drag icons into the Dock; drag one up to remove it. Keep a running app: its menu → «Keep in Dock»; any app: its menu in Spotlight.")
        }
        CatRepeat {
            model: keptGroup.kept
            delegate: Component {
                CatCustom {
                    id: keptRow
                    required property var modelData
                    required property int index
                    label: modelData.name || modelData.id
                    CatBox {
                        Flow {
                            width: parent.width
                            spacing: Theme.u * 2
                            PxButton {
                                compact: true
                                icon: "arrowUp"
                                enabled: keptRow.index > 0
                                onClicked: keptGroup.move(keptRow.index, -1)
                            }
                            PxButton {
                                compact: true
                                icon: "arrowDown"
                                enabled: keptRow.index < keptGroup.kept.length - 1
                                onClicked: keptGroup.move(keptRow.index, 1)
                            }
                            PxButton {
                                compact: true
                                icon: "close"
                                text: I18n.t("Убрать", "Remove")
                                onClicked: MacDockModel.setKept(keptRow.modelData.id, false)
                            }
                        }
                    }
                }
            }
        }
        CatButton {
            label: I18n.t("Порядок как вначале", "The order it came with")
            hint: I18n.t("файлы, Приложения, браузер, терминал, закреплённое в «Пуске», Системные настройки", "Files, Apps, the browser, the terminal, Start's pinned apps, System Settings")
            text: I18n.t("Сбросить порядок", "Reset the order")
            icon: "refresh"
            onClicked: MacDockModel.resetOrder()
        }
    }
    // ---- Appearance ----
    CatGroup {
        name: "look"
        title: I18n.t("Внешний вид", "Appearance")
        icon: "palette"
        CatChoice {
            label: I18n.t("Оформление", "Appearance")
            model: [
                {
                    "label": I18n.t("Светлое", "Light"),
                    "value": "light",
                    "icon": "sun"
                },
                {
                    "label": I18n.t("Тёмное", "Dark"),
                    "value": "dark",
                    "icon": "moon"
                },
                {
                    "label": I18n.t("Авто", "Auto"),
                    "value": "auto",
                    "icon": "sparkle"
                }
            ]
            currentValue: Config.appearance.mode
            onActivated: v => Config.appearance.mode = v
        }
        CatCustom {
            present: Config.appearance.mode === "auto"
            label: I18n.t("Светлое с … до …", "Light from … to …")
            hint: I18n.t("часы, по местному времени", "hours, local time")
            CatBox {
                Row {
                    spacing: Theme.u * 4
                    PxSpin {
                        from: page.lim["appearance.lightFrom"][0]
                        to: page.lim["appearance.lightFrom"][1]
                        value: Config.appearance.lightFrom
                        suffix: ":00"
                        onMoved: v => Config.appearance.lightFrom = v
                    }
                    PxSpin {
                        from: page.lim["appearance.darkFrom"][0]
                        to: page.lim["appearance.darkFrom"][1]
                        value: Config.appearance.darkFrom
                        suffix: ":00"
                        onMoved: v => Config.appearance.darkFrom = v
                    }
                }
            }
        }
        CatChoice {
            label: I18n.t("Цвет акцента", "Accent colour")
            model: [["blue", "Синий", "Blue"], ["purple", "Фиолетовый", "Purple"], ["pink", "Розовый", "Pink"], ["red", "Красный", "Red"], ["orange", "Оранжевый", "Orange"], ["yellow", "Жёлтый", "Yellow"], ["green", "Зелёный", "Green"], ["graphite", "Графит", "Graphite"]].map(a => ({
                        "label": I18n.t(a[1], a[2]),
                        "value": a[0]
                    }))
            currentValue: Config.mac.accent
            onActivated: v => Config.mac.accent = v
        }
        CatSlider {
            label: I18n.t("Прозрачность (Liquid Glass)", "Transparency (Liquid Glass)")
            hint: I18n.t("меню, Dock, Пункт управления: от прозрачного до тонированного", "menus, the Dock, Control Center: from clear to tinted")
            from: page.lim["mac.glass"][0]
            to: page.lim["mac.glass"][1]
            stepSize: 0.05
            value: Config.mac.glass
            valueScale: 100
            suffix: "%"
            onMoved: v => Config.mac.glass = v
        }
        CatToggle {
            label: I18n.t("Уменьшить прозрачность", "Reduce transparency")
            hint: GoldenGate.gameMode ? I18n.t("сейчас стекло и так плотное: идёт полноэкранное окно (niri-game-mode)", "the glass is solid right now anyway: a fullscreen window is up (niri-game-mode)") : I18n.t("как в Универсальном доступе macOS: плотное стекло без размытия и бликов по краю — читается легче и меньше работы видеокарте. Само включается, пока идёт полноэкранная игра", "as in macOS's Accessibility: solid glass, no blur and no edge light — easier to read and less work for the GPU. Turns on by itself while a fullscreen game runs")
            checked: Config.mac.reduceTransparency
            onToggled: v => Config.mac.reduceTransparency = v
        }
        CatToggle {
            label: I18n.t("Размытие под стеклом", "Blur behind the glass")
            hint: I18n.t("выключено — стекло почти непрозрачное, как «Уменьшить прозрачность» в macOS", "off: the glass nearly opaque, like macOS's Reduce Transparency")
            checked: Config.appearance.blur
            onToggled: v => Config.appearance.blur = v
        }
        CatChoice {
            label: I18n.t("Строка меню", "Menu bar")
            hint: Config.mac.barStyle === "islands" ? I18n.t("стеклянные островки: меню слева, значки справа, посередине Нимб, если он в строке меню", "glass islands: the menus on the left, the icons on the right, the Halo in the middle if it is in the menu bar") : I18n.t("одна полоса вдоль верха, как в macOS", "one strip along the top, as in macOS")
            model: [
                {
                    "label": I18n.t("Полоса", "Strip"),
                    "value": "bar"
                },
                {
                    "label": I18n.t("Островки", "Islands"),
                    "value": "islands"
                }
            ]
            currentValue: Config.mac.barStyle
            onActivated: v => Config.mac.barStyle = v
        }
        CatToggle {
            present: !!Config.halo.enabled
            label: I18n.t("Нимб в строке меню", "The Halo in the menu bar")
            hint: I18n.t("посередине строки, в её стекле и её высоты; сам не прячется. Выключено: Нимб сам по себе, со своей полосой (Настройки → Нимб)", "in the bar's middle, in its glass and at its height; it doesn't hide by itself. Off: the Halo on its own, with its own strip (Settings → Halo)")
            checked: Config.mac.haloInBar
            onToggled: v => Config.mac.haloInBar = v
        }
        CatToggle {
            present: Config.mac.barStyle !== "islands"
            label: I18n.t("Фон строки меню", "Menu bar background")
            hint: I18n.t("своя полоса вместо обоев под строкой", "a band of its own instead of the wallpaper under it")
            checked: Config.mac.barBackground
            onToggled: v => Config.mac.barBackground = v
        }
        CatChoice {
            label: I18n.t("Рабочие столы в строке меню", "Desktops in the menu bar")
            hint: Config.mac.barDesks === "off" ? I18n.t("в macOS их там нет; столы видны в Mission Control", "macOS has none there; the desktops are in Mission Control") : I18n.t("клик переходит на стол, колесо листает, правый клик открывает Mission Control, «+» в конце открывает новый пустой стол", "a click goes to the desktop, the wheel switches, a right click opens Mission Control, the «+» at the end opens a new empty desktop")
            model: [
                {
                    "label": I18n.t("Нет", "Off"),
                    "value": "off"
                },
                {
                    "label": I18n.t("Номера", "Numbers"),
                    "value": "numbers"
                },
                {
                    "label": I18n.t("Точки", "Dots"),
                    "value": "dots"
                }
            ]
            currentValue: Config.mac.barDesks
            onActivated: v => Config.mac.barDesks = v
        }
        CatChoice {
            present: Config.mac.barDesks !== "off"
            label: I18n.t("Где стоят рабочие столы", "Where the desktops stand")
            hint: I18n.t("слева перед эмблемой, справа перед значками программ или рядом с часами", "on the left before the emblem, on the right before the apps' icons, or by the clock")
            model: [
                {
                    "label": I18n.t("Слева", "Left"),
                    "value": "left"
                },
                {
                    "label": I18n.t("Перед значками", "Before the icons"),
                    "value": "icons"
                },
                {
                    "label": I18n.t("У часов", "By the clock"),
                    "value": "clock"
                }
            ]
            currentValue: Config.mac.barDesksAt
            onActivated: v => Config.mac.barDesksAt = v
        }
        CatChoice {
            present: Config.mac.barDesks !== "off"
            label: I18n.t("Подсветка рабочих столов", "Desktop highlighting")
            hint: Config.mac.barDesksLit === "all" ? I18n.t("стол спереди закрашен, пустые бледнее, красный стол ждёт тебя: там окно просит внимания", "the desktop in front filled, the empty ones paler, a red one waits for you: a window there asks for attention") : Config.mac.barDesksLit === "current" ? I18n.t("закрашен только стол спереди", "only the desktop in front is filled") : I18n.t("все столы выглядят одинаково", "all desktops look alike")
            model: [
                {
                    "label": I18n.t("Все состояния", "Every state"),
                    "value": "all"
                },
                {
                    "label": I18n.t("Только текущий", "Current only"),
                    "value": "current"
                },
                {
                    "label": I18n.t("Без подсветки", "None"),
                    "value": "none"
                }
            ]
            currentValue: Config.mac.barDesksLit
            onActivated: v => Config.mac.barDesksLit = v
        }
        CatChoice {
            label: I18n.t("Кнопка обзора в строке меню", "Overview button in the menu bar")
            hint: Config.mac.barOverview === "mission" ? I18n.t("открывает Mission Control angelOS: окна стола сеткой, столы полосой сверху", "opens angelOS's Mission Control: the desktop's windows in a grid, the desktops in a strip on top") : Config.mac.barOverview === "niri" ? I18n.t("открывает обзор niri, как жест на тачпаде и кнопка Mission Control в Пункте управления", "opens niri's overview, like the touchpad gesture and Control Center's Mission Control") : I18n.t("обзор открывается жестом, клавишами или из Пункта управления", "the overview opens by the gesture, the keys or from Control Center")
            model: [
                {
                    "label": I18n.t("Нет", "Off"),
                    "value": "off"
                },
                {
                    "label": I18n.t("Обзор niri", "niri's overview"),
                    "value": "niri"
                },
                {
                    "label": "Mission Control",
                    "value": "mission"
                }
            ]
            currentValue: Config.mac.barOverview
            onActivated: v => Config.mac.barOverview = v
        }
        CatChoice {
            present: Config.mac.barOverview !== "off"
            label: I18n.t("Где стоит кнопка обзора", "Where the overview button stands")
            hint: I18n.t("в одном месте со столами кнопка встаёт перед ними", "in the same place as the desktops the button goes before them")
            model: [
                {
                    "label": I18n.t("Слева", "Left"),
                    "value": "left"
                },
                {
                    "label": I18n.t("Перед значками", "Before the icons"),
                    "value": "icons"
                },
                {
                    "label": I18n.t("У часов", "By the clock"),
                    "value": "clock"
                }
            ]
            currentValue: Config.mac.barOverviewAt
            onActivated: v => Config.mac.barOverviewAt = v
        }
        CatToggle {
            label: I18n.t("Меню программ в строке меню", "App menus in the menu bar")
            hint: I18n.t("Меню Файл, Правка, Вид программы в фокусе. Уже открытые — после перезапуска.", "The focused app's File, Edit, View. Apps already open: after a restart.")
            checked: Config.mac.appMenus
            onToggled: v => Config.mac.appMenus = v
        }
        CatToggle {
            present: Config.mac.appMenus
            label: I18n.t("Меню Qt-программ тоже в строке меню", "Qt apps' menus in the menu bar too")
            hint: I18n.t("Telegram, qBittorrent, OBS отдают меню наверх. Выключено — меню остаётся в окне.", "Telegram, qBittorrent, OBS hand their menu up. Off: the menu stays in the window.")
            checked: Config.mac.qtGlobalMenu
            onToggled: v => Config.mac.qtGlobalMenu = v
        }
        CatChoice {
            label: I18n.t("Размер текста", "Text size")
            model: [1, 1.25, 1.5, 1.75, 2].filter(v => v >= page.lim["appearance.fontScale"][0] && v <= page.lim["appearance.fontScale"][1]).map(v => ({
                        "label": "×" + v,
                        "value": v
                    }))
            currentValue: Config.appearance.fontScale
            onActivated: v => Config.appearance.fontScale = v
        }
    }
    // ---- the sound effects (services/Sounds' Golden Gate pack) ----
    CatGroup {
        name: "sounds"
        id: soundsGroup
        title: I18n.t("Звуковые эффекты", "Sound Effects")
        icon: "speaker"
        // event -> its own file in ~/.local/share/angelos/sounds/macos ("" = the skin's)
        property var own: ({})
        readonly property var list: [["notify", "Уведомление", "Notification"], ["error", "Ошибка", "Error"], ["volume", "Громкость", "Volume"], ["screenshot", "Снимок экрана", "Screenshot"], ["trash", "Очистка Корзины", "Empty Trash"], ["usbIn", "USB подключено", "USB connected"], ["usbOut", "USB отключено", "USB disconnected"], ["power", "Зарядка подключена", "Charger connected"], ["lock", "Блокировка", "Lock"], ["login", "Вход", "Log in"]]
        function rescan() {
            ownScan.running = false;
            ownScan.running = true;
        }
        Component.onCompleted: rescan()
        Process {
            id: ownScan
            command: ["sh", "-c", 'cd "$1" 2>/dev/null || exit 0; for f in *; do [ -f "$f" ] && echo "$f"; done', "sh", Sounds.macUserDir]
            stdout: StdioCollector {
                onStreamFinished: {
                    const own = {};
                    for (const f of text.split("\n")) {
                        const m = f.match(/^(.+)\.(ogg|oga|opus|wav|flac|aiff|aif|caf|mp3)$/i);
                        if (m && own[m[1]] === undefined)
                            own[m[1]] = f;
                    }
                    soundsGroup.own = own;
                }
            }
        }
        CatToggle {
            label: I18n.t("Системные звуки", "Play sound effects")
            hint: I18n.t("Уведомления, ошибки, снимки, USB, зарядка, вход. Свои звуки в духе Mac.", "Notifications, errors, shots, USB, charging, login. Our own Mac-like sounds.")
            checked: Config.mac.sounds
            onToggled: v => Config.mac.sounds = v
        }
        CatSlider {
            label: I18n.t("Громкость эффектов", "Sound effects volume")
            from: page.lim["mac.soundVolume"][0]
            to: page.lim["mac.soundVolume"][1]
            stepSize: 0.05
            value: Config.mac.soundVolume
            valueScale: 100
            suffix: "%"
            onMoved: v => Config.mac.soundVolume = v
            onReleased: Sounds.preview("notify")
            enabled: Config.mac.sounds
        }
        CatToggle {
            label: I18n.t("Звук при изменении громкости", "Play feedback when volume is changed")
            checked: Config.mac.volumeSound
            onToggled: v => {
                Config.mac.volumeSound = v;
                if (v)
                    Sounds.preview("volume");
            }
            enabled: Config.mac.sounds
        }
        CatButton {
            label: I18n.t("Свои звуки", "Your own sounds")
            hint: I18n.t("Файл с именем события (notify, lock, login…) в этой папке играет вместо встроенного.", "A file named after the event (notify, lock, login…) in this folder plays instead.")
            text: I18n.t("Открыть папку", "Open folder")
            icon: "folder"
            onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec gio open "$1"', "sh", Sounds.macUserDir])
            CatButton {
                compact: true
                icon: "refresh"
                onClicked: soundsGroup.rescan()
            }
        }
        CatRepeat {
            model: soundsGroup.list
            delegate: Component {
                CatCustom {
                    id: sndRow
                    required property var modelData
                    readonly property string file: soundsGroup.own[modelData[0]] || ""
                    label: I18n.t(modelData[1], modelData[2])
                    hint: file ? I18n.t("ваш: ", "yours: ") + file : I18n.t("встроенный", "built-in")
                    CatBox {
                        PxButton {
                            compact: true
                            icon: "play"
                            onClicked: Sounds.preview(sndRow.modelData[0])
                        }
                    }
                }
            }
        }
    }
    // ---- the skin itself: back to the others ----
    CatGroup {
        name: "skin"
        id: skinGroup
        title: I18n.t("Оформление рабочего стола", "Desktop skin")
        icon: "window"
        CatNote {
            dim: true
            text: I18n.t("Golden Gate меняет весь рабочий стол. Вернуться к пиксельному angelOS — «Классика»; его настройки вернутся вместе с ним.", "Golden Gate changes the whole desktop. Back to the pixel angelOS: Classic; its settings come back with it.")
        }
        CatCustom {
            wide: true
            CatBox {
                Flow {
                    id: skinFlow
                    width: parent.width
                    spacing: Theme.u * 4
                    // four in a row while each has room for its name, else two
                    readonly property int cols: width >= Theme.u * 4 * 96 ? 4 : 2
                    Repeater {
                        model: ["classic", "windose", "stream", "goldengate"]
                        SettingsSkinCard {
                            required property string modelData
                            skin: modelData
                            width: Math.min(Theme.u * 100, (skinFlow.width - skinFlow.spacing * (skinFlow.cols - 1)) / skinFlow.cols - 1)
                        }
                    }
                }
            }
        }
    }
    // ---- reset ----
    CatGroup {
        name: "reset"
        id: resetGroup
        title: I18n.t("Стандартные настройки", "Defaults")
        icon: "refresh"
        property bool confirming: false
        property int done: -1
        Timer {
            id: unconfirm
            interval: 4000
            onTriggered: resetGroup.confirming = false
        }
        CatButton {
            id: resetRow
            label: I18n.t("Сбросить настройки темы к стандартным", "Reset the theme's settings to the defaults")
            hint: resetGroup.done >= 0 ? I18n.t("Сброшено: ", "Reset: ") + parent.done + I18n.t(". «Отменить» вверху окна вернёт как было", ". “Undo” at the top of the window brings it back") : I18n.t("Dock, внешний вид, обои Golden Gate, стиль виджетов, окна и клавиши Mac. Значки, оставленные в Dock, и их порядок не трогаются", "the Dock, appearance, the Golden Gate wallpaper, the widgets' style, windows and the Mac keys. The apps kept in the Dock and their order stay")
            danger: resetGroup.confirming
            icon: "refresh"
            text: resetGroup.confirming ? I18n.t("Точно? Нажмите ещё раз", "Sure? Click again") : I18n.t("Сбросить", "Reset")
            onClicked: {
                const g = resetGroup;
                if (!g.confirming) {
                    g.confirming = true;
                    unconfirm.restart();
                    return;
                }
                g.confirming = false;
                g.done = GoldenGate.resetTheme();
            }
        }
    }
    // ---- Wallpaper ----
    CatGroup {
        name: "wallpaper"
        title: I18n.t("Обои Golden Gate", "Golden Gate wallpaper")
        icon: "image"
        CatToggle {
            label: I18n.t("Обои Golden Gate", "Golden Gate wallpaper")
            hint: I18n.t("светлые или тёмные вместе с оформлением; выключено — ваши картинки ниже; прежние вернутся, когда скин выключат", "light or dark with the appearance; off — your pictures below; the ones before come back when the skin is off")
            checked: Config.mac.wallpaper
            onToggled: v => Config.mac.wallpaper = v
        }
    }
    // ---- Spotlight ----
    CatGroup {
        name: "spotlight"
        title: "Spotlight"
        icon: "search"
        CatToggle {
            label: I18n.t("Файлы", "Files")
            hint: I18n.t("Ищет файлы в домашней папке по имени или типу («.картинки», «.видео»). Новые выше.", "Finds home folder files by name or type (\".images\", \".video\"). Newest first.")
            checked: Config.launcher.files !== false
            onToggled: v => Config.launcher.files = v
        }
        CatToggle {
            label: I18n.t("Предпросмотр", "Preview")
            hint: I18n.t("миниатюры картинок и видео в результатах и большая картинка справа", "thumbnails of pictures and videos in the results and a big one on the right")
            enabled: Config.launcher.files !== false
            checked: Config.launcher.filePreview !== false
            onToggled: v => Config.launcher.filePreview = v
        }
    }
    // ---- Windows ----
    CatGroup {
        name: "windows"
        title: I18n.t("Окна", "Windows")
        icon: "window"
        CatCustom {
            label: I18n.t("Заголовки окон", "Title bars")
            // Golden Gate is always Desktop (WindowConfig.floatAll)
            hint: Niri.nativeMinimize ? I18n.t("окна всегда как на Mac — поверх друг друга. Программам, которые дают рисовать заголовок системе (kitty, alacritty, Qt), angel-niri рисует пиксельный со светофором слева; GTK, браузеры, Discord и Steam рисуют свой", "Windows are always as on a Mac, over each other. Apps that let the system draw their title bar (kitty, alacritty, Qt) get angel-niri's pixel one with the traffic lights on the left; GTK, the browsers, Discord and Steam draw their own") : I18n.t("рисуют сами программы: светофор слева у GTK, рамка Adwaita у Qt, свой заголовок у kitty и браузеров. Жёлтая кнопка убирает окно в Dock, если программа запущена из angelOS (niri сам сворачивание не умеет; его ловит extras/minimize-hook). Всегда работают ⌘M и меню Dock", "drawn by the apps themselves: the traffic lights on the left in GTK, Adwaita's frame in Qt, their own in kitty and the browsers. The yellow light sends the window to the Dock when the app was started from angelOS (niri can't minimize; extras/minimize-hook catches it). ⌘M and the Dock menu always work")
            CatBox {
                PxText {
                    text: GoldenGate.hookInstalled ? I18n.t("перехват: есть", "hook: installed") : I18n.t("перехват: нет", "hook: missing")
                    dim: true
                }
            }
        }
        CatChoice {
            present: Niri.nativeMinimize
            label: I18n.t("Зелёная кнопка", "The green light")
            hint: Config.mac.greenButton === "maximize" ? I18n.t("разворачивает окно между строкой меню и Dock, заголовок и кнопки остаются", "maximizes the window between the menu bar and the Dock, its title bar and lights stay") : I18n.t("как на Mac: окно на весь экран на своём рабочем столе, поверх строки меню и Dock; назад: та же кнопка у программ со своим заголовком или клавиши полноэкранного режима", "as on a Mac: the window full screen on a workspace of its own, over the menu bar and the Dock; back: the same light in apps with their own title bar, or the fullscreen keys")
            model: [
                {
                    "label": I18n.t("На весь экран", "Full screen"),
                    "value": "fullscreen"
                },
                {
                    "label": I18n.t("Развернуть", "Maximize"),
                    "value": "maximize"
                }
            ]
            currentValue: Config.mac.greenButton === "maximize" ? "maximize" : "fullscreen"
            onActivated: v => Config.mac.greenButton = v
        }
        CatChoice {
            label: I18n.t("Рабочие столы в обзоре", "Desktops in the overview")
            hint: Config.mac.overviewDesks === "clear" ? I18n.t("как рисует niri: на обоях видно только окна столов, самих столов не видно", "as niri draws them: only the desktops' windows over the wallpaper, the desktops themselves unseen") : I18n.t("в обзоре niri (жест на тачпаде, обзор с клавиш) каждый стол лежит на стеклянной карточке, обои под ней размыты", "in niri's overview (the touchpad gesture, the overview key) every desktop lies on a glass card, the wallpaper under it blurred")
            model: [
                {
                    "label": I18n.t("Стекло", "Glass"),
                    "value": "glass"
                },
                {
                    "label": I18n.t("Прозрачные", "Clear"),
                    "value": "clear"
                }
            ]
            currentValue: Config.mac.overviewDesks
            onActivated: v => Config.mac.overviewDesks = v
        }
    }
    // ---- the Mac keys ----
    CatGroup {
        name: "keys"
        title: I18n.t("Сочетания клавиш Mac", "Mac shortcuts")
        icon: "keyboard"
        CatToggle {
            label: I18n.t("Сочетания клавиш как на Mac", "Mac keyboard shortcuts")
            hint: I18n.t("⌘ — клавиша Windows: ⌘Q, ⌘W, ⌘Tab, ⌘Пробел и другие привычные сочетания Mac.", "⌘ is the Windows key: ⌘Q, ⌘W, ⌘Tab, ⌘Space and the other familiar Mac keys.")
            checked: Config.mac.keys
            onToggled: v => Config.mac.keys = v
        }
    }
}
