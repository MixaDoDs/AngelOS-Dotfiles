pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

PxPage {
    id: page

    heading: I18n.t("Виджеты", "Widgets")
    subtitle: DesktopWidgets.macLook ? I18n.t("Карточки на рабочем столе. Двойной клик по карточке — режим правки: в нём карточку таскают за любое место, «−» убирает её. Ещё их можно добавить через ПКМ → Вид.", "Cards on the desktop. Double-click a card for edit mode: there you drag it anywhere, “−” removes it. You can also add them via right-click → View.") : I18n.t("Виджеты на рабочем столе. ПКМ по виджету — его размер S/M/L, рамка и настройки; таскаются за заголовок (без заголовка — за любое место), двойной клик — режим правки. Добавить — здесь или ПКМ по столу → Вид.", "Widgets on the desktop. Right-click one for its size S/M/L, frame and options; drag them by the title (without one, anywhere), double-click for edit mode. Add them here or via right-click on the desktop → View.")

    property string newType: DesktopWidgets.types.length ? DesktopWidgets.types[0].type : ""
    property string newScreen: Shell.primaryName || (Quickshell.screens[0] ? Quickshell.screens[0].name : "")
    readonly property var screenModel: Quickshell.screens.map(s => ({
                "label": s.name,
                "value": s.name
            }))

    // what the music widget's spectrum can listen to: outputs, whole multichannel interfaces,
    // their labelled channel pairs, and (marked) inputs — scripts/audio-tap.py list
    property var tap: ({
            "auto": "",
            "nodes": []
        })
    readonly property var tapModel: {
        const out = [
            {
                "label": I18n.t("Авто: весь звук ПК", "Auto: all computer sound") + (tap.auto ? " · " + tap.auto : ""),
                "value": ""
            }
        ];
        const outs = tap.nodes.filter(n => n.kind === "output");
        const ins = tap.nodes.filter(n => n.kind === "input");
        for (const n of outs) {
            out.push({
                "label": "♪ " + n.description,
                "value": "monitor:" + n.name
            });
            if (n.pairs.length) {
                out.push({
                    "label": "♪ " + n.description + I18n.t(" — все каналы (", " — all channels (") + n.channels.length + ")",
                    "value": "all:" + n.name
                });
                for (const pr of n.pairs)
                    out.push({
                        "label": "   ↳ " + (pr.label ? pr.label + " · " : "") + pr.channels.join("/"),
                        "value": "pair:" + n.name + ":" + pr.channels.join(",")
                    });
            }
        }
        for (const n of ins) {
            out.push({
                "label": "🎤 " + n.description + I18n.t(" (вход)", " (input)"),
                "value": "input:" + n.name
            });
            for (const pr of n.pairs)
                out.push({
                    "label": "   ↳ 🎤 " + (pr.label ? pr.label + " · " : "") + pr.channels.join("/"),
                    "value": "pair:" + n.name + ":" + pr.channels.join(",")
                });
        }
        return out;
    }
    function tapValue(v) {
        // older settings stored a bare sink name
        return v && !/^(monitor|all|pair|input):/.test(v) ? "monitor:" + v : (v || "");
    }
    function tapIsInput(v) {
        v = tapValue(v);
        if (v.startsWith("input:"))
            return true;
        if (!v.startsWith("pair:"))
            return false;
        const name = v.slice(5, v.lastIndexOf(":"));
        return tap.nodes.some(n => n.name === name && n.kind === "input");
    }
    Process {
        id: tapList
        running: DesktopWidgets.widgets.some(w => w.type === "music" && DesktopWidgets.sizeOf(w) !== "m")
        command: ["python3", Quickshell.shellDir + "/scripts/audio-tap.py", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.tap = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    PxGroup {
        name: "add"
        title: I18n.t("Добавить", "Add")
        icon: "plus"
        width: parent.width
        Row {
            spacing: Theme.u * 3
            PxCombo {
                width: Theme.u * 100
                model: DesktopWidgets.types.map(t => ({
                            "label": t.label,
                            "value": t.type,
                            "icon": t.icon
                        }))
                currentValue: page.newType
                onActivated: v => page.newType = v
            }
            PxCombo {
                width: Theme.u * 60
                model: page.screenModel
                currentValue: page.newScreen
                onActivated: v => page.newScreen = v
            }
            PxButton {
                text: I18n.t("Добавить", "Add")
                icon: "plus"
                accent: true
                enabled: page.newType !== "" && page.newScreen !== ""
                onClicked: DesktopWidgets.add(page.newType, page.newScreen)
            }
        }
    }

    PxGroup {
        name: "on-desktop"
        title: I18n.t("На рабочем столе", "On the desktop") + " (" + DesktopWidgets.widgets.length + ")"
        icon: "layers"
        width: parent.width

        PxText {
            visible: DesktopWidgets.widgets.length === 0
            text: I18n.t("пока пусто ♡", "nothing yet ♡")
            dim: true
        }

        Repeater {
            model: DesktopWidgets.widgets.map(w => w.uid)
            PxBox {
                id: card
                required property string modelData
                readonly property var w: DesktopWidgets.byUid(modelData)
                readonly property var info: w ? DesktopWidgets.typeInfo(w.type) : null
                readonly property var st: w && w.settings ? w.settings : ({})
                width: parent.width
                height: cardCol.implicitHeight + Theme.u * 8
                color: Theme.faceAlt

                Column {
                    id: cardCol
                    x: Theme.u * 4
                    y: Theme.u * 4
                    width: parent.width - Theme.u * 8
                    spacing: Theme.u * 3

                    Row {
                        width: parent.width
                        spacing: Theme.u * 4
                        PxIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: card.info ? card.info.icon : "heart"
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.u * 170
                            text: (card.info ? DesktopWidgets.titleOf(card.info) : "?") + "  ·  " + (card.info ? card.info.label : "")
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        PxCombo {
                            width: Theme.u * 60
                            model: page.screenModel
                            currentValue: card.w ? card.w.screen : ""
                            onActivated: v => DesktopWidgets.setScreen(card.modelData, v)
                        }
                        PxButton {
                            compact: true
                            icon: "refresh"
                            onClicked: DesktopWidgets.resetPosition(card.modelData)
                        }
                        PxButton {
                            compact: true
                            icon: "trash"
                            danger: true
                            onClicked: DesktopWidgets.remove(card.modelData)
                        }
                    }

                    SettingRow {
                        visible: !!card.info && DesktopWidgets.sizesOf(card.info).length > 0 && !DesktopWidgets.macLook
                        label: I18n.t("Раскладка", "Layout")
                        hint: ({
                                "clock": I18n.t("S — время, M — с датой, L — крупно и погода словами", "S time, M with the date, L big, the weather in words"),
                                "sysmon": I18n.t("S — четыре числа, M — шкалы, L — шкалы, минута истории и самые занятые программы", "S four numbers, M meters, L meters, a minute of history and the busiest programs"),
                                "music": I18n.t("S — спектр, M — плеер, L — плеер и спектр", "S the spectrum, M the player, L both"),
                                "picture": I18n.t("длинная сторона: 64 / 100 / 160", "The longer side: 64 / 100 / 160"),
                                "note": I18n.t("ширина и сколько строк видно", "Its width and how many lines show"),
                                "disks": I18n.t("S — системный диск, M — все диски, L — диски и папки", "S the system disk, M every disk, L disks and folders")
                            })[card.w ? card.w.type : ""] || ""
                        PxSegmented {
                            model: DesktopWidgets.sizesOf(card.info).map(z => ({
                                        "label": z.toUpperCase(),
                                        "value": z
                                    }))
                            currentValue: DesktopWidgets.sizeOf(card.w)
                            onActivated: v => DesktopWidgets.setSize(card.modelData, v)
                        }
                    }
                    SettingRow {
                        visible: !DesktopWidgets.macLook
                        label: I18n.t("Рамка", "Frame")
                        PxCombo {
                            width: Theme.u * 90
                            model: ["", "window", "plate", "none"].map(f => ({
                                        "label": DesktopWidgets.frameLabel(f),
                                        "value": f
                                    }))
                            currentValue: card.w && DesktopWidgets.frameKinds.includes(card.w.frame) ? card.w.frame : ""
                            onActivated: v => DesktopWidgets.setFrame(card.modelData, v)
                        }
                    }
                    SettingRow {
                        label: I18n.t("Масштаб", "Zoom")
                        hint: I18n.t("70–130 %; ещё — колёсико над виджетом в режиме правки или с Ctrl", "70–130 %; also the wheel over the widget in edit mode or with Ctrl")
                        PxSlider {
                            width: parent.width
                            from: 70
                            to: 130
                            stepSize: 5
                            suffix: " %"
                            value: Math.round(DesktopWidgets.scaleOf(card.w) * 100)
                            live: false
                            onReleased: v => DesktopWidgets.setScale(card.modelData, v / 100)
                        }
                    }
                    // per-type options
                    SettingRow {
                        visible: !!card.w && card.w.type === "clock"
                        label: I18n.t("Секунды", "Seconds")
                        PxToggle {
                            checked: !!card.st.seconds
                            onToggled: c => DesktopWidgets.setSetting(card.modelData, "seconds", c)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "clock"
                        label: I18n.t("Погода", "Weather")
                        hint: Weather.ok ? Weather.deg(Weather.now.temp) + " · " + Weather.words(Weather.now.code) + " · " + Weather.place.name : Weather.error ? I18n.t("не получилось: ", "failed: ") + Weather.error : I18n.t("Open-Meteo; город — в «Поведении» ниже", "Open-Meteo; the city is under Behavior below")
                        PxToggle {
                            checked: card.st.weather !== false
                            onToggled: c => DesktopWidgets.setSetting(card.modelData, "weather", c)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "music" && DesktopWidgets.sizeOf(card.w) !== "m"
                        label: I18n.t("Столбиков", "Bars")
                        PxSpin {
                            from: 8
                            to: 64
                            stepSize: 4
                            value: card.st.bars || 32
                            onMoved: v => DesktopWidgets.setSetting(card.modelData, "bars", v)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "music" && DesktopWidgets.sizeOf(card.w) !== "m"
                        label: I18n.t("Что слушать", "Listen to")
                        hint: page.tapIsInput(card.st.source) ? I18n.t("⚠ это вход: визуализатор будет рисовать микрофон", "⚠ this is an input: the visualizer will draw your microphone") : I18n.t("выход, всё устройство или пара каналов (только чтение, маршрутизация не меняется)", "an output, a whole interface or one channel pair (read-only, routing is untouched)")
                        Row {
                            width: parent.width
                            spacing: Theme.u * 2
                            PxCombo {
                                width: parent.width - refreshTap.width - Theme.u * 2
                                model: page.tapModel
                                currentValue: page.tapValue(card.st.source)
                                onActivated: v => DesktopWidgets.setSetting(card.modelData, "source", v)
                            }
                            PxButton {
                                id: refreshTap
                                compact: true
                                icon: "refresh"
                                onClicked: tapList.running = true
                            }
                        }
                    }
                    // ---- the picture ----
                    SettingRow {
                        visible: !!card.w && card.w.type === "picture"
                        label: I18n.t("Что показывать", "Show")
                        PxSegmented {
                            model: [
                                {
                                    "label": I18n.t("Файл", "A file"),
                                    "value": "file"
                                },
                                {
                                    "label": I18n.t("Папку", "A folder"),
                                    "value": "folder"
                                }
                            ]
                            currentValue: card.st.mode === "folder" ? "folder" : "file"
                            onActivated: v => DesktopWidgets.setSetting(card.modelData, "mode", v)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "picture" && card.st.mode !== "folder"
                        label: I18n.t("Файл", "File")
                        hint: card.st.file ? card.st.file : I18n.t("GIF, WebP, PNG, JPG или видео (без звука)", "A GIF, WebP, PNG, JPG or a video (without its sound)")
                        PxButton {
                            text: I18n.t("Выбрать…", "Choose…")
                            icon: "image"
                            enabled: DesktopWidgets.picking === ""
                            onClicked: DesktopWidgets.pick(card.modelData, "file", false)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "picture" && card.st.mode === "folder"
                        label: I18n.t("Папка", "Folder")
                        hint: card.st.folder ? card.st.folder : I18n.t("картинки из неё по очереди", "Its pictures, one after another")
                        PxButton {
                            text: I18n.t("Выбрать…", "Choose…")
                            icon: "folder"
                            enabled: DesktopWidgets.picking === ""
                            onClicked: DesktopWidgets.pick(card.modelData, "folder", true)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "picture" && card.st.mode === "folder"
                        label: I18n.t("Менять каждые", "Change every")
                        PxSpin {
                            from: 1
                            to: 240
                            value: card.st.interval || 5
                            suffix: I18n.t(" мин", " min")
                            onMoved: v => DesktopWidgets.setSetting(card.modelData, "interval", v)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "picture" && card.st.mode === "folder"
                        label: I18n.t("Вперемешку", "Shuffle")
                        PxToggle {
                            checked: card.st.shuffle !== false
                            onToggled: c => DesktopWidgets.setSetting(card.modelData, "shuffle", c)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "picture"
                        label: I18n.t("Паспарту", "Mat")
                        PxSegmented {
                            model: [
                                {
                                    "label": I18n.t("Нет", "None"),
                                    "value": "none"
                                },
                                {
                                    "label": I18n.t("Полароид", "Polaroid"),
                                    "value": "polaroid"
                                }
                            ]
                            currentValue: card.st.mat === "polaroid" ? "polaroid" : "none"
                            onActivated: v => DesktopWidgets.setSetting(card.modelData, "mat", v)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "picture" && card.st.mode !== "folder"
                        label: I18n.t("Сколько раз проиграть", "Play it")
                        hint: (card.st.loops || 0) === 0 ? I18n.t("0 — по кругу без конца", "0 — round and round for ever") : I18n.t("потом замирает на кадре ниже", "then it rests on the frame below")
                        PxSpin {
                            from: 0
                            to: 20
                            value: card.st.loops || 0
                            suffix: I18n.t(" раз", "×")
                            onMoved: v => DesktopWidgets.setSetting(card.modelData, "loops", v)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "picture" && card.st.mode !== "folder" && (card.st.loops || 0) > 0
                        label: I18n.t("Замереть на", "Rest on")
                        PxSegmented {
                            model: [
                                {
                                    "label": I18n.t("Последнем кадре", "The last frame"),
                                    "value": "last"
                                },
                                {
                                    "label": I18n.t("Первом кадре", "The first frame"),
                                    "value": "first"
                                }
                            ]
                            currentValue: card.st.rest === "first" ? "first" : "last"
                            onActivated: v => DesktopWidgets.setSetting(card.modelData, "rest", v)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "picture" && card.st.mode !== "folder" && (card.st.loops || 0) > 0
                        label: I18n.t("Снова через", "Again after")
                        hint: (card.st.every || 0) === 0 ? I18n.t("0 — один раз и всё", "0 — once and that's it") : ""
                        PxSpin {
                            from: 0
                            to: 240
                            stepSize: 5
                            value: card.st.every || 0
                            suffix: I18n.t(" мин", " min")
                            onMoved: v => DesktopWidgets.setSetting(card.modelData, "every", v)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "picture" && card.st.mode !== "folder"
                        label: I18n.t("Чёткие пиксели", "Sharp pixels")
                        hint: I18n.t("для пиксель-арта: без размытия, увеличение целыми разами", "For pixel art: no blur, whole-number zoom")
                        PxToggle {
                            checked: card.st.sharp !== false
                            onToggled: c => DesktopWidgets.setSetting(card.modelData, "sharp", c)
                        }
                    }
                    // ---- the note ----
                    SettingRow {
                        visible: !!card.w && card.w.type === "note"
                        label: I18n.t("Цвет", "Colour")
                        PxSegmented {
                            model: [0, 1, 2, 3].map(i => ({
                                        "label": [I18n.t("Розовый", "Pink"), I18n.t("Голубой", "Cyan"), I18n.t("Жёлтый", "Yellow"), I18n.t("Четвёртый", "Fourth")][i],
                                        "value": i
                                    }))
                            currentValue: card.st.tint || 0
                            onActivated: v => DesktopWidgets.setSetting(card.modelData, "tint", v)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "note"
                        label: I18n.t("Текст", "Text")
                        hint: "~/.config/angelos/notes/" + card.modelData.replace(/[^\w-]/g, "_") + ".md"
                        Row {
                            spacing: Theme.u * 2
                            PxButton {
                                text: I18n.t("Редактировать", "Edit")
                                icon: "note"
                                onClicked: DesktopWidgets.request(card.modelData, "edit")
                            }
                            PxButton {
                                text: I18n.t("Открыть файл", "Open the file")
                                icon: "document"
                                onClicked: Shell.openPath(Config.dir + "/notes/" + card.modelData.replace(/[^\w-]/g, "_") + ".md")
                            }
                        }
                    }
                    PxButton {
                        visible: !!card.info && !!card.info.plugin && !!card.info.plugin.settings
                        compact: true
                        text: I18n.t("Настройки плагина", "Plugin settings")
                        icon: "gear"
                        onClicked: page.nav.settingsPage = "plugin:" + card.info.plugin.id
                    }
                }
            }
        }
    }

    PxGroup {
        name: "behavior"
        title: I18n.t("Поведение", "Behavior")
        icon: "gear"
        width: parent.width
        SettingRow {
            label: I18n.t("Стиль виджетов", "Widget style")
            hint: I18n.t("«Авто»: карточки macOS со скином Golden Gate, пиксельные окна с остальными. В аду — всегда адские", "Auto: macOS cards with the Golden Gate skin, pixel windows with the others. In hell always hell's own")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Авто", "Auto"),
                        "value": "auto"
                    },
                    {
                        "label": I18n.t("Пиксельный", "Pixel"),
                        "value": "pixel"
                    },
                    {
                        "label": "macOS",
                        "value": "mac"
                    }
                ]
                currentValue: DesktopWidgets.style
                onActivated: v => Config.desktop.widgetStyle = v
            }
        }
        SettingRow {
            visible: !DesktopWidgets.macLook
            label: I18n.t("Рамка", "Frame")
            hint: I18n.t("для всех пиксельных виджетов; у любого можно поставить свою (ПКМ → Рамка)", "For every pixel widget; any of them can have its own (right-click → Frame)")
            PxSegmented {
                model: ["window", "plate", "none"].map(f => ({
                            "label": DesktopWidgets.frameLabel(f),
                            "value": f
                        }))
                currentValue: DesktopWidgets.frameDefault
                onActivated: v => Config.desktop.widgetFrame = v
            }
        }
        SettingRow {
            label: I18n.t("Город для погоды", "Weather city")
            hint: Weather.place ? I18n.t("сейчас: ", "now: ") + Weather.place.name + (Weather.place.from === "ip" ? I18n.t(" (по IP)", " (by IP)") : "") : I18n.t("пусто — по IP (ip-api.com); погода — Open-Meteo, раз в 30 минут", "Empty: by IP (ip-api.com); the weather from Open-Meteo, every 30 minutes")
            PxField {
                width: Theme.u * 100
                placeholder: I18n.t("по IP", "by IP")
                text: Config.desktop.weatherCity
                // Weather waits for the typing to stop before it asks
                onEdited: Config.desktop.weatherCity = text.trim()
            }
        }
        SettingRow {
            label: I18n.t("Режим правки", "Edit mode")
            hint: DesktopWidgets.macLook ? I18n.t("«−» на карточках, их можно таскать за любое место, видны скрытые", "“−” on the cards, drag them anywhere, hidden ones shown") : I18n.t("крестики на виджетах и видны скрытые", "close buttons on widgets, hidden ones shown")
            PxToggle {
                checked: DesktopWidgets.editMode
                onToggled: c => DesktopWidgets.editMode = c
            }
        }
        SettingRow {
            label: I18n.t("Сетка", "Grid")
            hint: I18n.t("к чему прилипают виджеты; в режиме правки сетка видна на обоях, сверху — панель с этим же выбором и «Выровнять всё»", "What the widgets snap to; in edit mode the grid shows on the wallpaper, with a bar on top for the same choice and “Align all”")
            PxSegmented {
                model: DesktopWidgets.gridLevels
                currentValue: DesktopWidgets.gridLevel
                onActivated: v => DesktopWidgets.setGrid(v)
            }
        }
        Row {
            spacing: Theme.u * 3
            Repeater {
                model: Quickshell.screens
                PxButton {
                    required property var modelData
                    compact: true
                    icon: "trash"
                    text: I18n.t("Убрать все с ", "Clear ") + modelData.name
                    onClicked: DesktopWidgets.removeAll(modelData.name)
                }
            }
        }
    }
}
