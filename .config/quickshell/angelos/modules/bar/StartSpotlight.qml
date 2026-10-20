pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Spotlight / Raycast Start: one big search pill in the upper third of the screen and
// the results under it in sections — the calculator, apps, settings, folders, actions.
// Empty: the pinned apps and the actions. ↑↓ choose, Enter opens, right click a menu, middle pins,
// Esc clears / closes. StartOverlay centres it.
Item {
    id: root

    signal closeRequested
    // a right click on an app (StartApps.menuFor): StartOverlay opens the menu at x, y in `item`
    signal menuAsked(var items, Item item, real x, real y)
    property int current: 0
    property string query: ""
    readonly property bool searching: query.trim() !== ""
    // Settings → Bar → Start → Fine-tune (services/StartPrefs)
    readonly property var prefs: StartPrefs.of("spotlight")
    readonly property color accentColor: prefs.accentColor
    readonly property real sizeFactor: prefs.size
    property real room: 0                       // StartOverlay: the screen's room for it
    // every length is n units in whole pixels (StartPrefs.px): Fine-tune → Scale and Width keep
    // every edge on a pixel; `iu` the art pixel of icons, a whole number
    function px(n) {
        return StartPrefs.px(prefs, n);
    }
    readonly property int iu: prefs.iu
    readonly property int gap: px(4)                // between the pill and the results
    readonly property int rowH: px(22)
    readonly property int headH: px(11)             // a section's name over its first row
    readonly property int rowPad: px(5)             // a row's sides: the icon box in, the text after it
    readonly property int line: Math.max(1, Math.floor(iu / 2))
    // nine results, or what the screen has room for
    readonly property int maxRows: room > 0 ? Math.max(3, Math.min(9, Math.floor((room - pill.height - footer.height - headH * 2 - px(12)) / rowH))) : 9

    function matches(label, q) {
        return String(label).toLowerCase().indexOf(q) >= 0;
    }
    function plain(list, section) {
        return list.map(r => ({
                    "section": section,
                    "label": r.label,
                    "sub": "",
                    "icon": r.icon,
                    "run": r.run
                }));
    }
    function appRow(a, section) {
        return {
            "section": section,
            "label": a.name,
            "sub": a.genericName || a.comment || "",
            "app": a,
            "run": () => StartApps.launch(a)
        };
    }
    // Start's buttons as actions, without the ones Spotlight shows anyway (All settings and
    // Update among the actions, Home among the folders)
    readonly property var buttonRows: StartItems.rowsFor(["settings", "updates", "home"])
    readonly property var actions: plain((prefs.power ? buttonRows : []).concat(StartItems.settings.slice(0, 3)), I18n.t("Действия", "Actions"))
    readonly property var rows: {
        if (!searching)
            return (prefs.pinned ? StartApps.pinned.slice(0, 6).map(a => appRow(a, I18n.t("Закреплённые", "Pinned"))) : []).concat(actions.slice(0, 3));
        const q = query.trim().toLowerCase();
        const out = [];
        for (const r of StartApps.searchAll(query, 24)) {
            if (r.kind === "calc")
                out.push({
                    "section": I18n.t("Калькулятор", "Calculator"),
                    "label": r.calc.title,
                    "sub": r.calc.subtitle || I18n.t("Enter — скопировать", "Enter copies"),
                    "icon": "calc",
                    "run": () => Calc.copy(r.calc)
                });
            else if (r.kind === "app")
                out.push(appRow(r.app, I18n.t("Приложения", "Apps")));
            else if (r.kind === "file")
                out.push({
                    "section": I18n.t("Файлы", "Files"),
                    "label": r.file.name,
                    "sub": FileSearch.where(r.file),
                    "icon": FileSearch.pixelIcon(r.file),
                    "file": r.file,
                    "run": () => FileSearch.open(r.file)
                });
            else
                out.push({
                    "section": I18n.t("Настройки", "Settings"),
                    "label": r.doc.title,
                    "sub": r.doc.crumb || r.doc.hint || "",
                    "icon": r.doc.icon || "gear",
                    "run": () => StartApps.openSetting(r.doc)
                });
        }
        for (const p of plain(StartItems.places, I18n.t("Папки", "Folders")))
            if (matches(p.label, q))
                out.push(p);
        for (const a of plain(buttonRows, I18n.t("Действия", "Actions")))
            if (matches(a.label, q))
                out.push(a);
        // grouped by section, in the order they first show up (the best one leads)
        const order = [];
        for (const r of out)
            if (!order.includes(r.section))
                order.push(r.section);
        return order.reduce((acc, s) => acc.concat(out.filter(r => r.section === s)), []).slice(0, 30);
    }

    function setQuery(t) {
        field.text = t;
        query = t;
        current = 0;
    }
    function reset() {
        query = "";
        field.text = "";
        current = 0;
        Qt.callLater(() => field.focusField());
    }
    function runRow(r) {
        if (!r)
            return;
        closeRequested();
        Qt.callLater(r.run);
    }
    function move(d) {
        current = Math.max(0, Math.min(rows.length - 1, current + d));
        list.positionViewAtIndex(current, ListView.Contain);
    }
    function key(e) {
        if (nav(e))
            return;
        if (e.text && e.text.trim() !== "" && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            field.text += e.text;
            query = field.text;
            current = 0;
            field.focusField();
            e.accepted = true;
        }
    }
    function nav(e) {
        if (e.key === Qt.Key_Escape || e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R) {
            if (searching && e.key === Qt.Key_Escape)
                setQuery("");
            else
                closeRequested();
        } else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier)))
            move(1);
        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab)
            move(-1);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
            runRow(rows[current]);
        else
            return false;
        e.accepted = true;
        return true;
    }

    width: Math.round(Math.min(px(300), Math.round(760 * prefs.zoom)) * sizeFactor)
    height: pill.height + (rows.length ? gap + results.height : 0) + Math.ceil(footer.implicitHeight) + px(2)

    // the search pill
    Rectangle {
        id: pill
        width: parent.width
        height: root.px(30)
        radius: height / 2
        color: Qt.alpha(Theme.panel, root.prefs.opacity > 0 ? root.prefs.alpha : Math.max(0.88, Theme.panelAlpha))
        border.width: root.line
        border.color: Qt.alpha(root.accentColor, 0.6)
        PxIcon {
            id: lens
            x: root.px(10)
            y: Math.floor((parent.height - height) / 2)
            name: "search"
            pixel: Math.max(1, Math.round(root.iu * 1.5))
            fill: root.accentColor
        }
        PxField {
            id: field
            keepFocus: true
            x: lens.x + lens.width + root.px(4)
            y: Math.floor((parent.height - height) / 2)
            width: (pillUser.visible ? pillUser.x : parent.width) - root.px(12) - x
            height: Math.ceil(implicitHeight)
            kind: "title"
            placeholder: I18n.t("Что найти? Приложение, настройку, файл, .jpeg, 2+2…", "Find anything: an app, a setting, a file, .jpeg, 2+2…")
            onEdited: {
                root.query = text;
                root.current = 0;
            }
            onAccepted: root.runRow(root.rows[root.current])
            onKeyPressed: e => root.nav(e)
        }
        // the user at the pill's end (Fine-tune → Sections → User): just the avatar
        StartUser {
            id: pillUser
            visible: root.prefs.user
            x: parent.width - root.px(8) - width
            y: Math.floor((parent.height - height) / 2)
            size: root.iu * 18
            showName: false
            frameColor: root.accentColor
            onOpened: root.closeRequested()
        }
    }

    // the results
    Rectangle {
        id: results
        visible: root.rows.length > 0
        y: pill.height + root.gap
        width: parent.width
        height: Math.min(root.rows.length, root.maxRows) * root.rowH + sectionsShown * root.headH + root.px(3) * 2
        readonly property int sectionsShown: {
            const seen = [];
            for (const r of root.rows.slice(0, root.maxRows))
                if (!seen.includes(r.section))
                    seen.push(r.section);
            return seen.length;
        }
        radius: root.px(10)
        color: Qt.alpha(Theme.panel, Math.max(0.9, Theme.panelAlpha))
        border.width: root.line
        border.color: Qt.alpha(Theme.edge, 0.5)
        clip: true
        Behavior on height {
            NumberAnimation {
                duration: Motion.ms(110)
                easing.type: Easing.OutCubic
            }
        }
        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: root.px(3)
            model: root.rows
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                // a section's name over its first row
                readonly property bool head: index === 0 || root.rows[index - 1].section !== modelData.section
                width: list.width
                height: row.height + (head ? root.headH : 0)
                PxText {
                    visible: cell.head
                    x: root.rowPad
                    y: root.px(2)
                    kind: "tiny"
                    font.bold: true
                    color: root.accentColor
                    text: cell.modelData.section
                }
                Rectangle {
                    id: row
                    readonly property var modelData: cell.modelData
                    readonly property int index: cell.index
                    readonly property bool sel: index === root.current
                    y: cell.head ? root.headH : 0
                    width: list.width
                    height: root.rowH
                    radius: root.px(6)
                    color: sel ? Qt.alpha(root.accentColor, Theme.dark ? 0.3 : 0.22) : rm.containsMouse ? Qt.alpha(root.accentColor, 0.1) : "transparent"
                    // a fixed icon box: the text starts at the same x on every row
                    StartGlyph {
                        id: glyph
                        x: root.rowPad
                        width: root.iu * 14
                        height: parent.height
                        iu: root.iu
                        app: row.modelData.app || null
                        file: row.modelData.file || null
                        icon: row.modelData.icon || ""
                        appSize: root.iu * Math.round(12 * root.prefs.icons)
                        thumbSize: root.iu * Math.round(14 * root.prefs.icons)
                    }
                    Column {
                        x: glyph.x + glyph.width + root.rowPad
                        width: hint.x - root.px(4) - x
                        anchors.verticalCenter: parent.verticalCenter
                        PxText {
                            width: parent.width
                            elide: Text.ElideRight
                            font.bold: row.sel
                            text: row.modelData.label
                        }
                        PxText {
                            visible: text !== ""
                            width: parent.width
                            elide: Text.ElideRight
                            kind: "tiny"
                            dim: true
                            text: row.modelData.sub || ""
                        }
                    }
                    PxText {
                        id: hint
                        x: parent.width - root.px(6) - Math.ceil(implicitWidth)
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "tiny"
                        dim: true
                        text: row.sel ? "↵" : ""
                    }
                    MouseArea {
                        id: rm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onEntered: root.current = row.index
                        onClicked: m => {
                            const r = row.modelData, mid = m.button === Qt.MiddleButton;
                            if (m.button === Qt.LeftButton || (!r.app && !r.file)) {
                                root.runRow(r);
                            } else if (r.app) {
                                if (mid)
                                    StartApps.togglePin(r.app);
                                else
                                    root.menuAsked(StartApps.menuFor(r.app, () => root.runRow(r)), rm, m.x, m.y);
                            } else {
                                const reveal = () => {
                                    root.closeRequested();
                                    FileSearch.reveal(r.file);
                                };
                                if (mid)
                                    reveal();
                                else
                                    root.menuAsked(StartApps.fileMenuFor(reveal, () => root.runRow(r)), rm, m.x, m.y);
                            }
                        }
                    }
                }
            }
        }
    }
    PxText {
        id: footer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        kind: "tiny"
        color: Qt.alpha("#ffffff", 0.85)
        style: Text.Outline
        styleColor: Qt.alpha("#000000", 0.45)
        text: I18n.t("↑↓ выбрать · Enter открыть · ПКМ меню · средняя закрепить (файл — показать в папке) · Esc закрыть", "↑↓ choose · Enter opens · right click: menu · middle pins (a file: show in folder) · Esc closes")
    }
}
