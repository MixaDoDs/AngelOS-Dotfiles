import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

PxPage {
    heading: I18n.t("Внешний вид", "Appearance")
    subtitle: I18n.t("Основная тема angelOS и дополнительные светлые и тёмные палитры.", "The original angelOS theme and additional light and dark palettes.")
    Component.onCompleted: BlurConfig.refresh()

    // How Settings lay the pages out (the view) and what they wear (the skin): two
    // separate choices, any view in any skin; colours follow the theme either way.
    PxGroup {
        name: "settings-look"
        id: skinGroup
        title: I18n.t("Вид настроек", "Settings look")
        advanced: true
        icon: "window"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Как разложены разделы. Страницы везде одни и те же, поиск и клавиши (Ctrl+F, стрелки, Alt+↑) — тоже. Ещё: `angelos settingsView <вид>`.", "How the sections are laid out. The pages are the same in every view, and so are the search and the keys (Ctrl+F, arrows, Alt+↑). Also: `angelos settingsView <view>`.")
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 4
            Repeater {
                model: ["win11", "sidebar", "controlpanel", "properties", "tiles"]
                SettingsViewCard {
                    required property string modelData
                    view: modelData
                    width: Math.min(Theme.u * 100, (skinGroup.width - Theme.u * 20) / 5)
                }
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Оформление. Классика angelOS — исходное. Дополнительно: Windose с ярлыками рабочего стола и Стрим с панелью эфира — они подходят к любому виду и следуют за выбранными цветами. Golden Gate меняет весь рабочий стол: он как macOS 27 — строка меню с меню программ, Dock, Spotlight, окна со светофором, «Системные настройки».", "Skin. angelOS classic is the original. Also: Windose with desktop shortcuts and Stream with a broadcast panel — they fit any view and follow your colours. Golden Gate changes the whole desktop into macOS 27's: a menu bar with the apps' menus, the Dock, Spotlight, windows with traffic lights, System Settings.")
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
    // the Golden Gate skin's own settings (services/GoldenGate, modules/mac), while it is on
    PxGroup {
        name: "goldengate"
        title: "Golden Gate"
        icon: "window"
        width: parent.width
        shown: Config.settingsUi.skin === "goldengate"

        SettingRow {
            label: "Liquid Glass"
            hint: I18n.t("меню, Dock, Пункт управления: от прозрачного до тонированного", "menus, the Dock, Control Center: from clear to tinted")
            PxSlider {
                width: parent.width
                from: 0
                to: 1
                stepSize: 0.05
                value: Config.mac.glass
                valueScale: 100
                suffix: "%"
                onMoved: v => Config.mac.glass = v
            }
        }
        SettingRow {
            label: I18n.t("Акцент", "Accent colour")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Синий", "Blue"),
                        "value": "blue"
                    },
                    {
                        "label": I18n.t("Фиолетовый", "Purple"),
                        "value": "purple"
                    },
                    {
                        "label": I18n.t("Розовый", "Pink"),
                        "value": "pink"
                    },
                    {
                        "label": I18n.t("Красный", "Red"),
                        "value": "red"
                    },
                    {
                        "label": I18n.t("Оранжевый", "Orange"),
                        "value": "orange"
                    },
                    {
                        "label": I18n.t("Жёлтый", "Yellow"),
                        "value": "yellow"
                    },
                    {
                        "label": I18n.t("Зелёный", "Green"),
                        "value": "green"
                    },
                    {
                        "label": I18n.t("Графит", "Graphite"),
                        "value": "graphite"
                    }
                ]
                currentValue: Config.mac.accent
                onActivated: v => Config.mac.accent = v
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
            label: I18n.t("Фон строки меню", "Menu bar background")
            hint: I18n.t("своя полоса вместо обоев под строкой", "a band of its own instead of the wallpaper under it")
            PxToggle {
                checked: Config.mac.barBackground
                onToggled: v => Config.mac.barBackground = v
            }
        }
        SettingRow {
            label: I18n.t("Сочетания клавиш как на Mac", "Mac keyboard shortcuts")
            hint: I18n.t("⌘ — клавиша Windows: ⌘Q завершить, ⌘W закрыть окно, ⌘Пробел Spotlight, ⌘, настройки, ⌃↑ и F3 Mission Control, ⌘⇧3/4/5 снимки экрана, ⌃⌘Q блокировка, ⌃⌘F полный экран, ⌥⌘⎋ завершить принудительно, ⌃F2 строка меню. Заменяют сочетания angelOS на тех же клавишах.", "⌘ is the Windows key: ⌘Q quit, ⌘W close window, ⌘Space Spotlight, ⌘, settings, ⌃↑ and F3 Mission Control, ⌘⇧3/4/5 screenshots, ⌃⌘Q lock, ⌃⌘F full screen, ⌥⌘⎋ force quit, ⌃F2 the menu bar. They replace angelOS's on the same keys.")
            PxToggle {
                checked: Config.mac.keys
                onToggled: v => Config.mac.keys = v
            }
        }
        SettingRow {
            label: I18n.t("Окна плавают, как на Mac", "Windows float like on a Mac")
            hint: I18n.t("новые окна поверх друг друга; выключено — колонки niri", "new windows overlap; off — niri's columns")
            PxToggle {
                checked: Config.mac.floating
                onToggled: v => Config.mac.floating = v
            }
        }
        SettingRow {
            label: I18n.t("Размер Dock", "Dock size")
            PxSlider {
                width: parent.width
                from: 32
                to: 96
                stepSize: 4
                value: Config.mac.dockSize
                suffix: " px"
                onMoved: v => Config.mac.dockSize = v
            }
        }
        SettingRow {
            label: I18n.t("Увеличение в Dock", "Dock magnification")
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
                from: 32
                to: 128
                stepSize: 4
                value: Math.max(Config.mac.dockSize, Config.mac.dockMagnifySize)
                suffix: " px"
                onMoved: v => Config.mac.dockMagnifySize = v
            }
        }
        SettingRow {
            label: I18n.t("Значки в Dock как в macOS", "Mac-style icons in the Dock")
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
        SettingRow {
            label: I18n.t("Убирать в Dock с эффектом", "Minimise windows using")
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
            label: I18n.t("Автоматически скрывать Dock", "Automatically hide the Dock")
            PxToggle {
                checked: Config.mac.dockAutohide
                onToggled: v => Config.mac.dockAutohide = v
            }
        }
        SettingRow {
            label: I18n.t("Обои Golden Gate", "Golden Gate wallpaper")
            hint: I18n.t("светлые или тёмные вместе с темой; прежние вернутся, когда скин выключат", "light or dark with the theme; the ones before come back when the skin is off")
            PxToggle {
                checked: Config.mac.wallpaper
                onToggled: v => Config.mac.wallpaper = v
            }
        }
    }

    PxGroup {
        name: "theme"
        title: I18n.t("Тема", "Theme")
        icon: "palette"
        width: parent.width

        SettingRow {
            label: I18n.t("Режим", "Mode")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Светлая", "Light"),
                        "value": "light",
                        "icon": "sun"
                    },
                    {
                        "label": I18n.t("Тёмная", "Dark"),
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
            label: I18n.t("Светлая с … до …", "Light theme from … to …")
            hint: I18n.t("часы, по локальному времени", "hours in local time")
            Row {
                spacing: Theme.u * 4
                PxSpin {
                    from: 0
                    to: 23
                    value: Config.appearance.lightFrom
                    suffix: ":00"
                    onMoved: v => Config.appearance.lightFrom = v
                }
                PxSpin {
                    from: 0
                    to: 23
                    value: Config.appearance.darkFrom
                    suffix: ":00"
                    onMoved: v => Config.appearance.darkFrom = v
                }
            }
        }
        SettingRow {
            label: I18n.t("Цветовая схема", "Color scheme")
            PxCombo {
                model: Object.keys(Theme.flavors).map(k => ({
                            "label": Theme.flavors[k].name,
                            "value": k
                        }))
                currentValue: Config.appearance.flavor
                onActivated: v => Config.appearance.flavor = v
            }
        }
        Row {
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Создать из обоев", "Generate from wallpaper")
                icon: "image"
                enabled: !PaletteGenerator.busy
                onClicked: PaletteGenerator.generate()
            }
            PxField {
                width: Theme.u * 75
                visible: Config.appearance.flavor === "wallpaper"
                text: Config.appearance.customAccent
                placeholder: "#c77dff"
                onEdited: if (/^#[0-9a-f]{6}$/i.test(text))
                    Config.appearance.customAccent = text
            }
        }
        SettingRow {
            visible: Config.appearance.flavor === "wallpaper"
            label: I18n.t("Следовать за обоями", "Follow the wallpaper")
            hint: I18n.t("новые обои — новые цвета, автоматически", "New wallpaper, new colours — automatically")
            PxToggle {
                checked: Config.appearance.autoWallpaperColors
                onToggled: c => Config.appearance.autoWallpaperColors = c
            }
        }
        SettingRow {
            visible: Config.appearance.flavor === "wallpaper" && Config.appearance.autoWallpaperColors && Quickshell.screens.length > 1
            label: I18n.t("Экран с обоями", "Wallpaper screen")
            hint: I18n.t("чьи обои задают цвета", "Whose wallpaper sets the colours")
            PxCombo {
                width: Theme.u * 100
                model: [{
                        "label": I18n.t("Основной", "Primary"),
                        "value": ""
                    }].concat(Quickshell.screens.map(s => ({
                            "label": s.name,
                            "value": s.name
                        })))
                currentValue: Config.appearance.paletteScreen
                onActivated: v => Config.appearance.paletteScreen = v
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: PaletteGenerator.error
            visible: text !== ""
            color: Theme.danger
        }
        // palette preview
        Row {
            spacing: Theme.u * 2
            Repeater {
                model: [Theme.accent, Theme.accent2, Theme.accent3, Theme.accent4, Theme.title1, Theme.title2, Theme.face, Theme.faceAlt, Theme.text, Theme.danger, Theme.ok]
                PxBox {
                    required property color modelData
                    width: Theme.u * 14
                    height: Theme.u * 14
                    color: modelData
                }
            }
        }
    }

    PxGroup {
        name: "motion"
        title: I18n.t("Движение", "Motion")
        icon: "sparkle"
        width: parent.width

        SettingRow {
            id: motionRow
            // D4: the way into a circle at this level — the jolt, the slow dark, or a cut
            preview: "CircleFx"
            label: I18n.t("Анимации", "Animations")
            hint: Motion.level === "off" ? I18n.t("всё стоит: анимации оболочки, niri и Ада выключены, рай ⇄ ад меняются сразу; ангел и демоница только тихо дышат. Режим оптимизации", "Everything stands still: the shell's, niri's and hell's animations are off, heaven ⇄ hell switch at once; the angel and the demon only breathe quietly. The optimisation mode") : Motion.level === "calm" ? I18n.t("без вспышек, тряски экрана и резких звуков: лучи ангела и тряска не появляются, переходы между кругами медленнее и тише, буквы реплик не дрожат", "No flashes, screen shaking or sudden loud sounds: no angel rays or shaking, hell's transitions are slower and quieter, the letters of her lines don't tremble") : I18n.t("всё как задумано; отдельные анимации — в своих разделах", "Everything as designed; single animations live in their own sections")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Полное", "Full"),
                        "value": "full"
                    },
                    {
                        "label": I18n.t("Спокойное", "Calm"),
                        "value": "calm"
                    },
                    {
                        "label": I18n.t("Выключено", "Off"),
                        "value": "off"
                    }
                ]
                currentValue: Motion.level
                onActivated: v => {
                    Motion.set(v);
                    motionRow.show(v, I18n.t("переход в круг", "into a circle"));
                }
            }
        }
    }

    // D3: the shell's icons — ours, pixelarticons or HackerNoon's (widgets/IconSets.js)
    PxGroup {
        name: "icons"
        title: I18n.t("Значки", "Icons")
        icon: "grid"
        width: parent.width

        SettingRow {
            label: I18n.t("Стиль значков", "Icon style")
            hint: I18n.t("значки самой оболочки — панель, настройки, меню, кнопки. Сердечки, рожки и пентаграмма остаются своими в любом стиле. Значки приложений — тема системы, она отдельно", "The shell's own icons — the bar, settings, menus, buttons. Hearts, horns and the pentagram stay ours in every style. App icons are the system's icon theme, a separate thing")
            IconStyleCards {}
        }
    }

    PxGroup {
        name: "window-titles"
        title: I18n.t("Подписи окон", "Window titles")
        icon: "monitor"
        width: parent.width

        SettingRow {
            label: I18n.t("Окончание в названиях", "Name ending")
            // suffix-ok: the three endings themselves
            hint: I18n.t("как подписаны все окошки angelOS — виджеты, панели, Alt+Tab, лок, плагины: calendar.exe, calendar.sh или calendar.bin", "How every angelOS window is titled — widgets, panels, Alt+Tab, the lock, plugins: calendar.exe, calendar.sh or calendar.bin")
            PxSegmented {
                model: I18n.suffixes.map(s => ({
                            "label": "." + s,
                            "value": s
                        }))
                currentValue: I18n.suffix
                onActivated: v => Config.desktop.titleSuffix = v
            }
        }
    }

    PxGroup {
        name: "glass-pixels"
        title: I18n.t("Стекло и пиксели", "Glass and pixels")

        advanced: true
        icon: "sparkle"
        width: parent.width

        SettingRow {
            label: I18n.t("Блюр под панелями", "Blur behind panels")
            hint: I18n.t("ext-background-effect, рисует niri", "ext-background-effect, rendered by niri")
            PxToggle {
                checked: Config.appearance.blur
                onToggled: c => Config.appearance.blur = c
            }
        }
        SettingRow {
            label: I18n.t("Непрозрачность панелей", "Panel opacity")
            PxSlider {
                width: parent.width
                from: 0.4
                to: 1
                stepSize: 0.02
                value: Config.appearance.opacity
                valueScale: 100
                suffix: "%"
                onMoved: v => Config.appearance.opacity = v
            }
        }
        SettingRow {
            label: I18n.t("Сила блюра", "Blur strength")
            hint: I18n.t("Общая настройка niri; изменения сохраняются с бэкапом", "Global niri setting; changes are backed up")
            enabled: Config.appearance.blur && BlurConfig.supported && !BlurConfig.busy
            PxSlider {
                width: parent.width
                from: 0.5
                to: 10
                stepSize: 0.5
                decimals: 1
                value: BlurConfig.offset
                onReleased: v => BlurConfig.save({offset: v})
            }
        }
        SettingRow {
            label: I18n.t("Проходы размытия", "Blur passes")
            hint: I18n.t("Больше проходов — мягче размытие и выше нагрузка", "More passes soften the blur and use more GPU time")
            enabled: Config.appearance.blur && BlurConfig.supported && !BlurConfig.busy
            PxSpin {
                from: 1
                to: 6
                value: BlurConfig.passes
                onMoved: v => BlurConfig.save({passes: v})
            }
        }
        SettingRow {
            label: I18n.t("Зернистость стекла", "Glass grain")
            enabled: Config.appearance.blur && BlurConfig.supported && !BlurConfig.busy
            PxSlider {
                width: parent.width
                from: 0
                to: 0.1
                stepSize: 0.002
                valueScale: 100
                decimals: 1
                suffix: "%"
                value: BlurConfig.noise
                onReleased: v => BlurConfig.save({noise: v})
            }
        }
        PxText {
            width: parent.width
            visible: text !== ""
            wrapMode: Text.Wrap
            dim: true
            text: BlurConfig.log
        }
        SettingRow {
            label: I18n.t("Размер пикселя", "Pixel size")
            hint: I18n.t("1 арт-пиксель = N экранных; только целые — половинка размазала бы каждую рамку", "1 art pixel = N screen pixels; whole ones only — a half would smear every frame")
            PxSpin {
                from: 1
                to: 4
                value: Config.appearance.px
                suffix: " px"
                onMoved: v => Config.appearance.px = v
            }
        }
        SettingRow {
            label: I18n.t("Жёсткие пиксельные тени", "Pixel shadows")
            PxToggle {
                checked: Config.appearance.shadows
                onToggled: c => Config.appearance.shadows = c
            }
        }
    }

    PxGroup {
        name: "application-theme"
        title: I18n.t("Тема для приложений", "Application theme")

        advanced: true
        icon: "terminal"
        width: parent.width

        SettingRow {
            label: I18n.t("Красить приложения", "Theme applications")
            hint: I18n.t("шаблоны → kitty, foot, alacritty, GTK, niri. Свои шаблоны: ~/.config/angelos/templates/*.json", "Templates for kitty, foot, alacritty, GTK and niri. Custom templates: ~/.config/angelos/templates/*.json")
            PxToggle {
                checked: Config.appearance.themeApps
                onToggled: c => Config.appearance.themeApps = c
            }
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 6
            visible: Config.appearance.themeApps
            Repeater {
                model: ThemeExport.entries
                PxCheck {
                    required property var modelData
                    text: modelData.name || modelData.id
                    checked: !(Config.appearance.disabledTemplates || []).includes(modelData.id)
                    onToggled: c => {
                        const list = (Config.appearance.disabledTemplates || []).filter(i => i !== modelData.id);
                        if (!c)
                            list.push(modelData.id);
                        Config.appearance.disabledTemplates = list;
                    }
                }
            }
        }
        SettingRow {
            visible: Config.appearance.themeApps
            label: I18n.t("Qt-приложения в стиле angelOS", "Qt apps in the angelOS look")
            hint: I18n.t("через qt6ct: цвета темы (в аду — адские), квадратные углы, пиксельные кнопки и поля. Работает в kdenlive, qBittorrent, Prism Launcher и других Qt-программах; открытые меняются на лету, остальные — при следующем запуске. Выключение возвращает всё как было", "Through qt6ct: the theme's colours (hell's in hell), square corners, pixel buttons and fields. Works in kdenlive, qBittorrent, Prism Launcher and other Qt apps; open ones change on the fly, others on their next start. Off puts everything back")
            PxToggle {
                checked: Config.appearance.qtStyle
                onToggled: c => Config.appearance.qtStyle = c
            }
        }
        Row {
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Применить сейчас", "Apply now")
                icon: "refresh"
                onClicked: ThemeExport.apply()
            }
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                text: Shell.dev ? I18n.t("(dev-режим: шаблоны не пишутся)", "(dev mode: templates are not written)") : ThemeExport.lastLog.split("\n").filter(l => l).length + I18n.t(" файлов обновлено", " files updated")
                dim: true
            }
        }
    }
}
