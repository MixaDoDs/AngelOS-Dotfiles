import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

PxPage {
    heading: I18n.t("Внешний вид", "Appearance")
    subtitle: I18n.t("Основная тема angelOS и дополнительные светлые и тёмные палитры.", "The original angelOS theme and additional light and dark palettes.")
    Component.onCompleted: BlurConfig.refresh()

    // what the whole desktop wears: angelOS classic, Windose, Stream, or Golden Gate (macOS 27)
    PxGroup {
        name: "skin"
        id: skinGroup
        title: I18n.t("Скин рабочего стола", "Desktop skin")
        icon: "window"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Классика angelOS — исходное. Windose — с ярлыками на столе, Стрим — с панелью эфира; оба следуют за выбранными цветами. Golden Gate превращает весь стол в macOS 27: строка меню, Dock, Spotlight, окна со светофором.", "angelOS classic is the original. Windose has desktop shortcuts, Stream a broadcast panel; both follow your colours. Golden Gate turns the whole desktop into macOS 27: a menu bar, the Dock, Spotlight, windows with traffic lights.")
        }
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
            label: I18n.t("Цвета из обоев", "Colours from the wallpaper")
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
        title: I18n.t("Прозрачность и пиксели", "Transparency and pixels")

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
            label: I18n.t("Жёсткие пиксельные тени", "Pixel shadows")
            PxToggle {
                checked: Config.appearance.shadows
                onToggled: c => Config.appearance.shadows = c
            }
        }
    }
    PxGroup {
        name: "ui-size"
        title: I18n.t("Размер интерфейса", "Interface size")
        icon: "grid"
        width: parent.width
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
