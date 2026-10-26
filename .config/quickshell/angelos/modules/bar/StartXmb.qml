pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// PSP XMB Start: the whole screen, a drifting wave (shaders/xmb_wave.frag), the
// categories in a row and the chosen one's items in a column — the selected item
// right under the row, the ones before it above. ←/→ categories, ↑/↓ items, Enter
// runs, typing searches (a "Search" column comes first), Esc clears / closes.
// Mouse: click a category or an item, the wheel walks the column (Shift: categories).
Item {
    id: root

    signal closeRequested
    // a right click on an app (StartApps.menuFor): StartOverlay opens the menu at x, y in `item`
    signal menuAsked(var items, Item item, real x, real y)
    property real reveal: 1
    property int current: -1                // unused here (StartOverlay resets it)
    property string query: ""
    property int cat: 1                     // the selected category
    property var itemOf: ({})               // category id -> selected item
    readonly property bool searching: query.trim() !== ""
    // Settings → Bar → Start → Fine-tune (services/StartPrefs)
    readonly property var prefs: StartPrefs.of("xmb")
    readonly property color accentColor: prefs.accentColor
    // every length is n units in whole pixels (StartPrefs.px): Fine-tune → Scale keeps every edge
    // on a pixel; `iu` the art pixel of icons, a whole number
    function px(n) {
        return StartPrefs.px(prefs, n);
    }
    readonly property int iu: prefs.iu
    readonly property int pad: px(20)               // THE inset from the screen's sides
    readonly property int padY: px(12)              // … and from its top and bottom

    function appRow(a) {
        return {
            "label": a.name,
            "sub": a.genericName || a.comment || "",
            "app": a,
            "run": () => StartApps.launch(a)
        };
    }
    function plain(list) {
        return list.map(r => ({
                    "label": r.label,
                    "sub": "",
                    "icon": r.icon,
                    "run": r.run
                }));
    }
    readonly property var searchRows: searching ? StartApps.searchAll(query, 30).map(r => r.kind === "app" ? appRow(r.app) : r.kind === "file" ? {
            "label": r.file.name,
            "sub": FileSearch.where(r.file),
            "icon": FileSearch.pixelIcon(r.file),
            "file": r.file,
            "run": () => FileSearch.open(r.file)
        } : r.kind === "calc" ? {
            "label": r.calc.title,
            "sub": r.calc.subtitle || "",
            "icon": "calc",
            "run": () => Calc.copy(r.calc)
        } : {
            "label": r.title,
            "sub": r.sub,
            "icon": r.icon,
            "run": r.run
        }) : []
    readonly property var categories: {
        const all = [
            {
                "id": "settings",
                "label": I18n.t("Настройки", "Settings"),
                "icon": "gear",
                "rows": plain(StartItems.settings)
            },
            {
                "id": "pinned",
                "label": I18n.t("Закреплённые", "Pinned"),
                "icon": "heart",
                "rows": prefs.pinned ? StartApps.pinned.map(appRow) : []
            },
            {
                "id": "games",
                "label": I18n.t("Игры", "Games"),
                "icon": "gamepad",
                "rows": StartItems.appsIn("games").map(appRow)
            },
            {
                "id": "media",
                "label": I18n.t("Медиа", "Media"),
                "icon": "music",
                "rows": StartItems.appsIn("media").map(appRow)
            },
            {
                "id": "net",
                "label": I18n.t("Сеть", "Network"),
                "icon": "wifi",
                "rows": StartItems.appsIn("net").map(appRow)
            },
            {
                "id": "tools",
                "label": I18n.t("Инструменты", "Tools"),
                "icon": "terminal",
                "rows": StartItems.appsIn("tools").map(appRow)
            },
            {
                "id": "all",
                "label": I18n.t("Все приложения", "All apps"),
                "icon": "grid",
                "rows": StartPrefs.sorted("xmb", StartApps.apps).map(appRow)
            },
            {
                "id": "places",
                "label": I18n.t("Папки", "Folders"),
                "icon": "folder",
                "rows": plain(StartItems.places)
            },
            {
                "id": "power",
                "label": I18n.t("Питание", "Power"),
                "icon": "power",
                "rows": prefs.power ? plain(StartItems.power) : []
            }
        ].filter(c => c.rows.length > 0);
        return searching && prefs.search ? [
            {
                "id": "search",
                "label": I18n.t("Поиск", "Search"),
                "icon": "search",
                "rows": searchRows
            }
        ].concat(all) : all;
    }
    readonly property var column: categories[Math.max(0, Math.min(categories.length - 1, cat))] || {
        "id": "",
        "rows": []
    }
    readonly property int item: Math.max(0, Math.min(column.rows.length - 1, itemOf[column.id] || 0))

    function pick(c) {
        cat = Math.max(0, Math.min(categories.length - 1, c));
    }
    function walk(d) {
        const m = Object.assign({}, itemOf);
        m[column.id] = Math.max(0, Math.min(column.rows.length - 1, item + d));
        itemOf = m;
    }
    function runRow(r) {
        if (!r)
            return;
        closeRequested();
        Qt.callLater(r.run);
    }
    function setQuery(t) {
        query = t;
        cat = 0;
        itemOf = {};
    }
    function reset() {
        query = "";
        itemOf = {};
        const i = categories.findIndex(c => c.id === "pinned");
        cat = i >= 0 ? i : 0;
    }
    function key(e) {
        if (e.key === Qt.Key_Escape || e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R) {
            if (searching && e.key === Qt.Key_Escape)
                setQuery("");
            else
                closeRequested();
        } else if (e.key === Qt.Key_Left)
            pick(cat - 1);
        else if (e.key === Qt.Key_Right)
            pick(cat + 1);
        else if (e.key === Qt.Key_Up)
            walk(-1);
        else if (e.key === Qt.Key_Down)
            walk(1);
        else if (e.key === Qt.Key_PageUp)
            walk(-6);
        else if (e.key === Qt.Key_PageDown)
            walk(6);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
            runRow(column.rows[item]);
        else if (e.key === Qt.Key_Backspace) {
            if (searching)
                setQuery(query.slice(0, -1));
        } else if (prefs.search && e.text && e.text.trim() !== "" && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
            setQuery(query + e.text);
        else if (e.text === " " && searching)
            setQuery(query + " ");
        else
            return;
        e.accepted = true;
    }

    // ---- the wave ----
    ShaderEffect {
        id: wave
        anchors.fill: parent
        // Fine-tune → Opacity: the desktop through the wave
        opacity: root.reveal * (root.prefs.opacity > 0 ? root.prefs.opacity / 100 : 1)
        property real time: 0
        property real aspect: width / Math.max(1, height)
        property color skyTop: Theme.mix(Theme.dark ? "#08060c" : "#2a1630", root.accentColor, 0.18)
        property color skyBottom: Theme.mix(Theme.dark ? "#14081a" : "#3a1a40", Theme.accent2, 0.3)
        property color wave: Qt.rgba(1, 1, 1, 0.85)
        fragmentShader: Qt.resolvedUrl("../../shaders/xmb_wave.frag.qsb")
        FrameAnimation {
            running: root.visible && root.reveal > 0 && !Motion.still
            onTriggered: wave.time += frameTime
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
        onWheel: w => {
            if ((w.modifiers & Qt.ShiftModifier) || Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y))
                root.pick(root.cat + ((w.angleDelta.x || w.angleDelta.y) > 0 ? -1 : 1));
            else
                root.walk(w.angleDelta.y > 0 ? -1 : 1);
        }
    }

    // ---- the user, top left ----
    StartUser {
        visible: root.prefs.user
        x: root.pad
        y: root.padY
        opacity: root.reveal
        size: root.iu * 16
        frameColor: root.accentColor
        textColor: "#ffffff"
        kind: "title"
        onOpened: root.closeRequested()
    }

    // ---- clock, top right (the PSP's corner) ----
    Column {
        visible: root.prefs.clock || root.searching
        x: root.width - root.pad - Math.ceil(width)
        y: root.padY
        opacity: root.reveal
        PxText {
            visible: root.prefs.clock
            anchors.right: parent.right
            kind: "title"
            color: "#ffffff"
            text: now.date.toLocaleDateString(I18n.locale, "d.M") + "  " + I18n.time(now.date, false)
        }
        PxText {
            anchors.right: parent.right
            visible: root.searching
            kind: "tiny"
            color: Qt.alpha("#ffffff", 0.8)
            text: "⌕ " + root.query
        }
    }
    SystemClock {
        id: now
        precision: SystemClock.Minutes
    }

    // ---- the categories ----
    readonly property int rowY: Math.round(height * 0.28)
    readonly property int step: px(58)
    readonly property int catX: Math.round(width * 0.24)
    readonly property int iconBox: iu * Math.round(30 * prefs.icons)
    readonly property int half: Math.floor(iconBox / 2)
    Repeater {
        model: root.categories
        Item {
            id: catItem
            required property var modelData
            required property int index
            readonly property bool sel: index === root.cat
            x: root.catX + (index - root.cat) * root.step - root.half
            y: root.rowY - root.half - Math.round((1 - root.reveal) * root.px(10))
            width: root.iconBox
            height: root.iconBox + root.px(14)
            opacity: root.reveal * (sel ? 1 : Math.max(0.25, 0.8 - Math.abs(index - root.cat) * 0.12))
            Behavior on x {
                NumberAnimation {
                    duration: Motion.ms(180)
                    easing.type: Easing.OutCubic
                }
            }
            PxIcon {
                x: Math.floor((parent.width - width) / 2)
                name: catItem.modelData.icon
                pixel: catItem.sel ? root.iu * 3 : root.iu * 2
                ink: "#ffffff"
                fill: catItem.sel ? Theme.mix(root.accentColor, "#ffffff", 0.3) : Qt.alpha("#ffffff", 0.75)
                fill2: Theme.accent2
                light: "#ffffff"
                Behavior on pixel {
                    NumberAnimation {
                        duration: Motion.ms(120)
                    }
                }
            }
            PxText {
                visible: catItem.sel && root.prefs.labels
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                kind: "body"
                font.bold: true
                color: "#ffffff"
                style: Text.Outline
                styleColor: Qt.alpha("#000000", 0.3)
                text: catItem.modelData.label
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pick(catItem.index)
            }
        }
    }

    // ---- the chosen column: the selected item under the row, earlier ones above ----
    readonly property int itemH: px(22 * Math.max(0.8, prefs.icons))
    readonly property int below: rowY + half + px(18)
    Repeater {
        model: root.column.rows
        Item {
            id: it
            required property var modelData
            required property int index
            readonly property int off: index - root.item
            readonly property bool sel: off === 0
            visible: y > -height && y < root.height
            x: root.catX - root.half - root.px(2)
            y: off >= 0 ? root.below + off * root.itemH + (off > 0 ? root.px(10) : 0) : root.rowY - root.half - root.px(6) + off * root.itemH - root.itemH
            width: root.width - x - root.pad
            height: root.itemH
            opacity: root.reveal * (sel ? 1 : off < 0 ? 0.35 : Math.max(0.3, 0.85 - off * 0.08))
            Behavior on y {
                NumberAnimation {
                    duration: Motion.ms(150)
                    easing.type: Easing.OutCubic
                }
            }
            // a fixed icon box, as wide as a category's: the text starts at the same x on every row
            StartGlyph {
                id: glyph
                width: root.iconBox
                height: root.itemH
                iu: root.iu
                app: it.modelData.app || null
                file: it.modelData.file || null
                icon: it.modelData.icon || ""
                appSize: root.iu * Math.round((it.sel ? 18 : 12) * root.prefs.icons)
                thumbSize: appSize
                pixelIcon.pixel: it.sel ? root.iu * 2 : Math.max(1, Math.round(root.iu * 1.5))
                pixelIcon.ink: "#ffffff"
                pixelIcon.fill: Theme.mix(root.accentColor, "#ffffff", 0.35)
                pixelIcon.light: "#ffffff"
            }
            Column {
                anchors.left: glyph.right
                anchors.leftMargin: root.px(6)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                PxText {
                    width: parent.width
                    elide: Text.ElideRight
                    kind: it.sel ? "title" : "body"
                    color: "#ffffff"
                    style: it.sel ? Text.Outline : Text.Normal
                    styleColor: Qt.alpha(root.accentColor, 0.6)
                    text: it.modelData.label
                }
                PxText {
                    visible: it.sel && text !== "" && root.prefs.labels
                    width: parent.width
                    elide: Text.ElideRight
                    kind: "tiny"
                    color: Qt.alpha("#ffffff", 0.75)
                    text: it.modelData.sub || ""
                }
            }
            MouseArea {
                id: im
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: m => {
                    const r = it.modelData;
                    if (m.button === Qt.LeftButton || !r.app)
                        root.runRow(r);
                    else if (m.button === Qt.MiddleButton)
                        StartApps.togglePin(r.app);
                    else
                        root.menuAsked(StartApps.menuFor(r.app, () => root.runRow(r)), im, m.x, m.y);
                }
            }
        }
    }
    // nothing in this column (the search found nothing)
    PxText {
        visible: root.column.rows.length === 0
        x: root.catX - root.half
        y: root.below
        color: Qt.alpha("#ffffff", 0.7)
        text: I18n.t("Ничего не нашлось", "Nothing found")
    }
    // hints, bottom left
    PxText {
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.padY
        opacity: root.reveal * 0.7
        kind: "tiny"
        color: "#ffffff"
        text: I18n.t("←→ разделы · ↑↓ пункты · Enter открыть · печатай — поиск · ПКМ — меню · средняя — закрепить · Esc", "←→ sections · ↑↓ items · Enter opens · type to search · right click: menu · middle pins · Esc")
    }
}
