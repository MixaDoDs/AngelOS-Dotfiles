pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

PxPage {
    id: page

    heading: I18n.t("Обои", "Wallpaper")
    subtitle: I18n.t("Клик — поставить. Можно на все экраны, на монитор или на отдельный воркспейс.", "Click to apply to all displays, one monitor, or one workspace.")

    property string target: "all"   // all | output | workspace
    property string folder: ""
    property int pageNo: 0
    readonly property int perPage: 24
    readonly property var folders: {
        const set = {};
        for (const p of Wallpapers.heads)
            set[p.slice(0, p.lastIndexOf("/"))] = true;
        return Object.keys(set).sort();
    }
    // one card per wallpaper: its day / night / 21:9 / 9:16 files are one (Wallpapers.heads)
    readonly property var filtered: folder ? Wallpapers.heads.filter(p => p.slice(0, p.lastIndexOf("/")) === folder) : Wallpapers.heads
    readonly property int pages: Math.max(1, Math.ceil(filtered.length / perPage))
    onFolderChanged: pageNo = 0
    // heaven ⇄ hell: another set of pictures, start from the top
    readonly property bool hell: Wallpapers.hellOn
    onHellChanged: {
        folder = "";
        pageNo = 0;
    }
    property string output: Shell.focusedScreen ? Shell.focusedScreen.name : ""
    property int wsIdx: {
        const w = Niri.activeWorkspace(output);
        return w ? w.idx : 1;
    }

    function pick(path) {
        if (target === "all")
            Wallpapers.setEverywhere(path);
        else if (target === "output")
            Wallpapers.setForOutput(output, path);
        else
            Wallpapers.setForWorkspace(output, wsIdx, path);
    }

    // in hell: hell's own wallpaper, heaven's waits untouched (C2)
    PxBox {
        visible: Angel.demon
        width: parent.width
        height: hellNote.implicitHeight + Theme.u * 8
        color: Theme.mix(Theme.face, Theme.danger, 0.18)
        Row {
            x: Theme.u * 4
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.u * 8
            spacing: Theme.u * 3
            PxIcon {
                name: "fire"
                pixel: Theme.u * 2
                anchors.verticalCenter: parent.verticalCenter
            }
            PxText {
                id: hellNote
                width: parent.width - Theme.u * 20 - (Wallpapers.hellPackHere ? 0 : Theme.u * 40)
                wrapMode: Text.Wrap
                text: (I18n.t("Это обои Ада: здесь только адские картины, обои Рая не меняются и вернутся с ангелом. Выбранная картина держится до следующего круга.", "These are hell's wallpapers: only hell's pictures here; heaven's stay as they are and come back with the angel. A picked one stays until the next circle.") + (Wallpapers.hellPackHere ? "" : " " + I18n.t("Адский набор картин не скачан — пока только нарисованные.", "Hell's painting pack isn't downloaded — only the drawn hells for now.")))
            }
            PxButton {
                visible: !Wallpapers.hellPackHere
                compact: true
                hell: true
                icon: "download"
                enabled: !Wallpapers.fetching
                text: Wallpapers.fetching ? I18n.t("Скачиваю…", "Downloading…") : I18n.t("Скачать", "Download")
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Wallpapers.fetchHell()
            }
        }
    }

    PxGroup {
        name: "destination"
        title: I18n.t("Куда", "Destination")
        icon: "monitor"
        width: parent.width

        SettingRow {
            label: I18n.t("Применять", "Apply")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Везде", "Everywhere"),
                        "value": "all"
                    },
                    {
                        "label": I18n.t("Монитор", "Monitor"),
                        "value": "output"
                    },
                    {
                        "label": I18n.t("Воркспейс", "Workspace"),
                        "value": "workspace"
                    }
                ]
                currentValue: page.target
                onActivated: v => page.target = v
            }
        }
        SettingRow {
            visible: page.target !== "all"
            label: I18n.t("Монитор", "Monitor")
            PxCombo {
                width: Theme.u * 100
                model: Quickshell.screens.map(s => s.name)
                currentValue: page.output
                onActivated: v => page.output = v
            }
        }
        SettingRow {
            visible: page.target === "workspace"
            label: I18n.t("Воркспейс", "Workspace")
            PxCombo {
                width: Theme.u * 100
                model: Niri.workspacesOn(page.output).map(w => ({
                            "label": (w.name || "#" + w.idx) + (w.is_active ? "  ♡" : ""),
                            "value": w.idx
                        }))
                currentValue: page.wsIdx
                onActivated: v => page.wsIdx = v
            }
        }
        SettingRow {
            // hell's pictures have their own place (the Hell pack, the drawn hells)
            visible: !page.hell
            label: I18n.t("Папка", "Folder")
            Row {
                spacing: Theme.u * 3
                PxField {
                    id: dirField
                    width: Theme.u * 130
                    text: Config.wallpaper.dir
                    onAccepted: Config.wallpaper.dir = text
                }
                PxButton {
                    compact: true
                    icon: "folder"
                    onClicked: Wallpapers.pickDir()
                }
                PxButton {
                    compact: true
                    icon: "refresh"
                    onClicked: {
                        Config.wallpaper.dir = dirField.text;
                        Wallpapers.scan();
                    }
                }
                PxButton {
                    compact: true
                    icon: "sparkle"
                    text: I18n.t("случайные", "random")
                    onClicked: Wallpapers.random(page.target === "all" ? "" : page.output)
                }
            }
        }
        // new pictures into the folder: picked (the chooser opens where the last pick was) or
        // dragged in from the file manager
        SettingRow {
            visible: !page.hell
            label: I18n.t("Добавить обои", "Add wallpapers")
            hint: Wallpapers.importNote || I18n.t("Скопирует картинки в папку выше. Можно перетащить файлы прямо сюда из файлового менеджера", "Copies the pictures into the folder above. Files can be dragged right here from the file manager")
            PxBox {
                width: Theme.u * 150
                height: Theme.u * 14
                sunken: true
                color: addDrop.containsDrag ? Qt.alpha(Theme.accent, 0.25) : Theme.sunken
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.u * 3
                    PxButton {
                        compact: true
                        icon: "plus"
                        text: Wallpapers.importing ? "…" : I18n.t("Выбрать файлы…", "Pick files…")
                        enabled: !Wallpapers.importing
                        onClicked: Wallpapers.pickToImport()
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        dim: !addDrop.containsDrag
                        text: addDrop.containsDrag ? I18n.t("отпусти", "drop") : I18n.t("или перетащи сюда", "or drop here")
                    }
                }
                DropArea {
                    id: addDrop
                    anchors.fill: parent
                    onEntered: drag => drag.accepted = drag.hasUrls
                    onDropped: drop => {
                        Wallpapers.importFiles((drop.urls || []).map(u => String(u)).filter(u => u.startsWith("file://")).map(u => decodeURIComponent(u.slice(7))));
                        drop.accept(Qt.CopyAction);
                    }
                }
            }
        }
    }

    PxGroup {
        name: "variants"
        title: I18n.t("Варианты обоев", "Wallpaper variants")
        icon: "layers"
        width: parent.width
        SettingRow {
            label: I18n.t("Подбирать под тему и экран", "Fit the theme and the screen")
            hint: I18n.t("Одни обои в нескольких файлах — это одна карточка: днём ставится дневной, ночью ночной, на широкий монитор 21:9 или 32:9, на повёрнутый вертикально — 9:16. Форма берётся из самой картинки, а в имени достаточно пометить день/ночь: «озеро.png», «озеро-ночь.png», «озеро-21x9.png», «озеро 9 на 16.png» или папка «Озеро/» с «day.png», «night.png». Выключено — каждый файл сам по себе.", "One wallpaper in several files is one card: the day file by day, the night one at night, 21:9 or 32:9 on a wide monitor, 9:16 on one turned on its side. The shape is read from the picture; the name only marks day or night: lake.png, lake-night.png, lake-21x9.png, lake-9x16.png, or a Lake/ folder with day.png and night.png. Off: every file on its own.")
            PxToggle {
                checked: Config.wallpaper.variants !== false
                onToggled: c => Config.wallpaper.variants = c
            }
        }
    }

    // every big release of angelOS brings wallpapers drawn for it (services/Wallpapers: releases)
    PxGroup {
        name: "releases"
        visible: !page.hell && Wallpapers.releases.length > 0
        title: I18n.t("Обои релизов angelOS", "angelOS release wallpapers")
        icon: "sparkle"
        width: parent.width

        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: Wallpapers.variantsOn ? I18n.t("С каждым крупным релизом приходят свои обои, нарисованные для angelOS: днём и ночью — сами сменятся вместе с темой. Клик — поставить.", "Every big release comes with wallpapers drawn for angelOS, a day and a night one: they follow the theme. Click to apply.") : I18n.t("С каждым крупным релизом приходят свои обои, нарисованные для angelOS: днём и ночью. Клик — поставить.", "Every big release comes with wallpapers drawn for angelOS, a day and a night one. Click to apply.")
        }
        Repeater {
            model: Wallpapers.releases
            Column {
                id: relCol
                required property var modelData
                required property int index
                width: parent.width
                spacing: Theme.u * 2
                PxText {
                    text: Wallpapers.releaseLabel(relCol.modelData) + (relCol.index === 0 ? I18n.t("  · новые", "  · newest") : "") + "   " + relCol.modelData.date
                    color: relCol.index === 0 ? Theme.accent : Theme.text
                }
                Flow {
                    width: parent.width
                    spacing: Theme.u * 4
                    Repeater {
                        model: relCol.modelData.walls
                        Column {
                            id: wallCol
                            required property var modelData
                            spacing: Theme.u
                            Row {
                                spacing: Theme.u * 2
                                Repeater {
                                    // day and night are one wallpaper when variants follow the theme
                                    model: Wallpapers.variantsOn ? [wallCol.modelData.day || wallCol.modelData.night] : [wallCol.modelData.day, wallCol.modelData.night].filter(f => !!f)
                                    Item {
                                        id: rt
                                        required property string modelData
                                        readonly property bool active: Wallpapers.sameSet(page.target === "all" ? Wallpapers.raw(Quickshell.screens[0].name, 1) : page.target === "output" ? Wallpapers.raw(page.output, -1) : Wallpapers.raw(page.output, page.wsIdx), modelData)
                                        width: Theme.u * 56
                                        height: Theme.u * 32
                                        PxBox {
                                            anchors.fill: parent
                                            sunken: true
                                            color: Theme.sunken
                                            edgeColor: rt.active ? Theme.accent : Theme.edge
                                            Image {
                                                anchors.fill: parent
                                                source: "file://" + Wallpapers.pick(rt.modelData, page.output)
                                                sourceSize: Qt.size(480, 270)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                smooth: false
                                            }
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.width: rm.containsMouse || rt.active ? Theme.u * 2 : 0
                                            border.color: Theme.accent
                                        }
                                        PxIcon {
                                            visible: rt.active
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: Theme.u * 2
                                            name: "heart"
                                        }
                                        MouseArea {
                                            id: rm
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.pick(rt.modelData)
                                        }
                                    }
                                }
                            }
                            PxText {
                                visible: wallCol.modelData.name !== ""
                                text: wallCol.modelData.name
                                dim: true
                            }
                        }
                    }
                }
            }
        }
    }

    PxGroup {
        name: "transition"
        title: I18n.t("Переход", "Transition")
        icon: "sparkle"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: I18n.t("Играет только когда меняешь картинку. При переключении воркспейсов обои меняются мгновенно.", "Runs when the image changes. Workspace wallpapers otherwise switch instantly.")
            dim: true
        }
        SettingRow {
            id: fxRow
            preview: "WallpaperFx"
            label: I18n.t("Эффект", "Effect")
            hint: {
                const s = Wallpapers.transitions.find(x => x.id === Config.wallpaper.transition);
                return s ? s.hint : Config.wallpaper.transition === "random" ? I18n.t("каждый раз другой", "a different one every time") : I18n.t("картинка меняется сразу", "The picture changes at once");
            }
            PxCombo {
                width: parent.width
                model: Wallpapers.transitions.map(s => ({
                            "label": s.label,
                            "value": s.id
                        })).concat([
                        {
                            "label": I18n.t("Случайный", "Random"),
                            "value": "random"
                        },
                        {
                            "label": I18n.t("Нет", "None"),
                            "value": "none"
                        }
                    ])
                currentValue: Config.wallpaper.transition
                onActivated: v => {
                    Config.wallpaper.transition = v;
                    const s = Wallpapers.transitions.find(x => x.id === v);
                    fxRow.show(v, s ? s.label : v === "random" ? I18n.t("случайный", "random") : I18n.t("без перехода", "none"));
                }
            }
        }
        SettingRow {
            label: I18n.t("Длительность", "Duration")
            PxSlider {
                width: parent.width
                from: 200
                to: 2000
                stepSize: 50
                value: Config.wallpaper.duration
                suffix: I18n.t(" мс", " ms")
                onMoved: v => Config.wallpaper.duration = v
            }
        }
        SettingRow {
            label: I18n.t("Крупность мозаики", "Mosaic size")
            PxSlider {
                width: parent.width
                from: 8
                to: 128
                stepSize: 8
                value: Config.wallpaper.maxBlock
                suffix: " px"
                onMoved: v => Config.wallpaper.maxBlock = v
            }
        }
    }

    // the release's name on the desktop (widgets/ReleaseMark)
    PxGroup {
        name: "release-mark"
        visible: !!Updates.release
        title: I18n.t("Надпись релиза", "Release name")
        icon: "sparkle"
        width: parent.width

        SettingRow {
            label: I18n.t("Показывать на рабочем столе", "Show on the desktop")
            hint: Updates.release ? "angelOS " + Updates.release.number + (Updates.release.codename ? " · " + Updates.release.codename : "") + I18n.t(" — мелко и прозрачно, в свободном углу", ": small and see-through, in a free corner") : ""
            PxToggle {
                checked: Config.wallpaper.releaseMark
                onToggled: c => Config.wallpaper.releaseMark = c
            }
        }
        SettingRow {
            visible: Config.wallpaper.releaseMark
            label: I18n.t("Где", "Where")
            hint: I18n.t("«Само» — угол, который не заняли виджеты", "Auto: a corner no widget covers")
            PxSegmented {
                model: [["auto", "Само", "Auto"], ["top-left", "↖", "↖"], ["top-right", "↗", "↗"], ["bottom-left", "↙", "↙"], ["bottom-right", "↘", "↘"]].map(c => ({
                            "label": I18n.t(c[1], c[2]),
                            "value": c[0]
                        }))
                currentValue: Config.wallpaper.releaseMarkCorner
                onActivated: v => Config.wallpaper.releaseMarkCorner = v
            }
        }
        SettingRow {
            visible: Config.wallpaper.releaseMark
            label: I18n.t("Прозрачность", "Opacity")
            PxSlider {
                width: parent.width
                from: 10
                to: 80
                stepSize: 5
                value: Config.wallpaper.releaseMarkOpacity
                suffix: " %"
                onMoved: v => Config.wallpaper.releaseMarkOpacity = v
            }
        }
    }

    // half-alive wallpapers (services/LiveWalls): what in the picture may move a little
    PxGroup {
        id: liveGroup
        name: "live"
        title: I18n.t("Живые обои", "Alive")
        icon: "sparkle"
        width: parent.width
        // the picture on the screen these settings are open on
        readonly property string path: Wallpapers.resolve(page.output, page.wsIdx)
        readonly property var fx: LiveWalls.effective(path)
        readonly property var over: (Config.wallpaper.liveOverrides || {})[path] || {}
        Component.onCompleted: LiveWalls.request(path)
        onPathChanged: LiveWalls.request(path)

        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Если на картинке есть ночное небо, вода или огоньки, они чуть-чуть оживают: звёзды мерцают и иногда падают, вода рябит и отражает небо, водопады текут, окна и звёзды поблёскивают. Ненавязчиво, по пикселям картинки. Картинку оболочка разглядывает сама, один раз.", "If the picture has a night sky, water or little lights, they come a little alive: stars twinkle and now and then fall, water ripples and mirrors the sky, waterfalls stream, windows and stars glimmer. Quietly, on the picture's own pixels. The shell looks at each picture by itself, once.")
        }
        SettingRow {
            label: I18n.t("Живые обои", "Alive wallpaper")
            hint: Motion.still ? I18n.t("сейчас выключено: движение в оболочке остановлено", "off now: motion is turned off in the shell") : Theme.hell ? I18n.t("в Аду своё: оживает только в Раю", "hell has its own: comes alive in heaven only") : ""
            PxToggle {
                checked: Config.wallpaper.live
                onToggled: c => Config.wallpaper.live = c
            }
        }
        SettingRow {
            label: I18n.t("На этой картинке", "In this picture")
            hint: liveGroup.path.replace(Config.home, "~")
            Row {
                spacing: Theme.u * 3
                PxText {
                    width: Math.min(Theme.u * 150, implicitWidth)
                    wrapMode: Text.Wrap
                    anchors.verticalCenter: parent.verticalCenter
                    text: LiveWalls.describe(liveGroup.path)
                }
                PxButton {
                    compact: true
                    icon: "refresh"
                    enabled: LiveWalls.busy === ""
                    text: I18n.t("ещё раз", "again")
                    onClicked: LiveWalls.reanalyze(liveGroup.path)
                }
            }
        }
        // the same picture, alive, small
        Item {
            id: livePreview
            visible: Config.wallpaper.live
            width: Math.min(parent.width, Theme.u * 200)
            height: Math.round(width * 9 / 16)
            PxBox {
                anchors.fill: parent
                sunken: true
                color: Theme.sunken
            }
            Image {
                id: liveThumb
                anchors.fill: parent
                anchors.margins: Theme.u
                source: liveGroup.path ? "file://" + Wallpapers.display(liveGroup.path) : ""
                sourceSize: Qt.size(Math.round(width * 2), Math.round(height * 2))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: false
                visible: false
            }
            ShaderEffectSource {
                id: liveThumbSrc
                sourceItem: liveThumb
                hideSource: true
                visible: false
            }
            Image {
                anchors.fill: liveThumb
                source: liveThumb.source
                sourceSize: liveThumb.sourceSize
                fillMode: Image.PreserveAspectCrop
                smooth: false
            }
            LiveWall {
                anchors.fill: liveThumb
                screenName: page.output
                path: liveGroup.path
                picture: liveThumbSrc
                allowed: liveThumb.status === Image.Ready && livePreview.visible
            }
        }
        SettingRow {
            visible: Config.wallpaper.live
            label: I18n.t("Заметность", "How noticeable")
            hint: I18n.t("насколько сильно мерцает и рябит", "how much it twinkles and ripples")
            PxSlider {
                width: parent.width
                from: 10
                to: 100
                stepSize: 5
                value: Config.wallpaper.liveStrength
                suffix: " %"
                onMoved: v => Config.wallpaper.liveStrength = v
            }
        }
        SettingRow {
            visible: Config.wallpaper.live
            label: I18n.t("Звёзды мерцают", "Stars twinkle")
            hint: I18n.t("звёзды картинки и новые, которые появляются и гаснут", "the picture's stars and new ones that come and go")
            PxToggle {
                checked: Config.wallpaper.liveStars
                onToggled: c => Config.wallpaper.liveStars = c
            }
        }
        SettingRow {
            visible: Config.wallpaper.live
            label: I18n.t("Падающие звёзды", "Falling stars")
            hint: I18n.t("изредка, в верхней части неба", "now and then, high in the sky")
            PxToggle {
                checked: Config.wallpaper.liveMeteors
                onToggled: c => Config.wallpaper.liveMeteors = c
            }
        }
        SettingRow {
            visible: Config.wallpaper.live
            label: I18n.t("Вода", "Water")
            hint: I18n.t("водопады текут, море колышется, туман в бездне, блики, тени облаков", "waterfalls pour, the sea sways, mist in the abyss, glints, clouds' shadows")
            PxToggle {
                checked: Config.wallpaper.liveWater
                onToggled: c => Config.wallpaper.liveWater = c
            }
        }
        SettingRow {
            visible: Config.wallpaper.live
            label: I18n.t("Редкие события", "Now and then")
            hint: I18n.t("раз в 12–35 секунд: блик по кольцу, камешек с обрыва, порыв ветра, глаз в облаке ночью, круги по воде; под музыку — в долю. В полноэкранном режиме сцена замирает", "every 12–35 seconds: a glint over a ring, a pebble off the edge, a gust, an eye in a cloud at night, rings over the water; with music, on the beat. Under a fullscreen window the scene holds still")
            PxToggle {
                checked: Config.wallpaper.liveEvents
                onToggled: c => Config.wallpaper.liveEvents = c
            }
        }
        SettingRow {
            visible: Config.wallpaper.live
            label: I18n.t("Огоньки", "Lights")
            hint: I18n.t("окна и фонари на ночной картинке поблёскивают", "windows and lamps of a night picture glimmer")
            PxToggle {
                checked: Config.wallpaper.liveLights
                onToggled: c => Config.wallpaper.liveLights = c
            }
        }
        SettingRow {
            visible: Config.wallpaper.live
            label: I18n.t("Кадров в секунду", "Frames per second")
            hint: I18n.t("меньше — пиксельнее и легче для видеокарты; «Монитор» — каждый кадр экрана", "fewer: more pixel-like and lighter on the GPU; Monitor: every frame of the screen")
            PxSegmented {
                model: [12, 24, 60, 0].map(v => ({
                            "label": v ? String(v) : I18n.t("Монитор", "Monitor"),
                            "value": v
                        }))
                currentValue: Config.wallpaper.liveFps
                onActivated: v => Config.wallpaper.liveFps = v
            }
        }
        // the finding, corrected by hand for this picture
        SettingRow {
            visible: Config.wallpaper.live
            label: I18n.t("Небо на этой картинке", "Sky in this picture")
            hint: I18n.t("«есть» — всё выше линии воды", "\"Yes\": everything above the waterline")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Само", "Auto"),
                        "value": "auto"
                    },
                    {
                        "label": I18n.t("Есть", "Yes"),
                        "value": "on"
                    },
                    {
                        "label": I18n.t("Нет", "No"),
                        "value": "off"
                    }
                ]
                currentValue: liveGroup.over.sky || "auto"
                onActivated: v => LiveWalls.setOverride(liveGroup.path, "sky", v)
            }
        }
        SettingRow {
            visible: Config.wallpaper.live
            label: I18n.t("Вода на этой картинке", "Water in this picture")
            hint: I18n.t("«есть» — всё ниже линии воды, с отражением", "\"Yes\": everything below the waterline, with a reflection")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Само", "Auto"),
                        "value": "auto"
                    },
                    {
                        "label": I18n.t("Есть", "Yes"),
                        "value": "on"
                    },
                    {
                        "label": I18n.t("Нет", "No"),
                        "value": "off"
                    }
                ]
                currentValue: liveGroup.over.water || "auto"
                onActivated: v => LiveWalls.setOverride(liveGroup.path, "water", v)
            }
        }
        SettingRow {
            visible: Config.wallpaper.live && !!liveGroup.fx && (liveGroup.fx.water || liveGroup.over.sky === "on")
            label: I18n.t("Линия воды", "Waterline")
            hint: I18n.t("где кончается небо и начинается отражение (сверху вниз)", "where the sky ends and the reflection begins (from the top)")
            PxSlider {
                width: parent.width
                from: 20
                to: 95
                stepSize: 1
                value: liveGroup.fx ? Math.round(liveGroup.fx.axis * 100) : 65
                suffix: " %"
                onMoved: v => LiveWalls.setOverride(liveGroup.path, "axis", v / 100)
            }
        }
    }

    PxGroup {
        name: "images"
        title: I18n.t("Картинки (", "Images (") + page.filtered.length + ")"
        icon: "image"
        width: parent.width

        Row {
            spacing: Theme.u * 3
            PxCombo {
                width: Theme.u * 120
                model: [
                    {
                        "label": I18n.t("все папки", "All folders"),
                        "value": ""
                    }
                ].concat(page.folders.map(f => ({
                            "label": f.replace(Config.home, "~"),
                            "value": f
                        })))
                currentValue: page.folder
                onActivated: v => page.folder = v
            }
            PxButton {
                compact: true
                icon: "arrowLeft"
                enabled: page.pageNo > 0
                onClicked: page.pageNo--
            }
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                text: (page.pageNo + 1) + " / " + page.pages
            }
            PxButton {
                compact: true
                icon: "arrowRight"
                enabled: page.pageNo + 1 < page.pages
                onClicked: page.pageNo++
            }
        }

        Grid {
            id: grid
            width: parent.width
            columns: Math.max(2, Math.floor(width / (Theme.u * 72)))
            spacing: Theme.u * 3
            readonly property int cell: Math.floor((width - (columns - 1) * spacing) / columns)

            Repeater {
                model: page.filtered.slice(page.pageNo * page.perPage, (page.pageNo + 1) * page.perPage)
                Item {
                    id: thumb
                    required property string modelData
                    readonly property string currentHere: page.target === "all" ? Wallpapers.raw(Quickshell.screens[0].name, 1) : page.target === "output" ? Wallpapers.raw(page.output, -1) : Wallpapers.raw(page.output, page.wsIdx)
                    readonly property bool active: Wallpapers.sameSet(currentHere, modelData)
                    // the file this screen would show: the theme's, the screen's shape
                    readonly property string shownFile: Wallpapers.pick(modelData, page.output)
                    readonly property var tags: Wallpapers.variantTags(modelData)
                    width: grid.cell
                    height: Math.round(grid.cell * 9 / 16)

                    PxBox {
                        anchors.fill: parent
                        sunken: true
                        color: Theme.sunken
                        edgeColor: thumb.active ? Theme.accent : Theme.edge
                        Image {
                            anchors.fill: parent
                            source: "file://" + Wallpapers.display(thumb.shownFile)
                            // in the grimoire (or a dress): an engraving the right way round, not a negative
                            layer.enabled: Theme.inkWindows.length > 0 && Theme.inkWindows.includes(Window.window)
                            layer.effect: GrimoirePhoto {}
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            onStatusChanged: if (status === Image.Error)
                                Wallpapers.fit(thumb.shownFile)
                        }
                    }
                    // what the wallpaper has: ☼ ☾ 16:9 21:9 9:16
                    PxBox {
                        visible: thumb.tags.length > 0
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.u * 2
                        width: tagText.implicitWidth + Theme.u * 4
                        height: tagText.implicitHeight + Theme.u * 2
                        color: Qt.alpha(Theme.face, 0.85)
                        PxText {
                            id: tagText
                            anchors.centerIn: parent
                            kind: "tiny"
                            text: thumb.tags.join(" ")
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: tm.containsMouse || thumb.active ? Theme.u * 2 : 0
                        border.color: Theme.accent
                    }
                    PxIcon {
                        visible: thumb.active
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.u * 3
                        name: "heart"
                    }
                    MouseArea {
                        id: tm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.pick(thumb.modelData)
                    }
                }
            }
        }
    }
}
