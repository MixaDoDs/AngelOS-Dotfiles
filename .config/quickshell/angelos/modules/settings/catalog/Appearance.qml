// The settings once in AppearancePage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

CatPage {
    heading: I18n.t("Внешний вид", "Appearance")
    subtitle: I18n.t("Основная тема angelOS и дополнительные светлые и тёмные палитры.", "The original angelOS theme and additional light and dark palettes.")
    Component.onCompleted: BlurConfig.refresh()
    // how the Settings window looks (services/SettingsLook); Golden Gate has System Settings instead
    CatGroup {
        name: "settingslook"
        title: I18n.t("Вид окна настроек", "Settings window look")
        icon: "gear"
        present: Config.settingsUi.skin !== "goldengate"
        CatChoice {
            label: I18n.t("Вид окна настроек", "Settings window look")
            hint: I18n.t("Привычный — окно как в Windows 11. Новый — Persona 5 на весь экран. Сменится, когда закроешь настройки.", "Familiar: a window like Windows 11. New: Persona 5 over the whole screen. Changes once Settings are closed.")
            model: [
                {
                    "label": I18n.t("Привычный", "Familiar"),
                    "value": "win11",
                    "icon": "window"
                },
                {
                    "label": I18n.t("Новый (P5)", "New (P5)"),
                    "value": "p5",
                    "icon": "sparkle"
                }
            ]
            currentValue: Config.settingsUi.look === "p5" ? "p5" : "win11"
            onActivated: v => {
                Config.settingsUi.look = v;
                Config.settingsUi.lookAsked = true;
            }
        }
    }
    // what the whole desktop wears: angelOS classic, Windose, Stream, or Golden Gate (macOS 27)
    CatGroup {
        name: "skin"
        id: skinGroup
        title: I18n.t("Скин рабочего стола", "Desktop skin")
        icon: "window"
        CatNote {
            dim: true
            text: I18n.t("Классика — исходный вид. Windose и Стрим — свой вид окон. Golden Gate — весь стол как macOS: строка меню, Dock, Spotlight.", "Classic: the original look. Windose and Stream: their own look of windows. Golden Gate: the whole desk as macOS — menu bar, Dock, Spotlight.")
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
    CatGroup {
        name: "theme"
        title: I18n.t("Тема", "Theme")
        icon: "palette"
        CatChoice {
            label: I18n.t("Режим", "Mode")
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
        CatCustom {
            present: Config.appearance.mode === "auto"
            label: I18n.t("Светлая с … до …", "Light theme from … to …")
            hint: I18n.t("часы, по локальному времени", "hours in local time")
            CatBox {
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
        }
        CatChoice {
            label: I18n.t("Интерфейс днём", "The interface by day")
            hint: I18n.t("обои и программы светлые, а панель, меню и окна оболочки — в этом облике", "the wallpaper and the programs stay light; the bar, menus and the shell's windows wear this look")
            combo: true
            model: Object.keys(Theme.dayLooks).map(k => ({
                        "label": Theme.dayLooks[k].name,
                        "value": k
                    }))
            currentValue: Theme.dayLookId
            onActivated: v => Config.appearance.dayLook = v
        }
        CatChoice {
            label: I18n.t("Цветовая схема", "Color scheme")
            combo: true
            model: Object.keys(Theme.flavors).map(k => ({
                        "label": Theme.flavors[k].name,
                        "value": k
                    }))
            currentValue: Config.appearance.flavor
            onActivated: v => Config.appearance.flavor = v
        }
        CatCustom {
            wide: true
            CatBox {
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
            }
        }
        CatToggle {
            present: Config.appearance.flavor === "wallpaper"
            label: I18n.t("Цвета из обоев", "Colours from the wallpaper")
            hint: I18n.t("новые обои — новые цвета, автоматически", "New wallpaper, new colours — automatically")
            checked: Config.appearance.autoWallpaperColors
            onToggled: c => Config.appearance.autoWallpaperColors = c
        }
        CatChoice {
            present: Config.appearance.flavor === "wallpaper" && Config.appearance.autoWallpaperColors && Quickshell.screens.length > 1
            label: I18n.t("Экран с обоями", "Wallpaper screen")
            hint: I18n.t("чьи обои задают цвета", "Whose wallpaper sets the colours")
            combo: true
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
        CatChoice {
            id: areaRow
            present: Config.appearance.flavor === "wallpaper"
            label: I18n.t("Откуда брать цвет", "Where the colour comes from")
            hint: I18n.t("часть обоев: небо, середина, низ или своя рамка — её рисуют мышью на картинке", "A part of the wallpaper: the sky, the middle, the ground, or your own frame drawn on the picture")
            combo: true
            model: [
                {
                    "label": I18n.t("Вся картинка", "The whole picture"),
                    "value": "all"
                },
                {
                    "label": I18n.t("Небо (верх)", "The sky (top)"),
                    "value": "sky"
                },
                {
                    "label": I18n.t("Середина", "The middle"),
                    "value": "middle"
                },
                {
                    "label": I18n.t("Низ", "The ground (bottom)"),
                    "value": "ground"
                },
                {
                    "label": I18n.t("Своя область…", "My own area…"),
                    "value": "custom"
                }
            ]
            currentValue: Config.appearance.paletteArea
            onActivated: v => {
                Config.appearance.paletteArea = v;
                if (!PaletteGenerator.auto)
                    PaletteGenerator.generate();
            }
        }
        // the palette screen's wallpaper with the area on it (drawn with the mouse in "custom")
        // and the area's own colours beside it, read live by ColorQuantizer: a click takes one
        CatCustom {
            wide: true
            CatBox {
                // the palette screen's wallpaper with the area on it (drawn with the mouse in "custom")
                // and the area's own colours beside it, read live by ColorQuantizer: a click takes one
                Row {
                    id: areaView
                    visible: Config.appearance.flavor === "wallpaper"
                    spacing: Theme.u * 4
                    readonly property string picture: PaletteGenerator.wallpaper ? Wallpapers.display(PaletteGenerator.wallpaper) : ""
                    readonly property var rect: PaletteGenerator.area
                    onPictureChanged: PaletteGenerator.measure(picture)
                    Component.onCompleted: PaletteGenerator.measure(picture)
                    Item {
                        id: thumbBox
                        width: Theme.u * 110
                        height: thumb.status === Image.Ready ? thumb.paintedHeight : Theme.u * 62
                        Image {
                            id: thumb
                            width: parent.width
                            source: areaView.visible && areaView.picture ? "file://" + areaView.picture : ""
                            sourceSize.width: width
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                        }
                        Rectangle {
                            anchors.fill: parent
                            visible: thumb.status !== Image.Ready
                            color: Theme.tone("sunken", Theme.p5For(parent))
                        }
                        // the area in a frame
                        Rectangle {
                            id: frameRect
                            readonly property var r: drawer.drawing ? drawer.rect : areaView.rect || [0, 0, 1, 1]
                            x: r[0] * thumbBox.width
                            y: r[1] * thumbBox.height
                            width: r[2] * thumbBox.width
                            height: r[3] * thumbBox.height
                            color: "transparent"
                            border.width: Math.max(1, Theme.u / 2)
                            border.color: Theme.accent
                            visible: thumb.status === Image.Ready && (!!areaView.rect || drawer.drawing)
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -Math.max(1, Theme.u / 2) * 2
                                color: "transparent"
                                border.width: Math.max(1, Theme.u / 2)
                                border.color: Theme.tone("edge", Theme.p5For(parent))
                            }
                        }
                        MouseArea {
                            id: drawer
                            anchors.fill: parent
                            enabled: Config.appearance.paletteArea === "custom" && thumb.status === Image.Ready
                            cursorShape: enabled ? Qt.CrossCursor : Qt.ArrowCursor
                            // the settings page scrolls: without this it takes the drag away mid-frame
                            preventStealing: true
                            property bool drawing: false
                            property point from
                            property var rect: [0, 0, 1, 1]
                            function part(v, size) {
                                return Math.max(0, Math.min(1, v / size));
                            }
                            onPressed: e => {
                                from = Qt.point(part(e.x, width), part(e.y, height));
                                rect = [from.x, from.y, 0, 0];
                                drawing = true;
                            }
                            onPositionChanged: e => {
                                if (!drawing)
                                    return;
                                const x = part(e.x, width), y = part(e.y, height);
                                rect = [Math.min(from.x, x), Math.min(from.y, y), Math.abs(x - from.x), Math.abs(y - from.y)];
                            }
                            onCanceled: drawing = false
                            onReleased: {
                                drawing = false;
                                if (rect[2] > 0.02 && rect[3] > 0.02)
                                    Config.appearance.paletteRect = rect.map(v => Math.round(v * 1000) / 1000);
                                if (!PaletteGenerator.auto)
                                    PaletteGenerator.generate();
                            }
                        }
                    }
                    Column {
                        spacing: Theme.u * 2
                        width: Math.max(Theme.u * 60, areaRow.width - thumbBox.width - Theme.u * 4)
                        PxText {
                            text: Config.appearance.paletteArea === "custom" ? I18n.t("Нарисуй рамку на картинке. Цвета области:", "Draw a frame on the picture. The area's colours:") : I18n.t("Цвета области:", "The area's colours:")
                            kind: "tiny"
                            dim: true
                            width: parent.width
                            wrapMode: Text.Wrap
                        }
                        ColorQuantizer {
                            id: areaColors
                            depth: 3
                            rescaleSize: 96
                            source: areaView.visible && areaView.picture && PaletteGenerator.sizes[areaView.picture] ? "file://" + areaView.picture : ""
                            imageRect: PaletteGenerator.pixelRect(areaView.picture, areaView.rect || [0, 0, 1, 1]) || Qt.rect(0, 0, 0, 0)
                        }
                        Flow {
                            width: parent.width
                            spacing: Theme.u * 2
                            Repeater {
                                // the same colour from several buckets once
                                model: {
                                    const out = [];
                                    for (const c of areaColors.colors)
                                        if (!out.some(o => o.toString() === c.toString()))
                                            out.push(c);
                                    return out;
                                }
                                PxBox {
                                    id: sw
                                    required property color modelData
                                    width: Theme.u * 14
                                    height: Theme.u * 14
                                    color: modelData
                                    MouseArea {
                                        id: swMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onContainsMouseChanged: areaInfo.hovered = containsMouse ? sw.modelData.toString() : ""
                                        onClicked: PaletteGenerator.apply(sw.modelData.toString(), true)
                                    }
                                }
                            }
                        }
                        PxText {
                            id: areaInfo
                            property string hovered: ""
                            width: parent.width
                            kind: "tiny"
                            dim: true
                            wrapMode: Text.Wrap
                            text: hovered ? hovered + I18n.t(" — клик: сделать акцентом", " — click: make it the accent") : ""
                        }
                    }
                }
            }
        }
        // the eyedropper (services/ColorPicker): any pixel of any screen, its hex in the clipboard
        CatCustom {
            label: I18n.t("Пипетка", "Eyedropper")
            hint: I18n.t("взять цвет с экрана (Win+Shift+C): цвет сразу в буфере; ПКМ по образцу — сделать акцентом", "Pick a colour off the screen (Win+Shift+C): it goes to the clipboard; right click a swatch to make it the accent")
            CatBox {
                Column {
                    width: parent.width
                    spacing: Theme.u * 2
                    Flow {
                        width: parent.width
                        spacing: Theme.u * 3
                        PxButton {
                            text: ColorPicker.busy ? I18n.t("Кликни по цвету…", "Click a colour…") : I18n.t("Взять с экрана", "Pick from the screen")
                            icon: "drop"
                            enabled: !ColorPicker.busy
                            onClicked: ColorPicker.pick()
                        }
                        PxButton {
                            visible: ColorPicker.recent.length > 0
                            compact: true
                            icon: "trash"
                            Accessible.name: I18n.t("Забыть цвета пипетки", "Forget the picked colours")
                            onClicked: ColorPicker.forget()
                        }
                    }
                    Flow {
                        width: parent.width
                        spacing: Theme.u * 2
                        Repeater {
                            model: ColorPicker.recent
                            PxBox {
                                id: picked
                                required property string modelData
                                width: Theme.u * 14
                                height: Theme.u * 14
                                color: modelData
                                MouseArea {
                                    id: pickedMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: pickedInfo.hovered = containsMouse ? picked.modelData : ""
                                    onClicked: e => {
                                        if (e.button === Qt.RightButton)
                                            PaletteGenerator.apply(picked.modelData, true);
                                        else
                                            ColorPicker.copy(picked.modelData);
                                    }
                                }
                            }
                        }
                    }
                    PxText {
                        id: pickedInfo
                        property string hovered: ""
                        visible: ColorPicker.recent.length > 0
                        width: parent.width
                        kind: "tiny"
                        dim: true
                        text: hovered ? hovered + I18n.t(" — клик: копировать, ПКМ: акцент", " — click: copy, right click: accent") : I18n.t("последний: ", "last: ") + ColorPicker.recent[0]
                    }
                }
            }
        }
        CatNote {
            text: PaletteGenerator.error
            present: text !== ""
        }
        // palette preview
        CatCustom {
            wide: true
            CatBox {
                // palette preview
                Row {
                    spacing: Theme.u * 2
                    Repeater {
                        model: [Theme.accent, Theme.accent2, Theme.accent3, Theme.accent4, Theme.title1, Theme.title2, Theme.tone("face", Theme.p5For(parent)), Theme.tone("faceAlt", Theme.p5For(parent)), Theme.tone("text", Theme.p5For(parent)), Theme.danger, Theme.tone("ok", Theme.p5For(parent))]
                        PxBox {
                            required property color modelData
                            width: Theme.u * 14
                            height: Theme.u * 14
                            color: modelData
                        }
                    }
                }
            }
        }
    }
    CatGroup {
        name: "motion"
        title: I18n.t("Движение", "Motion")
        icon: "sparkle"
        CatChoice {
            id: motionRow
            // D4: the way into a circle at this level — the jolt, the slow dark, or a cut
            preview: "CircleFx"
            label: I18n.t("Анимации", "Animations")
            hint: Motion.level === "off" ? I18n.t("всё стоит: анимации оболочки, niri и Ада выключены, рай ⇄ ад меняются сразу; ангел и демоница только тихо дышат. Режим оптимизации", "Everything stands still: the shell's, niri's and hell's animations are off, heaven ⇄ hell switch at once; the angel and the demon only breathe quietly. The optimisation mode") : Motion.level === "calm" ? I18n.t("без вспышек, тряски экрана и резких звуков: лучи ангела и тряска не появляются, переходы между кругами медленнее и тише, буквы реплик не дрожат", "No flashes, screen shaking or sudden loud sounds: no angel rays or shaking, hell's transitions are slower and quieter, the letters of her lines don't tremble") : I18n.t("всё как задумано; отдельные анимации — в своих разделах", "Everything as designed; single animations live in their own sections")
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
    // D3: the shell's icons — ours, pixelarticons or HackerNoon's (widgets/IconSets.js)
    CatGroup {
        name: "icons"
        title: I18n.t("Значки", "Icons")
        icon: "grid"
        CatCustom {
            label: I18n.t("Стиль значков", "Icon style")
            hint: I18n.t("значки панели, меню и настроек; значки программ — из темы системы", "The icons of the bar, menus and settings; apps' icons come from the system theme")
            CatBox {
                IconStyleCards {}
            }
        }
        CatCustom {
            label: I18n.t("Цвет папок", "Folder colour")
            hint: I18n.t("папки в Nautilus и в окнах выбора файлов (тема значков Pixora): в цвет темы — они меняются вместе с ней, в аду тоже; или один из цветов; или как нарисовал автор Pixora", "Folders in Nautilus and in file choosers (the Pixora icon theme): in the theme's colour, changing with it, hell included; one of the colours; or as Pixora's author drew them")
            CatBox {
                FolderSwatches {
                    width: parent ? parent.width : implicitWidth
                }
            }
        }
    }
    CatGroup {
        name: "window-titles"
        title: I18n.t("Подписи окон", "Window titles")
        icon: "monitor"
        CatChoice {
            label: I18n.t("Окончание в названиях", "Name ending")
            // suffix-ok: the three endings themselves
            hint: I18n.t("calendar.exe, .sh или .bin — для красоты, в подписях окошек angelOS", "calendar.exe, .sh or .bin — just for looks, in angelOS's window titles")
            model: I18n.suffixes.map(s => ({
                        "label": "." + s,
                        "value": s
                    }))
            currentValue: I18n.suffix
            onActivated: v => Config.desktop.titleSuffix = v
        }
    }
    CatGroup {
        name: "glass-pixels"
        title: I18n.t("Прозрачность и пиксели", "Transparency and pixels")
        advanced: true
        icon: "sparkle"
        CatToggle {
            label: I18n.t("Блюр под панелями", "Blur behind panels")
            hint: I18n.t("размытие под панелями и меню", "Blur under the bars and menus")
            checked: Config.appearance.blur
            onToggled: c => Config.appearance.blur = c
        }
        CatSlider {
            label: I18n.t("Непрозрачность панелей", "Panel opacity")
            from: 0.4
            to: 1
            stepSize: 0.02
            value: Config.appearance.opacity
            valueScale: 100
            suffix: "%"
            onMoved: v => Config.appearance.opacity = v
        }
        CatSlider {
            label: I18n.t("Сила блюра", "Blur strength")
            hint: I18n.t("одна на всё: панели, меню и окна", "One for everything: bars, menus and windows")
            from: 0.5
            to: 10
            stepSize: 0.5
            decimals: 1
            value: BlurConfig.offset
            onReleased: v => BlurConfig.save({offset: v})
            enabled: Config.appearance.blur && BlurConfig.supported && !BlurConfig.busy
        }
        CatSpin {
            label: I18n.t("Проходы размытия", "Blur passes")
            hint: I18n.t("Больше проходов — мягче размытие и выше нагрузка", "More passes soften the blur and use more GPU time")
            from: 1
            to: 6
            value: BlurConfig.passes
            onMoved: v => BlurConfig.save({passes: v})
            enabled: Config.appearance.blur && BlurConfig.supported && !BlurConfig.busy
        }
        CatSlider {
            label: I18n.t("Зернистость стекла", "Glass grain")
            from: 0
            to: 0.1
            stepSize: 0.002
            valueScale: 100
            decimals: 1
            suffix: "%"
            value: BlurConfig.noise
            onReleased: v => BlurConfig.save({noise: v})
            enabled: Config.appearance.blur && BlurConfig.supported && !BlurConfig.busy
        }
        CatNote {
            present: text !== ""
            dim: true
            text: BlurConfig.log
        }
        CatToggle {
            label: I18n.t("Жёсткие пиксельные тени", "Pixel shadows")
            checked: Config.appearance.shadows
            onToggled: c => Config.appearance.shadows = c
        }
    }
    CatGroup {
        name: "ui-size"
        title: I18n.t("Размер интерфейса", "Interface size")
        icon: "grid"
        CatSpin {
            label: I18n.t("Размер пикселя", "Pixel size")
            hint: I18n.t("крупнее всё: панели, окна, меню", "Everything bigger: bars, windows, menus")
            from: 1
            to: 4
            value: Config.appearance.px
            suffix: " px"
            onMoved: v => Config.appearance.px = v
        }
    }
    CatGroup {
        name: "application-theme"
        title: I18n.t("Тема для приложений", "Application theme")
        advanced: true
        icon: "terminal"
        CatToggle {
            label: I18n.t("Красить приложения", "Theme applications")
            hint: I18n.t("терминалы, GTK-программы и рамки окон в цветах темы", "Terminals, GTK apps and window frames in the theme's colours")
            checked: Config.appearance.themeApps
            onToggled: c => Config.appearance.themeApps = c
        }
        CatCustom {
            wide: true
            CatBox {
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
            }
        }
        CatToggle {
            present: Config.appearance.themeApps
            label: I18n.t("Qt-приложения в стиле angelOS", "Qt apps in the angelOS look")
            hint: I18n.t("Qt-программы (kdenlive, qBittorrent, Prism Launcher…) в цветах темы, с пиксельными кнопками. Открытые меняются сразу, остальные — при запуске.", "Qt apps (kdenlive, qBittorrent, Prism Launcher…) in the theme's colours with pixel buttons. Open ones change at once, the rest on their next start.")
            checked: Config.appearance.qtStyle
            onToggled: c => Config.appearance.qtStyle = c
        }
        CatCustom {
            wide: true
            CatBox {
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
    }
}
