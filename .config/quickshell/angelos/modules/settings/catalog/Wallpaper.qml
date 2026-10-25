// The settings once in WallpaperPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

CatPage {
    id: page
    heading: I18n.t("Обои", "Wallpaper")
    subtitle: I18n.t("Клик — поставить. Можно на все экраны, на монитор или на отдельный рабочий стол.", "Click to apply to all displays, one monitor, or one workspace.")
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
    CatCustom {
        wide: true
        CatBox {
            // in hell: hell's own wallpaper, heaven's waits untouched (C2)
            PxBox {
                visible: Angel.demon
                width: parent.width
                height: hellNote.implicitHeight + Theme.u * 8
                color: Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.danger, 0.18)
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
        }
    }
    CatGroup {
        name: "images"
        title: I18n.t("Картинки (", "Images (") + page.filtered.length + ")"
        icon: "image"
        CatCustom {
            wide: true
            CatBox {
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
            }
        }
        CatCustom {
            wide: true
            CatBox {
                Grid {
                    id: grid
                    width: parent.width
                    readonly property bool p5: Theme.p5For(grid)
                    columns: Math.max(2, Math.floor(width / (Theme.u * 72)))
                    // P5: room for each picture's slanted frame and its shadow
                    spacing: Theme.u * (p5 ? 7 : 3)
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
                            // P5: the one picked or pointed at pops up out of the row
                            transform: Translate {
                                y: grid.p5 && (tm.containsMouse || thumb.active) ? -Theme.u * 2 : 0
                            }

                            // P5: a slanted black frame on a hard shadow, the accent one for the picked
                            P5Slant {
                                visible: grid.p5
                                x: -Theme.u * 2
                                y: -Theme.u * 2
                                width: parent.width + Theme.u * 4
                                height: parent.height + Theme.u * 4
                                slant: 0.06
                                raised: true
                                color: tm.containsMouse || thumb.active ? Theme.accent : Theme.p5Black
                            }
                            PxBox {
                                anchors.fill: parent
                                sunken: true
                                color: Theme.tone("sunken", Theme.p5For(parent))
                                edgeColor: thumb.active ? Theme.accent : Theme.tone("edge", Theme.p5For(parent))
                                Image {
                                    anchors.fill: parent
                                    source: "file://" + Wallpapers.display(thumb.shownFile)
                                    // in the grimoire (or a dress): an engraving the right way round, not a negative
                                    layer.enabled: Theme.inkWindows.length > 0 && Theme.inkWindows.includes(Window.window)
                                    layer.effect: GrimoirePhoto {}
                                    // in steps, not every pixel: resizing Settings decoded the whole grid again each frame
                                    sourceSize: Qt.size(Math.ceil(width / 64) * 64, Math.ceil(height / 64) * 64)
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
                                color: Qt.alpha(Theme.tone("face", Theme.p5For(parent)), 0.85)
                                PxText {
                                    id: tagText
                                    anchors.centerIn: parent
                                    kind: "tiny"
                                    text: thumb.tags.join(" ")
                                }
                            }
                            Rectangle {
                                visible: !grid.p5
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
    }
    CatGroup {
        name: "destination"
        wide: true
        title: I18n.t("Куда", "Destination")
        icon: "monitor"
        CatChoice {
            label: I18n.t("Применять", "Apply")
            hint: I18n.t("Одни обои на всё, свои на каждом мониторе или на каждом столе.", "One wallpaper for all, one per monitor or one per workspace.")
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
                    "label": I18n.t("Стол", "Workspace"),
                    "value": "workspace"
                }
            ]
            currentValue: page.target
            onActivated: v => page.target = v
        }
        CatChoice {
            present: page.target !== "all"
            label: I18n.t("Монитор", "Monitor")
            combo: true
            model: Quickshell.screens.map(s => s.name)
            currentValue: page.output
            onActivated: v => page.output = v
        }
        CatChoice {
            present: page.target === "workspace"
            label: I18n.t("Стол", "Workspace")
            combo: true
            model: Niri.workspacesOn(page.output).map(w => ({
                        "label": (w.name || "#" + w.idx) + (w.is_active ? "  ♡" : ""),
                        "value": w.idx
                    }))
            currentValue: page.wsIdx
            onActivated: v => page.wsIdx = v
        }
        CatField {
            // hell's pictures have their own place (the Hell pack, the drawn hells)
            present: !page.hell
            label: I18n.t("Папка", "Folder")
            id: dirField
            text: Config.wallpaper.dir
            onEditingFinished: Config.wallpaper.dir = text
            CatButton {
                compact: true
                icon: "folder"
                onClicked: Wallpapers.pickDir()
            }
            CatButton {
                compact: true
                icon: "refresh"
                onClicked: {
                    Config.wallpaper.dir = dirField.text;
                    Wallpapers.scan();
                }
            }
            CatButton {
                compact: true
                icon: "sparkle"
                text: I18n.t("случайные", "random")
                onClicked: Wallpapers.random(page.target === "all" ? "" : page.output)
            }
        }
        // new pictures into the folder: picked (the chooser opens where the last pick was) or
        // dragged in from the file manager
        CatCustom {
            present: !page.hell
            label: I18n.t("Добавить обои", "Add wallpapers")
            hint: Wallpapers.importNote || I18n.t("Скопирует картинки в папку выше. Можно перетащить файлы прямо сюда из файлового менеджера", "Copies the pictures into the folder above. Files can be dragged right here from the file manager")
            CatBox {
                PxBox {
                    // wide enough for the button and the words (they are longer in Russian)
                    width: Math.min(parent.width, Math.max(Theme.u * 150, pickFilesButton.width + addWords.implicitWidth + Theme.u * 12))
                    // (as tall as the button: P5's is taller and broke the box's edges)
                    height: Math.max(Theme.u * 14, pickFilesButton.height + Theme.u * 4)
                    sunken: true
                    color: addDrop.containsDrag ? Qt.alpha(Theme.accent, 0.25) : Theme.tone("sunken", Theme.p5For(parent))
                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.u * 3
                        PxButton {
                            id: pickFilesButton
                            compact: true
                            icon: "plus"
                            text: Wallpapers.importing ? "…" : I18n.t("Выбрать файлы…", "Pick files…")
                            enabled: !Wallpapers.importing
                            onClicked: Wallpapers.pickToImport()
                        }
                        PxText {
                            id: addWords
                            // a narrow box elides the words, the button stays whole
                            width: Math.max(0, Math.min(implicitWidth, parent.parent.width - pickFilesButton.width - parent.spacing - Theme.u * 6))
                            elide: Text.ElideRight
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
    }
    // every big release of angelOS brings wallpapers drawn for it (services/Wallpapers: releases)
    CatGroup {
        name: "releases"
        title: I18n.t("Обои релизов angelOS", "angelOS release wallpapers")
        icon: "sparkle"
        present: !page.hell && Wallpapers.releasesShown.length > 0
        CatNote {
            dim: true
            text: Wallpapers.variantsOn ? I18n.t("С каждым крупным релизом приходят свои обои, нарисованные для angelOS: днём и ночью — сами сменятся вместе с темой. Клик — поставить.", "Every big release comes with wallpapers drawn for angelOS, a day and a night one: they follow the theme. Click to apply.") : I18n.t("С каждым крупным релизом приходят свои обои, нарисованные для angelOS: днём и ночью. Клик — поставить.", "Every big release comes with wallpapers drawn for angelOS, a day and a night one. Click to apply.")
        }
        CatCustom {
            wide: true
            CatBox {
                Repeater {
                    model: Wallpapers.releasesShown
                    Column {
                        id: relCol
                        required property var modelData
                        required property int index
                        width: parent.width
                        spacing: Theme.u * 2
                        PxText {
                            text: Wallpapers.releaseLabel(relCol.modelData) + (relCol.index === 0 ? I18n.t("  · новые", "  · newest") : "") + "   " + relCol.modelData.date
                            color: relCol.index === 0 ? Theme.accent : Theme.tone("text", Theme.p5For(parent))
                        }
                        Flow {
                            width: parent.width
                            // P5: room for the slanted frames and their shadows
                            spacing: Theme.u * (Theme.p5For(parent) ? 7 : 4)
                            Repeater {
                                model: relCol.modelData.walls
                                Column {
                                    id: wallCol
                                    required property var modelData
                                    spacing: Theme.u * (Theme.p5For(wallCol) ? 4 : 1)
                                    Row {
                                        spacing: Theme.u * (Theme.p5For(parent) ? 7 : 2)
                                        Repeater {
                                            // day and night are one wallpaper when variants follow the theme
                                            model: Wallpapers.variantsOn ? [wallCol.modelData.day || wallCol.modelData.night] : [wallCol.modelData.day, wallCol.modelData.night].filter(f => !!f)
                                            Item {
                                                id: rt
                                                required property string modelData
                                                readonly property bool active: Wallpapers.sameSet(page.target === "all" ? Wallpapers.raw(Quickshell.screens[0].name, 1) : page.target === "output" ? Wallpapers.raw(page.output, -1) : Wallpapers.raw(page.output, page.wsIdx), modelData)
                                                readonly property bool p5: Theme.p5For(rt)
                                                width: Theme.u * 56
                                                height: Theme.u * 32
                                                // P5: as the pictures above — a slanted frame, the picked one pops up
                                                transform: Translate {
                                                    y: rt.p5 && (rm.containsMouse || rt.active) ? -Theme.u * 2 : 0
                                                }
                                                P5Slant {
                                                    visible: rt.p5
                                                    x: -Theme.u * 2
                                                    y: -Theme.u * 2
                                                    width: parent.width + Theme.u * 4
                                                    height: parent.height + Theme.u * 4
                                                    slant: 0.06
                                                    raised: true
                                                    color: rm.containsMouse || rt.active ? Theme.accent : Theme.p5Black
                                                }
                                                PxBox {
                                                    anchors.fill: parent
                                                    sunken: true
                                                    color: Theme.tone("sunken", Theme.p5For(parent))
                                                    edgeColor: rt.active ? Theme.accent : Theme.tone("edge", Theme.p5For(parent))
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
                                                    visible: !rt.p5
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
        }
    }
    // half-alive wallpapers (services/LiveWalls): what in the picture may move a little
    CatGroup {
        id: liveGroup
        name: "live"
        title: I18n.t("Живые обои", "Alive")
        icon: "sparkle"
        // the picture on the screen these settings are open on
        readonly property string path: Wallpapers.resolve(page.output, page.wsIdx)
        readonly property var fx: LiveWalls.effective(path)
        readonly property var over: LiveWalls.override(path)
        // what this picture has; the effects it has not are not offered
        readonly property bool alive: Config.wallpaper.live && !!fx && fx.alive
        readonly property bool stars: alive && fx.sky && fx.night >= 0.3
        function value(key) {
            return Wallpapers.own(path, key);
        }
        function pick(key, v) {
            Wallpapers.setOwn(path, key, v);
        }
        Component.onCompleted: LiveWalls.request(path)
        onPathChanged: LiveWalls.request(path)
        present: Wallpapers.sceneOf(path) === ""
        CatNote {
            dim: true
            text: I18n.t("Ночное небо, вода и огоньки на картинке чуть оживают: звёзды мерцают, вода рябит, окна поблёскивают.", "Night sky, water and lights in the picture come a little alive: stars twinkle, water ripples, windows glint.")
        }
        CatToggle {
            label: I18n.t("Живые обои", "Alive wallpaper")
            hint: Motion.still ? I18n.t("сейчас выключено: движение в оболочке остановлено", "off now: motion is turned off in the shell") : Theme.hell ? I18n.t("в Аду своё: оживает только в Раю", "hell has its own: comes alive in heaven only") : ""
            checked: Config.wallpaper.live
            onToggled: c => Config.wallpaper.live = c
        }
        CatCustom {
            label: I18n.t("На этой картинке", "In this picture")
            hint: liveGroup.path.replace(Config.home, "~")
            CatBox {
                Row {
                    width: parent.width
                    spacing: Theme.u * 3
                    PxText {
                        width: Math.max(0, Math.min(Theme.u * 150, implicitWidth, parent.width - againButton.width - parent.spacing))
                        wrapMode: Text.Wrap
                        anchors.verticalCenter: parent.verticalCenter
                        text: LiveWalls.describe(liveGroup.path)
                    }
                    PxButton {
                        id: againButton
                        compact: true
                        icon: "refresh"
                        enabled: LiveWalls.busy === ""
                        text: I18n.t("ещё раз", "again")
                        onClicked: LiveWalls.reanalyze(liveGroup.path)
                    }
                }
            }
        }
        // paint what is what in this picture (services/SceneEditor)
        CatButton {
            present: SceneEditor.allowed
            label: I18n.t("Редактор сцены", "The scene editor")
            hint: I18n.t("Отметить на картинке небо, воду, водопад и выключить лишние эффекты.", "Mark sky, water and waterfalls on the picture and switch effects off.")
            icon: "layers"
            text: I18n.t("Открыть", "Open")
            onClicked: SceneEditor.edit(Wallpapers.origin(liveGroup.path))
        }
        // the same picture, alive, small
        CatCustom {
            wide: true
            CatBox {
                // the same picture, alive, small
                Item {
                    id: livePreview
                    visible: Config.wallpaper.live
                    width: Math.min(parent.width, Theme.u * 200)
                    height: Math.round(width * 9 / 16)
                    PxBox {
                        anchors.fill: parent
                        sunken: true
                        color: Theme.tone("sunken", Theme.p5For(parent))
                    }
                    Image {
                        id: liveThumb
                        anchors.fill: parent
                        anchors.margins: Theme.u
                        source: liveGroup.path ? "file://" + Wallpapers.display(liveGroup.path) : ""
                        // in steps, not every pixel: resizing Settings decoded the wallpaper again each frame
                        sourceSize: Qt.size(Math.ceil(width * 2 / 128) * 128, Math.ceil(height * 2 / 128) * 128)
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
            }
        }
        CatNote {
            present: liveGroup.alive
            dim: true
            text: I18n.t("Заметность и эффекты ниже — только для этих обоев: " + Wallpapers.wallName(liveGroup.path) + ". У других обоев свои.", "How noticeable and the effects below: for this wallpaper only, " + Wallpapers.wallName(liveGroup.path) + ". Other wallpapers keep their own.")
        }
        CatSlider {
            present: liveGroup.alive
            label: I18n.t("Заметность", "How noticeable")
            hint: I18n.t("насколько сильно мерцает и рябит", "how much it twinkles and ripples")
            from: 10
            to: 100
            stepSize: 5
            value: liveGroup.value("liveStrength")
            suffix: " %"
            onMoved: v => liveGroup.pick("liveStrength", v)
        }
        CatToggle {
            present: liveGroup.stars
            label: I18n.t("Звёзды мерцают", "Stars twinkle")
            hint: I18n.t("звёзды картинки и новые, которые появляются и гаснут", "the picture's stars and new ones that come and go")
            checked: liveGroup.value("liveStars")
            onToggled: c => liveGroup.pick("liveStars", c)
        }
        CatToggle {
            present: liveGroup.stars
            label: I18n.t("Падающие звёзды", "Falling stars")
            hint: I18n.t("изредка, в верхней части неба", "now and then, high in the sky")
            checked: liveGroup.value("liveMeteors")
            onToggled: c => liveGroup.pick("liveMeteors", c)
        }
        CatToggle {
            present: liveGroup.alive && liveGroup.fx.water
            label: I18n.t("Вода", "Water")
            hint: I18n.t("водопады текут, море колышется, туман в бездне, блики, тени облаков", "waterfalls pour, the sea sways, mist in the abyss, glints, clouds' shadows")
            checked: liveGroup.value("liveWater")
            onToggled: c => liveGroup.pick("liveWater", c)
        }
        CatToggle {
            present: liveGroup.alive
            label: I18n.t("Редкие события", "Now and then")
            hint: I18n.t("Иногда на обоях что-то происходит: блик, порыв ветра, круги по воде. Под музыку — в такт.", "Now and then something happens: a glint, a gust, rings on water. With music, on the beat.")
            checked: liveGroup.value("liveEvents")
            onToggled: c => liveGroup.pick("liveEvents", c)
        }
        CatToggle {
            present: liveGroup.alive && liveGroup.fx.lights > 0
            label: I18n.t("Огоньки", "Lights")
            hint: I18n.t("окна и фонари на ночной картинке поблёскивают", "windows and lamps of a night picture glimmer")
            checked: liveGroup.value("liveLights")
            onToggled: c => liveGroup.pick("liveLights", c)
        }
        CatChoice {
            present: Config.wallpaper.live
            label: I18n.t("Кадров в секунду", "Frames per second")
            hint: I18n.t("Меньше — легче для компьютера. «Монитор» на 144 Гц в 6 раз тяжелее, чем 24. На батарее до 24.", "Fewer is lighter. Monitor at 144 Hz is six times the work of 24. On battery, 24 at most.")
            model: [12, 24, 60, 0].map(v => ({
                        "label": v ? String(v) : I18n.t("Монитор", "Monitor"),
                        "value": v
                    }))
            currentValue: Config.wallpaper.liveFps
            onActivated: v => Config.wallpaper.liveFps = v
        }
        // the finding, corrected by hand for this picture
        CatChoice {
            present: Config.wallpaper.live
            label: I18n.t("Небо на этой картинке", "Sky in this picture")
            hint: I18n.t("«есть» — всё выше линии воды", "\"Yes\": everything above the waterline")
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
        CatChoice {
            present: Config.wallpaper.live
            label: I18n.t("Вода на этой картинке", "Water in this picture")
            hint: I18n.t("«есть» — всё ниже линии воды, с отражением", "\"Yes\": everything below the waterline, with a reflection")
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
        CatSlider {
            present: Config.wallpaper.live && !!liveGroup.fx && (liveGroup.fx.water || liveGroup.over.sky === "on")
            label: I18n.t("Линия воды", "Waterline")
            hint: I18n.t("где кончается небо и начинается отражение (сверху вниз)", "where the sky ends and the reflection begins (from the top)")
            from: 20
            to: 95
            stepSize: 1
            value: liveGroup.fx ? Math.round(liveGroup.fx.axis * 100) : 65
            suffix: " %"
            onMoved: v => LiveWalls.setOverride(liveGroup.path, "axis", v / 100)
        }
    }
    // pixel wallpapers (services/Wallpapers: pixel): any picture redrawn in big pixels
    CatGroup {
        id: pixelGroup
        name: "pixel"
        title: I18n.t("Пиксельные обои", "Pixel wallpaper")
        icon: "grid"
        // the picture of the screen these settings are open on, and what was made of it
        readonly property string picked: Wallpapers.pick(Wallpapers.raw(page.output, page.wsIdx), page.output)
        readonly property string shownFile: Wallpapers.resolve(page.output, page.wsIdx)
        readonly property var info: Wallpapers.pixelInfo(picked, page.output)
        readonly property bool busy: Config.wallpaper.pixel && !page.hell && !!picked && !info
        readonly property string said: {
            if (page.hell)
                return I18n.t("в Аду свои картины: их не перерисовываю", "hell has its own paintings: they are not redrawn");
            if (!picked)
                return "";
            if (!info)
                return I18n.t("перерисовываю…", "redrawing…");
            if (info.skip === "art")
                return I18n.t("уже пиксель-арт — оставлена как есть", "pixel art already: left as it is");
            if (info.skip === "animated")
                return I18n.t("гифка — оставлена как есть", "a GIF that moves: left as it is");
            if (info.error)
                return I18n.t("не вышло, показываю как есть: ", "it did not work, shown as it is: ") + info.error;
            if (info.small)
                return I18n.t("маленькая картинка — только увеличена без сглаживания, ", "a small picture: only enlarged without smoothing, ") + info.art[0] + "×" + info.art[1];
            return info.art[0] + "×" + info.art[1] + I18n.t(" пикселей, цветов: ", " pixels, colours: ") + info.colors;
        }
        CatNote {
            dim: true
            text: I18n.t("Любая картинка перерисовывается крупными пикселями, как всё в angelOS. Сам файл не меняется.", "Any picture is redrawn in big pixels, like the rest of angelOS. The file itself stays as it is.")
        }
        CatToggle {
            label: I18n.t("Пиксельные обои", "Pixel wallpaper")
            hint: I18n.t("для всех обоев сразу; уже пиксельные и гифки остаются как есть", "for every wallpaper at once; pixel art and GIFs stay as they are")
            checked: Config.wallpaper.pixel
            onToggled: c => Config.wallpaper.pixel = c
        }
        // the copy of this screen's picture: whole, and its middle at the screen's own pixels
        CatCustom {
            wide: true
            CatBox {
                // the copy of this screen's picture: whole, and its middle at the screen's own pixels
                Row {
                    id: pixRow
                    visible: Config.wallpaper.pixel && !page.hell && !!pixelGroup.picked
                    width: parent.width
                    spacing: Theme.u * 4
                    Repeater {
                        model: 2
                        Item {
                            id: pixBox
                            required property int index
                            width: Math.floor((pixRow.width - pixRow.spacing) / 2)
                            height: Math.round(Math.min(width, Theme.u * 160) * 9 / 16)
                            PxBox {
                                anchors.fill: parent
                                sunken: true
                                color: Theme.tone("sunken", Theme.p5For(parent))
                            }
                            Item {
                                anchors.fill: parent
                                anchors.margins: Theme.u
                                clip: true
                                Image {
                                    anchors.centerIn: parent
                                    width: pixBox.index === 0 ? parent.width : implicitWidth
                                    height: pixBox.index === 0 ? parent.height : implicitHeight
                                    source: pixelGroup.shownFile ? "file://" + Wallpapers.display(pixelGroup.shownFile) : ""
                                    fillMode: pixBox.index === 0 ? Image.PreserveAspectCrop : Image.Pad
                                    asynchronous: true
                                    smooth: false
                                }
                            }
                            PxText {
                                x: Theme.u * 3
                                y: Theme.u * 2
                                kind: "tiny"
                                color: "#ffffff"
                                style: Text.Outline
                                styleColor: "#000000"
                                text: pixBox.index === 0 ? I18n.t("целиком", "whole") : I18n.t("как на экране", "as on the screen")
                            }
                        }
                    }
                }
            }
        }
        CatCustom {
            present: Config.wallpaper.pixel
            label: I18n.t("На этой картинке", "In this picture")
            hint: pixelGroup.picked.replace(Config.home, "~")
            CatBox {
                PxText {
                    width: Math.min(Theme.u * 170, implicitWidth)
                    wrapMode: Text.Wrap
                    text: pixelGroup.said
                }
            }
        }
        CatChoice {
            present: Config.wallpaper.pixel
            label: I18n.t("Пиксели обоев", "Wallpaper pixels")
            hint: I18n.t("Насколько крупные пиксели у картинки. 4 — как у обоев релизов.", "How big the picture's pixels are. 4 matches the release wallpapers.")
            model: [2, 3, 4, 5, 6, 8, 10, 12].map(v => ({
                        "label": String(v),
                        "value": v
                    }))
            currentValue: Config.wallpaper.pixelSize
            onActivated: v => Config.wallpaper.pixelSize = v
        }
        CatChoice {
            present: Config.wallpaper.pixel
            label: I18n.t("Цветов", "Colours")
            hint: I18n.t("палитра собирается из цветов самой картинки; меньше — плакатнее", "the palette is made of the picture's own colours; fewer looks more like a poster")
            model: [8, 12, 16, 24, 32, 48, 64].map(v => ({
                        "label": String(v),
                        "value": v
                    }))
            currentValue: Config.wallpaper.pixelColors
            onActivated: v => Config.wallpaper.pixelColors = v
        }
        CatSlider {
            present: Config.wallpaper.pixel
            label: I18n.t("Дизеринг", "Dither")
            hint: I18n.t("Шахматка между цветами на гладких местах. 0 — ровные пятна цвета.", "A checker between colours on smooth areas. 0: flat patches.")
            from: 0
            to: 100
            stepSize: 10
            value: Config.wallpaper.pixelDither
            suffix: " %"
            onReleased: v => Config.wallpaper.pixelDither = Math.round(v)
        }
    }
    CatGroup {
        name: "variants"
        title: I18n.t("Варианты обоев", "Wallpaper variants")
        icon: "layers"
        CatToggle {
            label: I18n.t("Подбирать под тему и экран", "Fit the theme and the screen")
            hint: I18n.t("Варианты одной картинки — днём дневной, ночью ночной. Пометь в имени: «озеро-ночь.png».", "Variants of a picture: day by day, night at night. Mark it in the name: lake-night.png.")
            checked: Config.wallpaper.variants !== false
            onToggled: c => Config.wallpaper.variants = c
        }
        CatNote {
            present: Wallpapers.copiesHidden > 0
            dim: true
            text: I18n.t("Одинаковые картинки показаны один раз: копий спрятано — ", "The same picture is shown once: copies left out — ") + Wallpapers.copiesHidden + I18n.t(". Файлы на месте, из списка убраны только повторы.", ". The files stay where they are, only the repeats are off the list.")
        }
    }
    CatGroup {
        name: "transition"
        title: I18n.t("Переход", "Transition")
        icon: "sparkle"
        CatNote {
            text: I18n.t("Играет только когда меняешь картинку. При переключении столов обои меняются мгновенно.", "Runs when the image changes. Workspace wallpapers otherwise switch instantly.")
            dim: true
        }
        CatChoice {
            id: fxRow
            preview: "WallpaperFx"
            label: I18n.t("Эффект", "Effect")
            hint: {
                const s = Wallpapers.transitions.find(x => x.id === Config.wallpaper.transition);
                return s ? s.hint : Config.wallpaper.transition === "random" ? I18n.t("каждый раз другой", "a different one every time") : I18n.t("картинка меняется сразу", "The picture changes at once");
            }
            combo: true
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
        CatChoice {
            present: Config.wallpaper.transition === "verdict" || Config.wallpaper.transition === "random"
            label: I18n.t("Слово «Вердикта»", "The verdict's word")
            hint: I18n.t("«Авто» — DESCEND в ад, ASCEND обратно; без слова — пиксельный нимб. Своё слово — verdictTitle в settings.json", "Auto: DESCEND into hell, ASCEND back; no word: a pixel halo. A word of your own: verdictTitle in settings.json")
            model: [
                {
                    "label": I18n.t("Авто", "Auto"),
                    "value": "auto"
                },
                {
                    "label": I18n.t("Без слова", "No word"),
                    "value": "off"
                }
            ]
            currentValue: Config.wallpaper.verdictTitle === "off" ? "off" : "auto"
            onActivated: v => Config.wallpaper.verdictTitle = v
        }
        CatSlider {
            label: I18n.t("Длительность", "Duration")
            from: 200
            to: 2000
            stepSize: 50
            value: Config.wallpaper.duration
            suffix: I18n.t(" мс", " ms")
            onMoved: v => Config.wallpaper.duration = v
        }
        CatSlider {
            label: I18n.t("Крупность мозаики", "Mosaic size")
            hint: I18n.t("Насколько крупные квадраты в переходе мозаикой.", "How big the squares are in the mosaic transition.")
            from: 8
            to: 128
            stepSize: 8
            value: Config.wallpaper.maxBlock
            suffix: " px"
            onMoved: v => Config.wallpaper.maxBlock = v
        }
    }
    // the release's name on the desktop (widgets/ReleaseMark)
    CatGroup {
        name: "release-mark"
        title: I18n.t("Надпись релиза", "Release name")
        icon: "sparkle"
        present: !!Updates.release
        CatToggle {
            label: I18n.t("Показывать на рабочем столе", "Show on the desktop")
            hint: Updates.release ? "angelOS " + Updates.release.number + (Updates.release.codename ? " · " + Updates.release.codename : "") + I18n.t(" — мелко и прозрачно, в свободном углу", ": small and see-through, in a free corner") : ""
            checked: Config.wallpaper.releaseMark
            onToggled: c => Config.wallpaper.releaseMark = c
        }
        CatChoice {
            present: Config.wallpaper.releaseMark
            label: I18n.t("Где", "Where")
            hint: I18n.t("«Само» — угол, который не заняли виджеты", "Auto: a corner no widget covers")
            model: [["auto", "Само", "Auto"], ["top-left", "↖", "↖"], ["top-right", "↗", "↗"], ["bottom-left", "↙", "↙"], ["bottom-right", "↘", "↘"]].map(c => ({
                        "label": I18n.t(c[1], c[2]),
                        "value": c[0]
                    }))
            currentValue: Config.wallpaper.releaseMarkCorner
            onActivated: v => Config.wallpaper.releaseMarkCorner = v
        }
        CatSlider {
            present: Config.wallpaper.releaseMark
            label: I18n.t("Прозрачность", "Opacity")
            from: 10
            to: 80
            stepSize: 5
            value: Config.wallpaper.releaseMarkOpacity
            suffix: " %"
            onMoved: v => Config.wallpaper.releaseMarkOpacity = v
        }
    }
    // layered scenes (widgets/SceneWall): what stands behind their nearer layers
    CatGroup {
        id: sceneGroup
        name: "scene-depth"
        title: I18n.t("Надпись в сцене", "The text in the scene")
        icon: "image"
        // the scene on this screen: the picks below are its own (its release's)
        readonly property string here: Wallpapers.sceneOf(Wallpapers.resolve(page.output, page.wsIdx))
        function value(key) {
            return Wallpapers.own(here, key);
        }
        function pick(key, v) {
            Wallpapers.setOwn(here, key, v);
        }
        present: here !== ""
        CatNote {
            dim: true
            text: I18n.t("Только для этих обоев: " + Wallpapers.wallName(sceneGroup.here) + ". У других обоев свои.", "For this wallpaper only: " + Wallpapers.wallName(sceneGroup.here) + ". Other wallpapers keep their own.")
        }
        CatChoice {
            label: I18n.t("За листвой", "Behind the leaves")
            hint: I18n.t("Крупно в глубине сцены: ближние дома и листва закрывают надпись", "Big, deep in the scene: the nearer houses and leaves stand in front of it")
            model: [["clock", "Часы", "Clock"], ["release", "Релиз", "Release"], ["", "Ничего", "Nothing"]].map(c => ({
                        "label": I18n.t(c[1], c[2]),
                        "value": c[0]
                    }))
            currentValue: sceneGroup.value("sceneDepth")
            onActivated: v => sceneGroup.pick("sceneDepth", v)
        }
        CatChoice {
            present: sceneGroup.value("sceneDepth") !== ""
            label: I18n.t("Стиль", "Look")
            hint: I18n.t("Цвета сами — из палитры сцены, акцента темы и того, что за надписью", "The colours pick themselves: the scene's palette, the theme's accent and what is behind the text")
            model: [["neon", "Неон", "Neon"], ["outline", "Наклейка", "Sticker"], ["chrome", "Хром", "Chrome"], ["cutout", "Вызов", "Calling card"], ["lcd", "Нокиа", "Nokia"], ["aqua", "Пузырь", "Aqua"]].map(c => ({
                        "label": I18n.t(c[1], c[2]),
                        "value": c[0]
                    }))
            currentValue: sceneGroup.value("sceneDepthStyle")
            onActivated: v => sceneGroup.pick("sceneDepthStyle", v)
        }
        CatToggle {
            present: sceneGroup.value("sceneDepth") !== ""
            label: I18n.t("Текстура", "Texture")
            hint: I18n.t("У каждого стиля своя: сцена в хроме, печать на плашках вызова, блик наклейки, сетка экрана Нокиа, блик пузыря", "Each look has its own: the scene in the chrome, the print on the calling card, the sticker's gloss, the Nokia screen's grid, the bubble's gloss")
            checked: sceneGroup.value("sceneDepthTexture")
            onToggled: c => sceneGroup.pick("sceneDepthTexture", c)
        }
    }
    // windows behind a layered scene's nearer things (services/SceneBehind; angel-niri only)
    CatGroup {
        id: behindGroup
        name: "scene-behind"
        title: I18n.t("Окна за сценой", "Windows behind the scene")
        icon: "image"
        // the apps of the windows open now that are not in the list
        readonly property var candidates: {
            const seen = {};
            return Niri.windows.filter(w => {
                const id = w.app_id || "";
                if (!id || id === "org.quickshell" || SceneBehind.entryFor(id) || seen[id])
                    return false;
                seen[id] = true;
                return true;
            }).map(w => w.app_id);
        }
        present: SceneBehind.on
        CatNote {
            dim: true
            text: I18n.t("Плавающие окна этих программ стоят в сцене: ближние предметы их закрывают. Наведи мышь — выйдут вперёд.", "These apps' floating windows sit in the scene behind near objects. Hover one to bring it forward.")
        }
        CatRepeat {
            model: SceneBehind.apps
            delegate: Component {
                CatCustom {
                    id: behindApp
                    required property var modelData
                    label: AppMenu.prettyName(modelData.id)
                    hint: modelData.id
                    CatBox {
                        Flow {
                            id: behindFlow
                            width: parent.width
                            spacing: Theme.u * 3
                            Row {
                                spacing: Theme.u * 3
                                AppIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    appId: behindApp.modelData.id
                                    size: Theme.u * 8
                                }
                                // a click steps to the next depth, as a widget's menu → Depth does
                                PxButton {
                                    compact: true
                                    icon: "image"
                                    // beside the icon, at most the row: a long depth elides
                                    maxWidth: behindFlow.width - Theme.u * 11
                                    text: SceneBehind.depthLabel(behindApp.modelData.id)
                                    onClicked: SceneBehind.setDepth(behindApp.modelData.id, SceneBehind.nextDepth(behindApp.modelData.id))
                                }
                            }
                            PxButton {
                                compact: true
                                icon: "trash"
                                text: I18n.t("Убрать", "Remove")
                                onClicked: SceneBehind.remove(behindApp.modelData.id)
                            }
                        }
                    }
                }
            }
        }
        CatCustom {
            present: behindGroup.candidates.length > 0
            label: I18n.t("Открыто сейчас", "Open right now")
            hint: I18n.t("нажми на программу, чтобы её окна стояли в сцене", "Pick an app to stand its windows in the scene")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: behindGroup.candidates
                        PxButton {
                            required property string modelData
                            compact: true
                            icon: "plus"
                            text: AppMenu.prettyName(modelData)
                            onClicked: SceneBehind.add(modelData)
                        }
                    }
                }
            }
        }
        CatCustom {
            label: I18n.t("Другая программа", "Another app")
            hint: I18n.t("если её нет среди открытых: имя программы, как его знает система", "If it isn't open: the app's name as the system knows it")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 3
                    PxField {
                        id: behindId
                        width: Math.min(Theme.u * 60, parent.width)
                        placeholder: "spotify"
                        kind: "mono"
                        input.onAccepted: behindAdd.clicked()
                    }
                    PxButton {
                        id: behindAdd
                        compact: true
                        icon: "plus"
                        text: I18n.t("Добавить", "Add")
                        onClicked: {
                            SceneBehind.add(behindId.text);
                            behindId.text = "";
                        }
                    }
                }
            }
        }
    }
}
