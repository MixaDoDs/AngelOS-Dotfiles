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
        for (const p of Wallpapers.list)
            set[p.slice(0, p.lastIndexOf("/"))] = true;
        return Object.keys(set).sort();
    }
    readonly property var filtered: folder ? Wallpapers.list.filter(p => p.slice(0, p.lastIndexOf("/")) === folder) : Wallpapers.list
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
            text: I18n.t("С каждым крупным релизом приходят свои обои, нарисованные для angelOS: днём и ночью. Клик — поставить.", "Every big release comes with wallpapers drawn for angelOS, a day and a night one. Click to apply.")
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
                                    model: [wallCol.modelData.day, wallCol.modelData.night].filter(f => !!f)
                                    Item {
                                        id: rt
                                        required property string modelData
                                        readonly property bool active: (page.target === "all" ? Wallpapers.resolve(Quickshell.screens[0].name, 1) : page.target === "output" ? Wallpapers.resolve(page.output, -1) : Wallpapers.resolve(page.output, page.wsIdx)) === modelData
                                        width: Theme.u * 56
                                        height: Theme.u * 32
                                        PxBox {
                                            anchors.fill: parent
                                            sunken: true
                                            color: Theme.sunken
                                            edgeColor: rt.active ? Theme.accent : Theme.edge
                                            Image {
                                                anchors.fill: parent
                                                source: "file://" + rt.modelData
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
                    readonly property string currentHere: page.target === "all" ? Wallpapers.resolve(Quickshell.screens[0].name, 1) : page.target === "output" ? Wallpapers.resolve(page.output, -1) : Wallpapers.resolve(page.output, page.wsIdx)
                    readonly property bool active: currentHere === modelData
                    width: grid.cell
                    height: Math.round(grid.cell * 9 / 16)

                    PxBox {
                        anchors.fill: parent
                        sunken: true
                        color: Theme.sunken
                        edgeColor: thumb.active ? Theme.accent : Theme.edge
                        Image {
                            anchors.fill: parent
                            source: "file://" + Wallpapers.display(thumb.modelData)
                            // in the grimoire (or a dress): an engraving the right way round, not a negative
                            layer.enabled: Theme.inkWindows.length > 0 && Theme.inkWindows.includes(Window.window)
                            layer.effect: GrimoirePhoto {}
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            onStatusChanged: if (status === Image.Error)
                                Wallpapers.fit(thumb.modelData)
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
