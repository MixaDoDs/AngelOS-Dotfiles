pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Spotlight / Raycast Start: one big search pill in the upper third of the screen and
// the results under it in sections — the calculator, apps, settings, folders, actions.
// Empty: the pinned apps and the actions. ↑↓ choose, Enter opens, right click pins,
// Esc clears / closes. StartOverlay centres it.
Item {
    id: root

    signal closeRequested
    property int current: 0
    property string query: ""
    readonly property bool searching: query.trim() !== ""
    // Settings → Bar → Start → Fine-tune (services/StartPrefs)
    readonly property var prefs: StartPrefs.of("spotlight")
    readonly property color accentColor: prefs.accentColor
    readonly property real sizeFactor: prefs.size
    property real room: 0                       // StartOverlay: the screen's room for it
    // nine results, or what the screen has room for
    readonly property int maxRows: room > 0 ? Math.max(3, Math.min(9, Math.floor((room - pill.height - footer.height - Theme.fit(11) * 2 - Theme.u * 12) / Theme.fit(22)))) : 9

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
    readonly property var actions: plain((prefs.power ? StartItems.power : []).concat(StartItems.settings.slice(0, 3)), I18n.t("Действия", "Actions"))
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
        for (const a of plain(StartItems.power, I18n.t("Действия", "Actions")))
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

    width: Math.round(Math.min(Theme.u * 300, 760) * sizeFactor)
    height: pill.height + (rows.length ? Theme.u * 4 + results.height : 0) + footer.height + Theme.u * 2

    // the search pill
    Rectangle {
        id: pill
        width: parent.width
        height: Theme.fit(30)
        radius: height / 2
        color: Qt.alpha(Theme.panel, root.prefs.opacity > 0 ? root.prefs.alpha : Math.max(0.88, Theme.panelAlpha))
        border.width: Math.max(1, Theme.u / 2)
        border.color: Qt.alpha(root.accentColor, 0.6)
        PxIcon {
            id: lens
            x: Theme.u * 10
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            pixel: Math.max(1, Math.round(Theme.u * 1.5))
            fill: root.accentColor
        }
        PxField {
            id: field
            keepFocus: true
            anchors.left: lens.right
            anchors.leftMargin: Theme.u * 4
            anchors.right: pillUser.visible ? pillUser.left : parent.right
            anchors.rightMargin: Theme.u * 12
            anchors.verticalCenter: parent.verticalCenter
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
            anchors.right: parent.right
            anchors.rightMargin: Theme.u * 8
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.u * 18
            showName: false
            frameColor: root.accentColor
            onOpened: root.closeRequested()
        }
    }

    // the results
    Rectangle {
        id: results
        visible: root.rows.length > 0
        y: pill.height + Theme.u * 4
        width: parent.width
        height: Math.min(root.rows.length, root.maxRows) * Theme.fit(22) + sectionsShown * Theme.fit(11) + Theme.u * 6
        readonly property int sectionsShown: {
            const seen = [];
            for (const r of root.rows.slice(0, root.maxRows))
                if (!seen.includes(r.section))
                    seen.push(r.section);
            return seen.length;
        }
        radius: Theme.u * 10
        color: Qt.alpha(Theme.panel, Math.max(0.9, Theme.panelAlpha))
        border.width: Math.max(1, Theme.u / 2)
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
            anchors.margins: Theme.u * 3
            model: root.rows
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                // a section's name over its first row
                readonly property bool head: index === 0 || root.rows[index - 1].section !== modelData.section
                width: list.width
                height: row.height + (head ? Theme.fit(11) : 0)
                PxText {
                    visible: cell.head
                    x: Theme.u * 6
                    y: Theme.u * 2
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
                    y: cell.head ? Theme.fit(11) : 0
                    width: list.width
                    height: Theme.fit(22)
                    radius: Theme.u * 6
                    color: sel ? Qt.alpha(root.accentColor, Theme.dark ? 0.3 : 0.22) : rm.containsMouse ? Qt.alpha(root.accentColor, 0.1) : "transparent"
                    Item {
                        id: glyph
                        x: Theme.u * 5
                        width: Theme.u * 14
                        height: parent.height
                        AppIcon {
                            visible: !!row.modelData.app
                            anchors.centerIn: parent
                            iconName: row.modelData.app ? row.modelData.app.icon || "" : ""
                            appId: row.modelData.app ? row.modelData.app.id || "" : ""
                            size: Math.round(Theme.u * 12 * root.prefs.icons)
                        }
                        FileThumb {
                            id: thumb
                            visible: ok
                            anchors.centerIn: parent
                            width: Math.round(Theme.u * 14 * root.prefs.icons)
                            height: width
                            hit: row.modelData.file || null
                        }
                        PxIcon {
                            visible: !row.modelData.app && !thumb.ok
                            anchors.centerIn: parent
                            name: row.modelData.icon || "heart"
                        }
                    }
                    Column {
                        anchors.left: glyph.right
                        anchors.leftMargin: Theme.u * 5
                        anchors.right: hint.left
                        anchors.rightMargin: Theme.u * 4
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
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.u * 6
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
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: root.current = row.index
                        onClicked: m => {
                            if (m.button === Qt.RightButton && row.modelData.app)
                                StartApps.togglePin(row.modelData.app);
                            else if (m.button === Qt.RightButton && row.modelData.file) {
                                root.closeRequested();
                                FileSearch.reveal(row.modelData.file);
                            } else
                                root.runRow(row.modelData);
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
        text: I18n.t("↑↓ выбрать · Enter открыть · ПКМ закрепить (файл — показать в папке) · Esc закрыть", "↑↓ choose · Enter opens · right click pins (a file: show in folder) · Esc closes")
    }
}
