pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Right-click desktop menu, laid out like Windows 11: signed quick actions on top,
// then the entries with flyouts (Вид ▸ / Создать ▸ / Обои ▸ / Открыть ▸ / Показать больше ▸).
// What it holds and in which order: services/DeskMenu (Settings → Right-click menu).
// The "ring" look is RadialMenu: openAt() hands over to it, the flyouts' lists stay here.
PopupWindow {
    id: root

    required property var parentWindow
    property var radial: null               // RadialMenu of the same screen
    // the ring, the tiles and the pentagram live in RadialMenu; the list here, plain or Y2K
    readonly property bool ringStyle: DeskMenu.overlay && !!radial
    readonly property string skin: DeskMenu.style === "y2k" ? "y2k" : ""
    readonly property real k: ({
            "compact": 0.85,
            "large": 1.25
        })[Config.desktop.menuSize] || 1
    readonly property string screenName: parentWindow && parentWindow.screen ? parentWindow.screen.name : ""
    property real px: 0
    property real py: 0

    // An open menu is hidden and shown again on the next turn of the event loop:
    // shown in the same event, the new surface kept the old position and jumped
    // aside. Clicks while that is pending only move the target, so a fast double
    // right-click shows the menu once, where it was asked for last.
    property bool reopening: false
    // a desktop widget's own menu (openWidget): its uid; "" = the desktop's
    property string widgetUid: ""
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
    function show(x, y) {
        px = x;
        py = y;
        sub.visible = false;
        anchor.rect.x = x;
        anchor.rect.y = y;
        if (!visible && !reopening) {
            visible = true;
            return;
        }
        visible = false;
        if (reopening)
            return;
        reopening = true;
        Qt.callLater(() => {
            if (!reopening)
                return;
            reopening = false;
            anchor.updateAnchor();
            visible = true;
        });
    }
    function close() {
        reopening = false;
        sub.visible = false;
        visible = false;
        if (radial && radial.visible)
            radial.close();
    }
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
            "label": I18n.t("Скриншот области", "Region screenshot"),
            "icon": "image",
            "run": () => Capture.screenshot()
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

    anchor.window: parentWindow
    anchor.rect.width: 1
    anchor.rect.height: 1
    // the menu starts one pixel past the pointer, so a second right-click on the
    // same spot lands on the desktop (menu moves there) instead of its corner
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
    grabFocus: !Shell.demo
    color: "transparent"
    implicitWidth: frame.width + Theme.u * 3
    implicitHeight: frame.height + Theme.u * 3
    onVisibleChanged: {
        if (visible) {
            if (Config.desktop.menuAnim !== false)
                popAnim.restart();
            if (PopupManager.active && PopupManager.active !== root)
                PopupManager.close(PopupManager.active);
            PopupManager.active = root;
        } else if (PopupManager.active === root) {
            PopupManager.active = null;
        }
    }
    visible: false

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: frame
    }

    DesktopSubmenu {
        id: sub
        parentMenu: root
        onDone: root.close()
    }
    // hover opens flyouts after a short beat, like Windows
    Timer {
        id: hoverTimer
        property Item item: null
        property var list: []
        interval: 160
        onTriggered: if (item && item.hovered)
            sub.openFor(item, list)
    }
    // scripting: open a flyout by name ("view" | "new" | "wallpaper" | "open" | "more")
    property var subAnchors: ({})
    function openSub(name) {
        if (radial && radial.visible) {
            radial.openSub(name);
            return;
        }
        const it = subAnchors[name];
        if (it)
            sub.openFor(it, listFor(name));
    }
    function hoverSub(item, list) {
        if (sub.visible && sub.anchorItem === item)
            return;
        hoverTimer.item = item;
        hoverTimer.list = list;
        hoverTimer.restart();
    }

    PxBox {
        id: frame
        width: Math.max(Theme.u * 150 * root.k, quick.implicitWidth + Theme.u * 8, ...col.children.map(c => c.implicitWidth || 0)) + inset * 2
        // a little pop when it opens (Settings → Right-click menu → Animation)
        transformOrigin: Item.TopLeft
        scale: popAnim.running ? popAnim.v : 1
        NumberAnimation {
            id: popAnim
            property real v: 1
            target: popAnim
            property: "v"
            from: 0.92
            to: 1
            duration: Motion.ms(120)
            easing.type: Easing.OutCubic
        }
        height: col.implicitHeight + inset * 2
        color: root.skin === "y2k" ? "transparent" : Qt.alpha(Theme.menuSurface, Theme.panelAlpha)
        outline: root.skin !== "y2k"
        flat: root.skin === "y2k"
        shadow: Config.appearance.shadows && root.skin !== "y2k"
        focus: true
        Keys.onEscapePressed: root.close()
        // Y2K gloss: the chrome bubble instead of the bevelled box
        Y2kGloss {
            visible: root.skin === "y2k"
            anchors.fill: parent
            z: -1
        }

        Column {
            id: col
            width: parent.width - frame.inset * 2
            bottomPadding: root.skin === "y2k" ? Theme.u * 3 : 0

            // Y2K gloss: a little title in the chrome
            PxText {
                visible: root.skin === "y2k" && !root.widgetUid
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: Theme.u * 4
                kind: "tiny"
                font.bold: true
                color: Theme.text
                style: Text.Outline
                styleColor: Qt.alpha(Theme.accent, 0.6)
                text: "✧ angelOS ✧"
            }
            // quick actions (Windows 11 puts cut/copy/paste here; we put the everyday stuff), signed
            Row {
                id: quick
                visible: DeskMenu.quick.length > 0 && !root.widgetUid
                anchors.horizontalCenter: parent.horizontalCenter
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
                        PxBox {
                            anchors.fill: parent
                            visible: qm.containsMouse && root.skin !== "y2k"
                            sunken: qm.pressed
                            color: Theme.mix(Theme.face, Theme.accent, 0.18)
                        }
                        Rectangle {
                            anchors.fill: parent
                            visible: qm.containsMouse && root.skin === "y2k"
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
                                }
                            }
                            PxText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: qa.width - Theme.u * 2
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: qa.e ? (qa.e.short || qa.e.label) : ""
                                kind: "tiny"
                            }
                        }
                        MouseArea {
                            id: qm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: sub.visible = false
                            onClicked: {
                                const e = qa.e;
                                if (e && e.flyout)
                                    sub.openFor(qa, root.listFor(qa.modelData));
                                else
                                    root.run(() => DeskMenu.run(qa.modelData, root.screenName));
                            }
                        }
                    }
                }
            }
            PxMenuItem {
                visible: DeskMenu.quick.length > 0 && DeskMenu.items.length > 0 && !root.widgetUid
                height: visible ? implicitHeight : 0
                separator: true
                skin: root.skin
            }

            // ---- a widget's menu: its name, then its entries ----
            PxText {
                visible: !!root.widgetUid
                x: Theme.u * 4
                topPadding: Theme.u * 2
                bottomPadding: Theme.u
                width: col.width - Theme.u * 8
                elide: Text.ElideRight
                kind: "tiny"
                dim: true
                text: {
                    const w = DesktopWidgets.byUid(root.widgetUid);
                    const info = w ? DesktopWidgets.typeInfo(w.type) : null;
                    return info ? DesktopWidgets.titleOf(info) + " · " + info.label : "";
                }
            }
            Repeater {
                model: root.widgetList
                PxMenuItem {
                    id: wItem
                    required property var modelData
                    readonly property bool fly: !!modelData.flyout
                    separator: !!modelData.separator
                    skin: root.skin
                    text: modelData.label || ""
                    icon: Config.desktop.menuIcons !== false ? (modelData.icon || "") : ""
                    submenu: fly
                    checkable: !!modelData.checkable
                    checked: modelData.checked ? modelData.checked() : false
                    onHoveredChanged: {
                        if (!hovered)
                            return;
                        if (fly)
                            root.hoverSub(wItem, modelData.flyout);
                        else
                            sub.visible = false;
                    }
                    onTriggered: {
                        if (fly) {
                            sub.openFor(wItem, modelData.flyout);
                        } else if (modelData.keepOpen) {
                            modelData.run();
                        } else {
                            const fn = modelData.run;
                            root.run(fn);
                        }
                    }
                }
            }
            Repeater {
                model: root.widgetUid ? [] : DeskMenu.items
                PxMenuItem {
                    id: entryItem
                    required property string modelData
                    readonly property var e: DeskMenu.entry(modelData)
                    readonly property bool fly: !!(e && e.flyout)
                    visible: modelData !== "more" || root.moreItems.length > 0 || Plugins.menuComponents.length > 0
                    height: visible ? implicitHeight : 0
                    separator: modelData === "sep"
                    skin: root.skin
                    text: e ? e.label : ""
                    icon: Config.desktop.menuIcons !== false && e ? e.icon : ""
                    submenu: fly
                    Component.onCompleted: if (fly)
                        root.subAnchors[modelData] = entryItem
                    onHoveredChanged: {
                        if (!hovered)
                            return;
                        if (fly)
                            root.hoverSub(entryItem, root.listFor(modelData));
                        else
                            sub.visible = false;
                    }
                    onTriggered: {
                        if (fly)
                            sub.openFor(entryItem, root.listFor(modelData));
                        else
                            root.run(() => DeskMenu.run(modelData, root.screenName));
                    }
                }
            }
            Repeater {
                // QML menu components from plugins can't live in a flyout list; they stay inline
                model: root.widgetUid ? [] : Plugins.menuComponents
                Loader {
                    required property var modelData
                    width: col.width
                    Component.onCompleted: setSource(Plugins.url(modelData, modelData.menuComponent), {
                        "plugin": Plugins.context(modelData),
                        "menu": root
                    })
                }
            }
        }
    }

    RightClickGuard {}
}
