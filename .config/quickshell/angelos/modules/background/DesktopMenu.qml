pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Right-click desktop menu, laid out like Windows 11: signed quick actions on top,
// then the entries with flyouts (Вид ▸ / Создать ▸ / Обои ▸ / Открыть ▸ / Показать больше ▸).
// What it holds and in which order: services/DeskMenu (Settings → Right-click menu).
// The "ring" look is RadialMenu: openAt() hands over to it, the flyouts' lists stay here.
// The list itself is the shared pixel menu (widgets/PxMenu) in its look (services/MenuLook).
PxMenu {
    id: root

    property var radial: null               // RadialMenu of the same screen
    // the ring, the tiles and the pentagram live in RadialMenu; the list here, plain or Y2K
    readonly property bool ringStyle: DeskMenu.overlay && !!radial
    readonly property real k: ({
            "compact": 0.85,
            "large": 1.25
        })[Config.desktop.menuSize] || 1
    readonly property string screenName: parentWindow && parentWindow.screen ? parentWindow.screen.name : ""

    // a desktop widget's own menu (openWidget): its uid; "" = the desktop's
    property string widgetUid: ""
    readonly property bool own: widgetUid !== ""
    function openWidget(uid, x, y) {
        widgetUid = uid;
        widgetList = widgetItems(uid);
        show(x, y);
    }
    function openAt(x, y) {
        widgetUid = "";
        widgetList = [];
        Achievements.note("deskmenu.open", DeskMenu.style);
        if (ringStyle) {
            if (visible)
                close();
            radial.openAt(x, y);
            return;
        }
        show(x, y);
    }
    onDismissed: if (radial && radial.visible)
        radial.close()
    // a flyout's entries by name
    function listFor(name) {
        return ({
                "view": viewItems,
                "new": newItems,
                "wallpaper": wallpaperItems,
                "open": openItems,
                "more": moreItems
            })[name] || [];
    }
    function run(fn) {
        close();
        fn();
    }

    // the scene's things the widget can stand behind, where it is (SceneWall.layersAt), 8 at most
    function depthThings(uid) {
        const f = DesktopWidgets.faces[uid];
        const wall = f && f.depth ? f.sceneWall : null;
        const r = Qt.rect(f.x, f.y, f.width, f.height);
        // with how much of it the nearer layers would cover there
        return wall ? wall.layersAt(r).slice(0, 8).map(l => Object.assign({}, l, {
                    "covered": Math.round(wall.coverAt(r, l.z - 0.5) * 100)
                })) : [];
    }
    // ---- a widget's menu: its size, its frame, what it has of its own, settings, remove ----
    function widgetItems(uid) {
        const w = DesktopWidgets.byUid(uid);
        const info = w ? DesktopWidgets.typeInfo(w.type) : null;
        if (!info)
            return [];
        const cur = () => DesktopWidgets.byUid(uid) || {};
        const st = () => cur().settings || {};
        const out = [];
        const sizes = DesktopWidgets.sizesOf(info);
        if (sizes.length && !DesktopWidgets.macLook)
            out.push({
                "label": I18n.t("Размер", "Size"),
                "icon": "maximize",
                "flyout": sizes.map(z => ({
                            "label": ({
                                    "s": I18n.t("Маленький · S", "Small · S"),
                                    "m": I18n.t("Средний · M", "Medium · M"),
                                    "l": I18n.t("Большой · L", "Large · L")
                                })[z],
                            "checkable": true,
                            "checked": () => DesktopWidgets.sizeOf(cur()) === z,
                            "keepOpen": true,
                            "run": () => DesktopWidgets.setSize(uid, z)
                        }))
            });
        if (!DesktopWidgets.macLook)
            out.push({
                "label": I18n.t("Рамка", "Frame"),
                "icon": "window",
                "flyout": ["", "window", "plate", "none"].map(f => ({
                            "label": DesktopWidgets.frameLabel(f) + (f ? "" : " (" + DesktopWidgets.frameLabel(DesktopWidgets.frameDefault).toLowerCase() + ")"),
                            "checkable": true,
                            "checked": () => (DesktopWidgets.frameKinds.includes(cur().frame) ? cur().frame : "") === f,
                            "keepOpen": true,
                            "run": () => DesktopWidgets.setFrame(uid, f)
                        }))
            });
        // on a layered wallpaper: how deep it stands between the scene's layers
        const ws = Niri.activeWorkspace(root.screenName);
        if (Wallpapers.sceneOf(Wallpapers.resolve(root.screenName, ws ? ws.idx : 1)))
            out.push({
                "label": I18n.t("Глубина", "Depth"),
                "icon": "layers",
                "flyout": DesktopWidgets.depthKinds.map(d => ({
                            "label": DesktopWidgets.depthLabel(d),
                            "checkable": true,
                            "checked": () => DesktopWidgets.depthOf(cur()) === d,
                            "keepOpen": true,
                            "run": () => DesktopWidgets.setDepth(uid, d)
                        })).concat(depthThings(uid).map(l => ({
                            "label": I18n.t("За: ", "Behind: ") + (l.label_ru || l.id).toLowerCase() + I18n.t(" · закрыто ", " · covered ") + l.covered + " %",
                            "checkable": true,
                            "checked": () => DesktopWidgets.depthOf(cur()) === "behind:" + l.id,
                            "keepOpen": true,
                            "run": () => DesktopWidgets.setDepth(uid, "behind:" + l.id)
                        })))
            });
        const toggle = (key, label, icon, dflt) => ({
                "label": label,
                "icon": icon,
                "checkable": true,
                "checked": () => st()[key] === undefined ? dflt : !!st()[key],
                "keepOpen": true,
                "run": () => DesktopWidgets.setSetting(uid, key, !(st()[key] === undefined ? dflt : !!st()[key]))
            });
        if (w.type === "clock") {
            out.push(toggle("seconds", I18n.t("Секунды", "Seconds"), "clock", false));
            out.push(toggle("weather", I18n.t("Погода", "Weather"), "sun", true));
        } else if (w.type === "picture") {
            out.push({
                "label": I18n.t("Выбрать картинку…", "Choose a picture…"),
                "icon": "image",
                "run": () => {
                    DesktopWidgets.setSetting(uid, "mode", "file");
                    DesktopWidgets.pick(uid, "file", false);
                }
            });
            out.push({
                "label": I18n.t("Слайд-шоу из папки…", "Slideshow from a folder…"),
                "icon": "folder",
                "run": () => {
                    DesktopWidgets.setSetting(uid, "mode", "folder");
                    DesktopWidgets.pick(uid, "folder", true);
                }
            });
            if (st().mode === "folder" && st().folder)
                out.push({
                    "label": I18n.t("Следующая", "Next"),
                    "icon": "next",
                    "keepOpen": true,
                    "run": () => DesktopWidgets.request(uid, "next")
                });
        } else if (w.type === "note") {
            out.push({
                "label": I18n.t("Редактировать", "Edit"),
                "icon": "note",
                "run": () => DesktopWidgets.request(uid, "edit")
            });
            out.push({
                "label": I18n.t("Цвет", "Colour"),
                "icon": "palette",
                "flyout": [0, 1, 2, 3].map(i => ({
                            "label": [I18n.t("Розовый", "Pink"), I18n.t("Голубой", "Cyan"), I18n.t("Жёлтый", "Yellow"), I18n.t("Четвёртый акцент", "Fourth accent")][i],
                            "checkable": true,
                            "checked": () => (st().tint || 0) === i,
                            "keepOpen": true,
                            "run": () => DesktopWidgets.setSetting(uid, "tint", i)
                        }))
            });
        }
        out.push({
            "separator": true
        });
        out.push({
            "label": I18n.t("Настройки виджетов…", "Widget settings…"),
            "icon": "gear",
            "run": () => Shell.openSettings("widgets")
        });
        out.push({
            "label": I18n.t("Режим правки", "Edit mode"),
            "icon": "layers",
            "checkable": true,
            "checked": () => DesktopWidgets.editMode,
            "run": () => DesktopWidgets.toggleEdit(root.screenName)
        });
        out.push({
            "label": I18n.t("Убрать с рабочего стола", "Remove from the desktop"),
            "icon": "trash",
            "run": () => DesktopWidgets.remove(uid)
        });
        return out;
    }
    // built once as it opens: rebuilt on every change, it would take the open flyout's anchor away
    property var widgetList: []

    // ---- flyout contents ----
    // `checked` is a function: the open flyout keeps a copy of its list, and the
    // tick has to follow the setting while it is open (issue #5)
    readonly property var viewItems: DesktopWidgets.types.map(t => ({
                "label": t.label,
                "icon": t.icon,
                "checkable": true,
                "checked": () => DesktopWidgets.has(t.type, root.screenName),
                "keepOpen": true,
                "run": () => DesktopWidgets.toggle(t.type, root.screenName)
            })).concat([
            // not a widget, but looked for among them: the people of the Discord call over the
            // bar (modules/desktop/DiscordCrew), on this screen
            {
                "label": I18n.t("Человечки из звонка Discord", "Little people from the Discord call"),
                "icon": "headphones",
                "checkable": true,
                "checked": () => Config.discord.crew && (Config.discord.crewScreen || Shell.primaryName) === root.screenName,
                "keepOpen": true,
                "run": () => {
                    if (Config.discord.crew && (Config.discord.crewScreen || Shell.primaryName) === root.screenName) {
                        Config.discord.crew = false;
                    } else {
                        Config.discord.crewScreen = root.screenName === Shell.primaryName ? "" : root.screenName;
                        Config.discord.crew = true;
                    }
                }
            },
            {
                "separator": true
            },
            {
                "label": I18n.t("Редактировать виджеты", "Edit widgets"),
                "icon": "gear",
                "checkable": true,
                "checked": () => DesktopWidgets.editMode,
                "run": () => DesktopWidgets.toggleEdit(root.screenName)
            },
            {
                "label": I18n.t("Прилипать к сетке", "Snap to grid"),
                "checkable": true,
                "checked": () => Config.desktop.snap,
                "keepOpen": true,
                "run": () => Config.desktop.snap = !Config.desktop.snap
            }
        ])
    readonly property var newItems: [
        {
            "label": I18n.t("Текстовую заметку", "Text note"),
            "icon": "terminal",
            "run": () => DesktopActions.newText()
        },
        {
            "label": I18n.t("Скриншот", "Screenshot"),
            "icon": "image",
            "run": () => Capture.screenshot(root.screenName)
        },
        {
            "label": I18n.t("Запись области экрана", "Region recording"),
            "icon": "play",
            "enabled": true,
            "run": () => Capture.record()
        },
        {
            "label": I18n.t("Видео для DaVinci (mediafix)…", "Video for DaVinci (mediafix)…"),
            "icon": "music",
            "run": () => NautilusSetup.mediafix([])
        }
    ]
    readonly property int wsIdx: {
        const ws = Niri.activeWorkspace(screenName);
        return ws ? ws.idx : 1;
    }
    readonly property var wallpaperItems: [
        {
            "label": I18n.t("Следующие обои", "Next wallpaper"),
            "icon": "arrowRight",
            "keepOpen": true,
            "run": () => Wallpapers.next(root.screenName, root.wsIdx, 1)
        },
        {
            "label": I18n.t("Предыдущие обои", "Previous wallpaper"),
            "icon": "arrowLeft",
            "keepOpen": true,
            "run": () => Wallpapers.next(root.screenName, root.wsIdx, -1)
        },
        {
            "label": I18n.t("Случайные", "Random"),
            "icon": "sparkle",
            "keepOpen": true,
            "run": () => Wallpapers.shuffle(root.screenName, root.wsIdx)
        },
        {
            "label": I18n.t("Случайные на всех экранах", "Random everywhere"),
            "icon": "monitor",
            "run": () => Wallpapers.random("")
        },
        {
            "separator": true
        },
        {
            "label": I18n.t("Выбрать обои…", "Choose wallpaper…"),
            "icon": "image",
            "run": () => Shell.openSettings("wallpaper")
        },
        {
            "label": I18n.t("Открыть папку с обоями", "Open the wallpaper folder"),
            "icon": "folder",
            "run": () => Shell.openPath(Wallpapers.dir)
        },
        {
            "label": I18n.t("Обновить список", "Rescan pictures"),
            "icon": "refresh",
            "hint": Wallpapers.heads.length ? String(Wallpapers.heads.length) : "",
            "run": () => {
                Wallpapers.scan();
                Plugins.reload();
            }
        }
    ]
    readonly property var openItems: [
        {
            "key": "HOME",
            "label": I18n.t("Домашняя папка", "Home")
        },
        {
            "key": "DESKTOP",
            "label": I18n.t("Рабочий стол", "Desktop")
        },
        {
            "key": "DOWNLOAD",
            "label": I18n.t("Загрузки", "Downloads")
        },
        {
            "key": "DOCUMENTS",
            "label": I18n.t("Документы", "Documents")
        },
        {
            "key": "PICTURES",
            "label": I18n.t("Изображения", "Pictures")
        },
        {
            "key": "MUSIC",
            "label": I18n.t("Музыка", "Music")
        },
        {
            "key": "VIDEOS",
            "label": I18n.t("Видео", "Videos")
        }
    ].map(d => ({
                "label": d.label,
                "icon": "folder",
                "run": () => DesktopActions.openDirectory(d.key)
            }))
    readonly property var moreItems: Plugins.menuEntries.map(e => ({
                "label": I18n.label(e.label || "?"),
                "icon": e.icon || "heart",
                "hint": e.hint || "",
                "separator": !!e.separator,
                "run": () => Plugins.run(e)
            }))

    // the desktop's own entries (DeskMenu.items) in the menu's schema; flyouts are built as
    // they open (listFor), "more" only when there is more
    readonly property var deskItems: DeskMenu.items.filter(id => id !== "more" || moreItems.length > 0 || Plugins.menuComponents.length > 0).map(id => {
        if (id === "sep")
            return {
                "separator": true
            };
        const e = DeskMenu.entry(id);
        return e.flyout ? {
            "id": id,
            "label": e.label,
            "icon": e.icon,
            "children": () => root.listFor(id)
        } : {
            "id": id,
            "label": e.label,
            "icon": e.icon,
            "run": () => DeskMenu.run(id, root.screenName)
        };
    })
    // scripting: open a flyout by name ("view" | "new" | "wallpaper" | "open" | "more")
    function openSub(name) {
        if (radial && radial.visible) {
            radial.openSub(name);
            return;
        }
        const i = items.findIndex(e => e.id === name);
        if (i >= 0)
            openChild(i);
    }

    kind: own ? "widget" : "desktop"
    items: own ? widgetList : deskItems
    title: {
        if (own) {
            const w = DesktopWidgets.byUid(root.widgetUid);
            const info = w ? DesktopWidgets.typeInfo(w.type) : null;
            return info ? DesktopWidgets.titleOf(info) + " · " + info.label : "";
        }
        // the 2004 looks carry a title bar; the classic list and the gloss have their quick row
        return look === "save" || look === "sticker" ? I18n.t("Рабочий стол", "Desktop") : "";
    }
    icons: Config.desktop.menuIcons !== false
    pop: Config.desktop.menuAnim !== false
    minWidth: Math.max(Math.round(MenuLook.minWidth * k), own ? 0 : quick.implicitWidth + Theme.u * 8)

    header: [
        // Y2K gloss: a little title in the chrome
        PxText {
            visible: root.look === "y2k" && !root.own
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            topPadding: Theme.u * 4
            kind: "tiny"
            font.bold: true
            color: Theme.text
            style: Text.Outline
            styleColor: Qt.alpha(Theme.accent, 0.6)
            text: "✧ angelOS ✧"
        },
        // quick actions (Windows 11 puts cut/copy/paste here; we put the everyday stuff), signed
        Row {
            id: quick
            readonly property var t: MenuLook.tokens(root.look)
            visible: DeskMenu.quick.length > 0 && !root.own
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            topPadding: Theme.u * 2
            bottomPadding: Theme.u * 2
            spacing: Theme.u
            Repeater {
                model: DeskMenu.quick
                Item {
                    id: qa
                    required property string modelData
                    readonly property var e: DeskMenu.entry(modelData)
                    width: Math.round(Theme.u * 30 * root.k)
                    height: qaCol.implicitHeight + Theme.u * 4
                    // the hover in the menu's look: a raised tile (classic), the gloss's bubble,
                    // a flat tile in the row highlight's colour (save, sticker)
                    PxBox {
                        anchors.fill: parent
                        visible: qm.containsMouse && root.look !== "y2k" && quick.t.tileBevel
                        sunken: qm.pressed
                        hell: quick.t.hellBox
                        color: quick.t.tileBg
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: qm.containsMouse && root.look !== "y2k" && !quick.t.tileBevel
                        color: quick.t.tileBg
                        border.width: Theme.u
                        border.color: quick.t.tileEdge
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: qm.containsMouse && root.look === "y2k"
                        radius: Theme.u * 5
                        color: Qt.alpha(Theme.accent, qm.pressed ? 0.45 : 0.3)
                        border.width: Math.max(1, Theme.u / 2)
                        border.color: Qt.alpha("#ffffff", 0.55)
                    }
                    Column {
                        id: qaCol
                        anchors.centerIn: parent
                        spacing: Theme.u
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Theme.u * 12 * root.k
                            height: width
                            PxIcon {
                                anchors.centerIn: parent
                                name: qa.e ? qa.e.icon : "heart"
                                pixel: root.k > 1.1 ? Theme.u * 2 : Theme.u
                                ink: qm.containsMouse && !quick.t.tileBevel ? quick.t.litInk : quick.t.ink
                            }
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: qa.width - Theme.u * 2
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: qa.e ? (qa.e.short || qa.e.label) : ""
                            kind: "tiny"
                            color: qm.containsMouse && !quick.t.tileBevel ? quick.t.litText : quick.t.text
                            style: quick.t.outlineText !== "transparent" ? Text.Outline : Text.Normal
                            styleColor: quick.t.outlineText
                        }
                    }
                    MouseArea {
                        id: qm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.collapse(1)
                        onClicked: {
                            const e = qa.e;
                            if (e && e.flyout)
                                root.cascade(0, qa, root.listFor(qa.modelData), false);
                            else
                                root.run(() => DeskMenu.run(qa.modelData, root.screenName));
                        }
                    }
                }
            }
        },
        PxMenuItem {
            visible: DeskMenu.quick.length > 0 && DeskMenu.items.length > 0 && !root.own
            separator: true
        }
    ]
    footer: [
        Repeater {
            // QML menu components from plugins can't live in a flyout list; they stay inline
            model: root.own ? [] : Plugins.menuComponents
            Loader {
                required property var modelData
                width: parent ? parent.width : 0
                Component.onCompleted: setSource(Plugins.url(modelData, modelData.menuComponent), {
                    "plugin": Plugins.context(modelData),
                    "menu": root
                })
            }
        }
    ]
}
