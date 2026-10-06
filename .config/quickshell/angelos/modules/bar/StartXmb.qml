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
    property real reveal: 1
    property int current: -1                // unused here (StartOverlay resets it)
    property string query: ""
    property int cat: 1                     // the selected category
    property var itemOf: ({})               // category id -> selected item
    readonly property bool searching: query.trim() !== ""
    // Settings → Bar → Start → Fine-tune (services/StartPrefs)
    readonly property var prefs: StartPrefs.of("xmb")
    readonly property color accentColor: prefs.accentColor

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
        } : r.kind === "setting" ? {
            "label": r.doc.title,
            "sub": I18n.t("Настройки", "Settings") + (r.doc.crumb ? " › " + r.doc.crumb : ""),
            "icon": r.doc.icon || "gear",
            "run": () => StartApps.openSetting(r.doc)
        } : {
            "label": r.calc.title,
            "sub": r.calc.subtitle || "",
            "icon": "calc",
            "run": () => Calc.copy(r.calc)
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
        x: Theme.u * 20
        y: Theme.u * 12
        opacity: root.reveal
        size: Theme.u * 16
        frameColor: root.accentColor
        textColor: "#ffffff"
        kind: "title"
        onOpened: root.closeRequested()
    }

    // ---- clock, top right (the PSP's corner) ----
    Column {
        visible: root.prefs.clock || root.searching
        anchors.right: parent.right
        anchors.rightMargin: Theme.u * 20
        y: Theme.u * 14
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
    readonly property real rowY: Math.round(height * 0.28)
    readonly property real step: Theme.u * 58
    readonly property real catX: Math.round(width * 0.24)
    readonly property real iconBox: Math.round(Theme.u * 30 * prefs.icons)
    Repeater {
        model: root.categories
        Item {
            id: catItem
            required property var modelData
            required property int index
            readonly property bool sel: index === root.cat
            x: root.catX + (index - root.cat) * root.step - width / 2
            y: root.rowY - root.iconBox / 2 - (1 - root.reveal) * Theme.u * 10
            width: root.iconBox
            height: root.iconBox + Theme.u * 14
            opacity: root.reveal * (sel ? 1 : Math.max(0.25, 0.8 - Math.abs(index - root.cat) * 0.12))
            Behavior on x {
                NumberAnimation {
                    duration: Motion.ms(180)
                    easing.type: Easing.OutCubic
                }
            }
            PxIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: catItem.modelData.icon
                pixel: catItem.sel ? Theme.u * 3 : Theme.u * 2
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
    readonly property real itemH: Math.round(Theme.u * 22 * Math.max(0.8, prefs.icons))
    readonly property real below: rowY + iconBox / 2 + Theme.u * 18
    Repeater {
        model: root.column.rows
        Item {
            id: it
            required property var modelData
            required property int index
            readonly property int off: index - root.item
            readonly property bool sel: off === 0
            visible: y > -height && y < root.height
            x: root.catX - root.iconBox / 2 - Theme.u * 2
            y: off >= 0 ? root.below + off * root.itemH + (off > 0 ? Theme.u * 10 : 0) : root.rowY - root.iconBox / 2 - Theme.u * 6 + off * root.itemH - root.itemH
            width: root.width - x - Theme.u * 20
            height: root.itemH
            opacity: root.reveal * (sel ? 1 : off < 0 ? 0.35 : Math.max(0.3, 0.85 - off * 0.08))
            Behavior on y {
                NumberAnimation {
                    duration: Motion.ms(150)
                    easing.type: Easing.OutCubic
                }
            }
            Item {
                id: glyph
                width: root.iconBox
                height: root.itemH
                AppIcon {
                    visible: !!it.modelData.app
                    anchors.centerIn: parent
                    iconName: it.modelData.app ? it.modelData.app.icon || "" : ""
                    appId: it.modelData.app ? it.modelData.app.id || "" : ""
                    size: Math.round((it.sel ? Theme.u * 18 : Theme.u * 12) * root.prefs.icons)
                }
                FileThumb {
                    id: fileGlyph
                    visible: ok
                    anchors.centerIn: parent
                    width: Math.round((it.sel ? Theme.u * 18 : Theme.u * 12) * root.prefs.icons)
                    height: width
                    hit: it.modelData.file || null
                }
                PxIcon {
                    visible: !it.modelData.app && !fileGlyph.ok
                    anchors.centerIn: parent
                    name: it.modelData.icon || "heart"
                    pixel: it.sel ? Theme.u * 2 : Math.max(1, Math.round(Theme.u * 1.5))
                    ink: "#ffffff"
                    fill: Theme.mix(root.accentColor, "#ffffff", 0.35)
                    light: "#ffffff"
                }
            }
            Column {
                anchors.left: glyph.right
                anchors.leftMargin: Theme.u * 6
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
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: m => {
                    if (m.button === Qt.RightButton && it.modelData.app)
                        StartApps.togglePin(it.modelData.app);
                    else
                        root.runRow(it.modelData);
                }
            }
        }
    }
    // nothing in this column (the search found nothing)
    PxText {
        visible: root.column.rows.length === 0
        x: root.catX - root.iconBox / 2
        y: root.below
        color: Qt.alpha("#ffffff", 0.7)
        text: I18n.t("Ничего не нашлось", "Nothing found")
    }
    // hints, bottom left
    PxText {
        x: Theme.u * 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.u * 12
        opacity: root.reveal * 0.7
        kind: "tiny"
        color: "#ffffff"
        text: I18n.t("←→ разделы · ↑↓ пункты · Enter открыть · печатай — поиск · ПКМ — закрепить · Esc", "←→ sections · ↑↓ items · Enter opens · type to search · right click pins · Esc")
    }
}
