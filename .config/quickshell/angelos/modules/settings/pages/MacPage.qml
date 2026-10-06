import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import qs.modules.mac

// The Golden Gate skin's own settings (services/GoldenGate, modules/mac): its pages in Settings
// while the skin is on are put together from these groups (tree.json "mac": Dock, Appearance,
// Wallpaper, Widgets, Keyboard and mouse, Windows). The pixel skins' pages are not in that tree.
// Every number has the range GoldenGate.limits holds (a value out of it from the file is put back
// there too); "Reset the theme" puts GoldenGate.themeKeys back to their defaults.
PxPage {
    id: page
    heading: "Golden Gate"
    subtitle: I18n.t("Рабочий стол как в macOS 27: Dock, строка меню, окна со светофором.", "The desktop as in macOS 27: the Dock, the menu bar, windows with traffic lights.")

    readonly property var lim: GoldenGate.limits

    // ---- Dock ----
    PxGroup {
        name: "dock"
        title: "Dock"
        icon: "grid"
        width: parent.width

        SettingRow {
            label: I18n.t("Размер", "Size")
            PxSlider {
                width: parent.width
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
        }
        SettingRow {
            label: I18n.t("Увеличение", "Magnification")
            hint: I18n.t("значки под указателем растут, соседние — чуть меньше", "icons under the pointer grow, their neighbours a little less")
            PxToggle {
                checked: Config.mac.dockMagnify
                onToggled: v => Config.mac.dockMagnify = v
            }
        }
        SettingRow {
            visible: Config.mac.dockMagnify
            label: I18n.t("Размер при увеличении", "Magnified size")
            PxSlider {
                width: parent.width
                from: Math.max(page.lim["mac.dockMagnifySize"][0], Config.mac.dockSize)
                to: page.lim["mac.dockMagnifySize"][1]
                stepSize: 4
                value: Math.max(Config.mac.dockSize, Config.mac.dockMagnifySize)
                suffix: " px"
                onMoved: v => Config.mac.dockMagnifySize = v
            }
        }
        SettingRow {
            label: I18n.t("Положение на экране", "Position on screen")
            PxSegmented {
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
        }
        SettingRow {
            label: I18n.t("Автоматически скрывать и показывать Dock", "Automatically hide and show the Dock")
            hint: I18n.t("появляется, когда указатель у края экрана", "it comes back when the pointer reaches the screen's edge")
            PxToggle {
                checked: Config.mac.dockAutohide
                onToggled: v => Config.mac.dockAutohide = v
            }
        }
        SettingRow {
            label: I18n.t("Убирать окна в Dock с эффектом", "Minimise windows using")
            hint: I18n.t("«Джин» — окно изгибается и втекает в значок, «Масштаб» — уменьшается в него; с движением «выкл» — сразу", "Genie — the window bends and pours into its icon, Scale — it shrinks into it; with Motion off — at once")
            PxSegmented {
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
        }
        SettingRow {
            label: I18n.t("Значки как в macOS", "Mac-style icons")
            hint: DockIcons.busy ? I18n.t("скачиваются…", "downloading…") : DockIcons.error ? I18n.t("не скачались: ", "not downloaded: ") + DockIcons.error : I18n.t("свободная тема MacTahoe (GPL-3.0), скачивается один раз; выключено — значки вашей темы", "the free MacTahoe theme (GPL-3.0), downloaded once; off — your theme's icons")
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

    // ---- the apps kept in the Dock, in order (the same as dragging them in the Dock) ----
    PxGroup {
        name: "dock-apps"
        id: keptGroup
        title: I18n.t("Порядок значков", "Icon order")
        icon: "grid"
        width: parent.width
        readonly property var kept: MacDockModel.apps.filter(a => a.kept)
        function move(i, d) {
            const ids = kept.map(a => a.id);
            const j = i + d;
            if (j < 0 || j >= ids.length)
                return;
            ids.splice(j, 0, ids.splice(i, 1)[0]);
            MacDockModel.setOrder(ids);
        }

        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Значки можно перетаскивать прямо в Dock; вытащите значок вверх из Dock — он уберётся. Запущенную программу оставит в Dock её меню («Оставить в Dock»).", "Drag the icons right in the Dock; pull one up out of the Dock to remove it. A running app stays in the Dock from its menu (Keep in Dock).")
        }
        Repeater {
            model: keptGroup.kept
            SettingRow {
                id: keptRow
                required property var modelData
                required property int index
                label: modelData.name || modelData.id
                Row {
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
        SettingRow {
            label: I18n.t("Порядок как вначале", "The order it came with")
            hint: I18n.t("файлы, Приложения, браузер, терминал, закреплённое в «Пуске», Системные настройки", "Files, Apps, the browser, the terminal, Start's pinned apps, System Settings")
            PxButton {
                text: I18n.t("Сбросить порядок", "Reset the order")
                icon: "refresh"
                onClicked: MacDockModel.resetOrder()
            }
        }
    }

    // ---- Appearance ----
    PxGroup {
        name: "look"
        title: I18n.t("Внешний вид", "Appearance")
        icon: "palette"
        width: parent.width

        SettingRow {
            label: I18n.t("Оформление", "Appearance")
            PxSegmented {
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
        }
        SettingRow {
            visible: Config.appearance.mode === "auto"
            label: I18n.t("Светлое с … до …", "Light from … to …")
            hint: I18n.t("часы, по местному времени", "hours, local time")
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
        SettingRow {
            label: I18n.t("Цвет акцента", "Accent colour")
            PxSegmented {
                model: [["blue", "Синий", "Blue"], ["purple", "Фиолетовый", "Purple"], ["pink", "Розовый", "Pink"], ["red", "Красный", "Red"], ["orange", "Оранжевый", "Orange"], ["yellow", "Жёлтый", "Yellow"], ["green", "Зелёный", "Green"], ["graphite", "Графит", "Graphite"]].map(a => ({
                            "label": I18n.t(a[1], a[2]),
                            "value": a[0]
                        }))
                currentValue: Config.mac.accent
                onActivated: v => Config.mac.accent = v
            }
        }
        SettingRow {
            label: I18n.t("Прозрачность (Liquid Glass)", "Transparency (Liquid Glass)")
            hint: I18n.t("меню, Dock, Пункт управления: от прозрачного до тонированного", "menus, the Dock, Control Center: from clear to tinted")
            PxSlider {
                width: parent.width
                from: page.lim["mac.glass"][0]
                to: page.lim["mac.glass"][1]
                stepSize: 0.05
                value: Config.mac.glass
                valueScale: 100
                suffix: "%"
                onMoved: v => Config.mac.glass = v
            }
        }
        SettingRow {
            label: I18n.t("Уменьшить прозрачность", "Reduce transparency")
            hint: GoldenGate.gameMode ? I18n.t("сейчас стекло и так плотное: идёт полноэкранное окно (niri-game-mode)", "the glass is solid right now anyway: a fullscreen window is up (niri-game-mode)") : I18n.t("как в Универсальном доступе macOS: плотное стекло без размытия и бликов по краю — читается легче и меньше работы видеокарте. Само включается, пока идёт полноэкранная игра", "as in macOS's Accessibility: solid glass, no blur and no edge light — easier to read and less work for the GPU. Turns on by itself while a fullscreen game runs")
            PxToggle {
                checked: Config.mac.reduceTransparency
                onToggled: v => Config.mac.reduceTransparency = v
            }
        }
        SettingRow {
            label: I18n.t("Размытие под стеклом", "Blur behind the glass")
            hint: I18n.t("выключено — стекло почти непрозрачное, как «Уменьшить прозрачность» в macOS", "off: the glass nearly opaque, like macOS's Reduce Transparency")
            PxToggle {
                checked: Config.appearance.blur
                onToggled: v => Config.appearance.blur = v
            }
        }
        SettingRow {
            label: I18n.t("Фон строки меню", "Menu bar background")
            hint: I18n.t("своя полоса вместо обоев под строкой", "a band of its own instead of the wallpaper under it")
            PxToggle {
                checked: Config.mac.barBackground
                onToggled: v => Config.mac.barBackground = v
            }
        }
        SettingRow {
            label: I18n.t("Меню программ в строке меню", "App menus in the menu bar")
            hint: I18n.t("Файл, Правка, Вид программы в фокусе (Qt, GTK, стандартные наборы); программы, запущенные раньше, — после перезапуска", "the focused app's File, Edit, View (Qt, GTK, standard sets); apps started before — after a restart")
            PxToggle {
                checked: Config.mac.appMenus
                onToggled: v => Config.mac.appMenus = v
            }
        }
        SettingRow {
            visible: Config.mac.appMenus
            label: I18n.t("Меню Qt-программ тоже в строке меню", "Qt apps' menus in the menu bar too")
            hint: I18n.t("Telegram, qBittorrent, OBS… отдают своё меню наверх и прячут его в окне — Qt решает это при запуске сразу для всех своих программ. Выключено: у Qt-программ их собственные меню", "Telegram, qBittorrent, OBS… hand their menu up and hide it in the window — Qt decides at start, for all its apps at once. Off: Qt apps keep their own menus")
            PxToggle {
                checked: Config.mac.qtGlobalMenu
                onToggled: v => Config.mac.qtGlobalMenu = v
            }
        }
        SettingRow {
            label: I18n.t("Размер текста", "Text size")
            PxSegmented {
                model: [1, 1.25, 1.5, 1.75, 2].filter(v => v >= page.lim["appearance.fontScale"][0] && v <= page.lim["appearance.fontScale"][1]).map(v => ({
                            "label": "×" + v,
                            "value": v
                        }))
                currentValue: Config.appearance.fontScale
                onActivated: v => Config.appearance.fontScale = v
            }
        }
    }

    // ---- the sound effects (services/Sounds' Golden Gate pack) ----
    PxGroup {
        name: "sounds"
        id: soundsGroup
        title: I18n.t("Звуковые эффекты", "Sound Effects")
        icon: "speaker"
        width: parent.width
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

        SettingRow {
            label: I18n.t("Системные звуки", "Play sound effects")
            hint: I18n.t("уведомления, ошибки, снимки экрана, Корзина, USB, зарядка, блокировка и вход. Свои, похожие на Mac, без звуков Apple", "notifications, errors, screenshots, the Trash, USB, the charger, locking and logging in. Our own, Mac-like, no Apple sounds")
            PxToggle {
                checked: Config.mac.sounds
                onToggled: v => Config.mac.sounds = v
            }
        }
        SettingRow {
            enabled: Config.mac.sounds
            label: I18n.t("Громкость эффектов", "Sound effects volume")
            PxSlider {
                width: parent.width
                from: page.lim["mac.soundVolume"][0]
                to: page.lim["mac.soundVolume"][1]
                stepSize: 0.05
                value: Config.mac.soundVolume
                valueScale: 100
                suffix: "%"
                onMoved: v => Config.mac.soundVolume = v
                onReleased: Sounds.preview("notify")
            }
        }
        SettingRow {
            enabled: Config.mac.sounds
            label: I18n.t("Звук при изменении громкости", "Play feedback when volume is changed")
            PxToggle {
                checked: Config.mac.volumeSound
                onToggled: v => {
                    Config.mac.volumeSound = v;
                    if (v)
                        Sounds.preview("volume");
                }
            }
        }
        SettingRow {
            label: I18n.t("Свои звуки", "Your own sounds")
            hint: I18n.t("файл с именем события (notify, error, volume, screenshot, trash, usbIn, usbOut, power, lock, login; .aiff .caf .wav .ogg .flac .mp3) в этой папке играет вместо встроенного — например, звуки со своего Mac из /System/Library/Sounds", "a file named after the event (notify, error, volume, screenshot, trash, usbIn, usbOut, power, lock, login; .aiff .caf .wav .ogg .flac .mp3) in this folder plays instead of the built-in one — e.g. sounds from your own Mac's /System/Library/Sounds")
            Row {
                spacing: Theme.u * 2
                PxButton {
                    text: I18n.t("Открыть папку", "Open folder")
                    icon: "folder"
                    onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec gio open "$1"', "sh", Sounds.macUserDir])
                }
                PxButton {
                    compact: true
                    icon: "refresh"
                    onClicked: soundsGroup.rescan()
                }
            }
        }
        Repeater {
            model: soundsGroup.list
            SettingRow {
                id: sndRow
                required property var modelData
                readonly property string file: soundsGroup.own[modelData[0]] || ""
                label: I18n.t(modelData[1], modelData[2])
                hint: file ? I18n.t("ваш: ", "yours: ") + file : I18n.t("встроенный", "built-in")
                PxButton {
                    compact: true
                    icon: "play"
                    onClicked: Sounds.preview(sndRow.modelData[0])
                }
            }
        }
    }

    // ---- the skin itself: back to the others ----
    PxGroup {
        name: "skin"
        id: skinGroup
        title: I18n.t("Оформление рабочего стола", "Desktop skin")
        icon: "window"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Golden Gate меняет весь рабочий стол. Вернуться к пиксельному angelOS — «Классика»; его настройки вернутся вместе с ним.", "Golden Gate changes the whole desktop. Back to the pixel angelOS: Classic; its settings come back with it.")
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 4
            Repeater {
                model: ["classic", "windose", "stream", "goldengate"]
                SettingsSkinCard {
                    required property string modelData
                    skin: modelData
                    width: Math.min(Theme.u * 100, (skinGroup.width - Theme.u * 16) / 4)
                }
            }
        }
    }

    // ---- reset ----
    PxGroup {
        name: "reset"
        id: resetGroup
        title: I18n.t("Стандартные настройки", "Defaults")
        icon: "refresh"
        width: parent.width
        property bool confirming: false
        property int done: -1
        Timer {
            id: unconfirm
            interval: 4000
            onTriggered: resetGroup.confirming = false
        }
        SettingRow {
            id: resetRow
            label: I18n.t("Сбросить настройки темы к стандартным", "Reset the theme's settings to the defaults")
            hint: resetGroup.done >= 0 ? I18n.t("Сброшено: ", "Reset: ") + parent.done + I18n.t(". «Отменить» вверху окна вернёт как было", ". “Undo” at the top of the window brings it back") : I18n.t("Dock, внешний вид, обои Golden Gate, стиль виджетов, окна и клавиши Mac. Значки, оставленные в Dock, и их порядок не трогаются", "the Dock, appearance, the Golden Gate wallpaper, the widgets' style, windows and the Mac keys. The apps kept in the Dock and their order stay")
            PxButton {
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
    }

    // ---- Wallpaper ----
    PxGroup {
        name: "wallpaper"
        title: I18n.t("Обои Golden Gate", "Golden Gate wallpaper")
        icon: "image"
        width: parent.width
        SettingRow {
            label: I18n.t("Обои Golden Gate", "Golden Gate wallpaper")
            hint: I18n.t("светлые или тёмные вместе с оформлением; выключено — ваши картинки ниже; прежние вернутся, когда скин выключат", "light or dark with the appearance; off — your pictures below; the ones before come back when the skin is off")
            PxToggle {
                checked: Config.mac.wallpaper
                onToggled: v => Config.mac.wallpaper = v
            }
        }
    }

    // ---- Spotlight ----
    PxGroup {
        name: "spotlight"
        title: "Spotlight"
        icon: "search"
        width: parent.width
        SettingRow {
            label: I18n.t("Файлы", "Files")
            hint: I18n.t("Spotlight ищет файлы в домашней папке: по имени («отпуск») или типу («.jpeg», «.картинки», «.видео», «.музыка», «.документы»); новые выше. Скрытые папки не смотрит", "Spotlight finds files in the home folder by name (\"holiday\") or type (\".jpeg\", \".images\", \".video\", \".music\", \".docs\"); newest first. Hidden folders are skipped")
            PxToggle {
                checked: Config.launcher.files !== false
                onToggled: v => Config.launcher.files = v
            }
        }
        SettingRow {
            label: I18n.t("Предпросмотр", "Preview")
            hint: I18n.t("миниатюры картинок и видео в результатах и большая картинка справа", "thumbnails of pictures and videos in the results and a big one on the right")
            PxToggle {
                enabled: Config.launcher.files !== false
                checked: Config.launcher.filePreview !== false
                onToggled: v => Config.launcher.filePreview = v
            }
        }
    }

    // ---- Windows ----
    PxGroup {
        name: "windows"
        title: I18n.t("Окна", "Windows")
        icon: "window"
        width: parent.width
        SettingRow {
            label: I18n.t("Окна плавают, как на Mac", "Windows float like on a Mac")
            hint: I18n.t("новые окна поверх друг друга; выключено — колонки niri. Пишется в ~/.config/niri/angelos.kdl с бэкапом и проверкой niri validate", "new windows overlap; off — niri's columns. Written to ~/.config/niri/angelos.kdl with a backup and niri validate")
            PxToggle {
                checked: Config.mac.floating
                onToggled: v => Config.mac.floating = v
            }
        }
        SettingRow {
            label: I18n.t("Заголовки окон", "Title bars")
            hint: I18n.t("рисуют сами программы: светофор слева у GTK, рамка Adwaita у Qt, свой заголовок у kitty и браузеров. Жёлтая кнопка убирает окно в Dock, если программа запущена из angelOS (niri сам сворачивание не умеет; его ловит extras/minimize-hook). Всегда работают ⌘M и меню Dock", "drawn by the apps themselves: the traffic lights on the left in GTK, Adwaita's frame in Qt, their own in kitty and the browsers. The yellow light sends the window to the Dock when the app was started from angelOS (niri can't minimize; extras/minimize-hook catches it). ⌘M and the Dock menu always work")
            PxText {
                text: GoldenGate.hookInstalled ? I18n.t("перехват: есть", "hook: installed") : I18n.t("перехват: нет", "hook: missing")
                dim: true
            }
        }
    }

    // ---- the Mac keys ----
    PxGroup {
        name: "keys"
        title: I18n.t("Сочетания клавиш Mac", "Mac shortcuts")
        icon: "keyboard"
        width: parent.width
        SettingRow {
            label: I18n.t("Сочетания клавиш как на Mac", "Mac keyboard shortcuts")
            hint: I18n.t("⌘ — клавиша Windows: ⌘Q завершить, ⌘W закрыть окно, ⌘M свернуть в Dock, ⌘H скрыть программу, ⌘Tab программы, ⌘` окна программы, ⌘Пробел Spotlight, ⌘, настройки, ⌃←/⌃→ рабочие столы, ⌃↑ и F3 Mission Control, ⇧⌘3/4/5 снимки экрана, ⌃⌘Q блокировка, ⌃⌘F полный экран, ⌥⌘⎋ завершить принудительно, ⌃F2 строка меню. Тайлинг niri — на ⌘⌥. Пишется в ~/.config/niri/angelos.kdl с бэкапом и проверкой", "⌘ is the Windows key: ⌘Q quit, ⌘W close window, ⌘M minimize to the Dock, ⌘H hide the app, ⌘Tab apps, ⌘` the app's windows, ⌘Space Spotlight, ⌘, settings, ⌃←/⌃→ desktops, ⌃↑ and F3 Mission Control, ⇧⌘3/4/5 screenshots, ⌃⌘Q lock, ⌃⌘F full screen, ⌥⌘⎋ force quit, ⌃F2 the menu bar. niri's tiling is on ⌘⌥. Written to ~/.config/niri/angelos.kdl with a backup and a check")
            PxToggle {
                checked: Config.mac.keys
                onToggled: v => Config.mac.keys = v
            }
        }
    }
}
