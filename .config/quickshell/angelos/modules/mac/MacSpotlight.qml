pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Spotlight of the Golden Gate skin (StartOverlay's look while the skin is on): a big dark glass
// capsule a fifth down the screen, the results under it in a glass panel by section — the
// calculator, apps, settings, folders, actions. On the capsule's right, like macOS 26/27, the
// browsing modes: Apps (every app as a grid — the Dock's Apps opens it too), Files (the folders),
// Actions and the Clipboard (its history). Ctrl+1…4 switch them, ↑↓ (←→ in the grid) choose,
// Enter opens, Esc clears and closes. Same interface as the other Start looks.
Item {
    id: root

    signal closeRequested
    property int current: 0
    // the pointer takes the selection only when it moves, as on a Mac: results appearing under
    // a still pointer leave the top hit selected. Moved = away from where it stood when these
    // results came (not between two events: a 1000 Hz mouse moves a pixel or less per event, and
    // the selection stuck until a fast flick); from then on it follows the pointer every event
    property var _anchor: null
    property bool _pointerMoved: false
    function pointed(area, m, index) {
        if (!_pointerMoved) {
            const p = area.mapToItem(null, m.x, m.y);
            if (!_anchor) {
                _anchor = p;
                return;
            }
            if (Math.abs(p.x - _anchor.x) + Math.abs(p.y - _anchor.y) < 3)
                return;
            _pointerMoved = true;
        }
        if (current !== index)
            current = index;
    }
    function _stillPointer() {
        _anchor = null;
        _pointerMoved = false;
    }
    onRowsChanged: _stillPointer()
    property string query: ""
    property string mode: ""                  // "" search | apps | files | actions | clipboard
    property real room: 0                     // StartOverlay: the screen's room for it
    readonly property bool searching: query.trim() !== ""
    // the screen's width (the Loader's parent is StartOverlay's window)
    readonly property real screenW: parent && parent.parent ? parent.parent.width : 1200
    readonly property real capW: Math.min(GoldenGate.px(680), Math.max(Math.min(GoldenGate.px(420), screenW - GoldenGate.px(32)), screenW * 0.46))
    readonly property real capH: GoldenGate.px(52)
    readonly property real rowH: GoldenGate.px(40)
    readonly property int maxRows: room > 0 ? Math.max(4, Math.min(10, Math.floor((room - capH - GoldenGate.px(40)) / rowH))) : 9
    readonly property int gridCols: Math.max(4, Math.floor((capW - GoldenGate.px(24)) / GoldenGate.px(104)))

    width: capW
    height: capH + (panel.visible ? panel.height + GoldenGate.px(10) : 0)

    function matches(label, q) {
        return String(label).toLowerCase().indexOf(q) >= 0;
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
    function plain(list, section, icon) {
        return list.map(r => ({
                    "section": section,
                    "label": r.label,
                    "sub": r.sub || "",
                    "mac": icon || "",
                    "run": r.run
                }));
    }
    readonly property var rows: {
        if (mode === "apps")
            return StartApps.apps.filter(a => !searching || matches(a.name, query.trim().toLowerCase())).map(a => appRow(a, ""));
        if (mode === "files")
            return plain(StartItems.places, I18n.t("Папки", "Folders"), "folder").filter(r => !searching || matches(r.label, query.trim().toLowerCase()));
        if (mode === "actions")
            return plain(StartItems.power.concat(StartItems.settings), I18n.t("Действия", "Actions"), "zap").filter(r => !searching || matches(r.label, query.trim().toLowerCase()));
        if (mode === "clipboard")
            return (Clipboard.history || []).slice(0, 40).map(e => ({
                        "section": I18n.t("Буфер обмена", "Clipboard"),
                        "label": e.kind === "image" ? I18n.t("Изображение", "Image") : String(e.text || "").replace(/\s+/g, " ").slice(0, 120),
                        "sub": e.kind === "image" ? String(e.path || "").split("/").pop() : "",
                        "mac": e.kind === "image" ? "image" : "copy",
                        "run": () => Clipboard.copy(e)
                    })).filter(r => !searching || matches(r.label, query.trim().toLowerCase()));
        if (!searching)
            return [];
        const q = query.trim().toLowerCase();
        const out = [];
        for (const r of StartApps.searchAll(query, 24)) {
            if (r.kind === "calc")
                out.push({
                    "section": I18n.t("Калькулятор", "Calculator"),
                    "label": r.calc.title,
                    "sub": r.calc.subtitle || I18n.t("Enter — скопировать", "Enter copies"),
                    "mac": "calculator",
                    "run": () => Calc.copy(r.calc)
                });
            else if (r.kind === "app")
                out.push(appRow(r.app, I18n.t("Приложения", "Applications")));
            else
                out.push({
                    "section": I18n.t("Системные настройки", "System Settings"),
                    "label": r.doc.title,
                    "sub": r.doc.crumb || r.doc.hint || "",
                    "mac": "settings",
                    "run": () => StartApps.openSetting(r.doc)
                });
        }
        for (const p of plain(StartItems.places, I18n.t("Папки", "Folders"), "folder"))
            if (matches(p.label, q))
                out.push(p);
        for (const a of plain(StartItems.power, I18n.t("Действия", "Actions"), "zap"))
            if (matches(a.label, q))
                out.push(a);
        const order = [];
        for (const r of out)
            if (!order.includes(r.section))
                order.push(r.section);
        return order.reduce((acc, s) => acc.concat(out.filter(r => r.section === s)), []).slice(0, 40);
    }
    readonly property bool grid: mode === "apps"

    function setQuery(t) {
        field.text = t;
        query = t;
        current = 0;
    }
    function reset() {
        _stillPointer();
        query = "";
        field.text = "";
        current = 0;
        mode = Shell.startMode || "";
        Shell.startMode = "";
        Qt.callLater(() => field.forceActiveFocus());
    }
    function setMode(m) {
        mode = mode === m ? "" : m;
        current = 0;
    }
    function runRow(r) {
        if (!r)
            return;
        closeRequested();
        Qt.callLater(r.run);
    }
    function move(d) {
        current = Math.max(0, Math.min(rows.length - 1, current + d));
        if (grid)
            gridView.positionViewAtIndex(current, GridView.Contain);
        else
            list.positionViewAtIndex(current, ListView.Contain);
    }
    function key(e) {
        if ((e.modifiers & Qt.ControlModifier) && e.key >= Qt.Key_1 && e.key <= Qt.Key_4) {
            setMode(["apps", "files", "actions", "clipboard"][e.key - Qt.Key_1]);
            e.accepted = true;
            return;
        }
        switch (e.key) {
        case Qt.Key_Down:
            move(grid ? gridCols : 1);
            break;
        case Qt.Key_Up:
            move(grid ? -gridCols : -1);
            break;
        case Qt.Key_Right:
            if (!grid)
                return;
            move(1);
            break;
        case Qt.Key_Left:
            if (!grid)
                return;
            move(-1);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            runRow(rows[current]);
            break;
        case Qt.Key_Escape:
            if (query !== "")
                setQuery("");
            else if (mode !== "")
                mode = "";
            else
                closeRequested();
            break;
        case Qt.Key_Backspace:
            field.text = field.text.slice(0, -1);
            query = field.text;
            break;
        default:
            if (e.text && e.text.trim() !== "" && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                field.text += e.text;
                query = field.text;
                current = 0;
            } else
                return;
        }
        e.accepted = true;
    }

    // ---- the capsule ----
    MacGlass {
        id: capsule
        width: parent.width
        height: root.capH
        radius: height / 2
        fill: GoldenGate.hell ? GoldenGate.glass(0.25) : Qt.rgba(0.08, 0.08, 0.09, 0.72 + GoldenGate.tint * 0.2)
        shadowSize: GoldenGate.px(36)
        shadowY: GoldenGate.px(10)
        MacIcon {
            id: lens
            x: GoldenGate.px(20)
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: GoldenGate.px(20)
            stroke: 2.2
            color: Qt.rgba(1, 1, 1, 0.6)
        }
        TextInput {
            id: field
            anchors.left: lens.right
            anchors.leftMargin: GoldenGate.px(12)
            anchors.right: modes.left
            anchors.rightMargin: GoldenGate.px(10)
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
            font.family: GoldenGate.font
            font.pixelSize: GoldenGate.px(22)
            selectionColor: GoldenGate.accent
            clip: true
            onTextEdited: {
                root.query = text;
                root.current = 0;
            }
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Down || e.key === Qt.Key_Up || e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Escape || ((e.modifiers & Qt.ControlModifier) && e.key >= Qt.Key_1 && e.key <= Qt.Key_4))
                    root.key(e);
            }
            MacText {
                visible: field.text === ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.mode === "apps" ? I18n.t("Поиск в приложениях", "Search Applications") : root.mode === "files" ? I18n.t("Поиск папок", "Search Folders") : root.mode === "actions" ? I18n.t("Поиск действий", "Search Actions") : root.mode === "clipboard" ? I18n.t("Поиск в буфере обмена", "Search Clipboard") : I18n.t("Поиск", "Search")
                size: GoldenGate.px(22)
                color: Qt.rgba(1, 1, 1, 0.45)
            }
        }
        // the browsing modes, as on macOS 26/27
        Row {
            id: modes
            anchors.right: parent.right
            anchors.rightMargin: GoldenGate.px(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: GoldenGate.px(4)
            Repeater {
                model: [["apps", "layout-grid"], ["files", "folder"], ["actions", "zap"], ["clipboard", "clipboard-paste"]]
                Rectangle {
                    id: mb
                    required property var modelData
                    width: GoldenGate.px(32)
                    height: width
                    radius: width / 2
                    color: root.mode === modelData[0] ? Qt.rgba(1, 1, 1, 0.24) : mbHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    MacIcon {
                        anchors.centerIn: parent
                        name: mb.modelData[1]
                        size: GoldenGate.px(17)
                        stroke: 2
                        color: Qt.rgba(1, 1, 1, 0.8)
                    }
                    HoverHandler {
                        id: mbHover
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.setMode(mb.modelData[0])
                    }
                }
            }
        }
    }

    // ---- the results ----
    MacGlass {
        id: panel
        visible: root.rows.length > 0
        y: root.capH + GoldenGate.px(10)
        width: parent.width
        height: root.grid ? Math.min(GoldenGate.px(460), gridView.contentHeight + GoldenGate.px(20)) : Math.min(root.maxRows, root.rows.length) * root.rowH + sections * GoldenGate.px(26) + GoldenGate.px(16)
        readonly property int sections: root.grid ? 0 : new Set(root.rows.slice(0, root.maxRows).map(r => r.section)).size
        radius: GoldenGate.panelRadius

        ListView {
            id: list
            visible: !root.grid
            anchors.fill: parent
            anchors.margins: GoldenGate.px(8)
            clip: true
            model: root.grid ? [] : root.rows
            boundsBehavior: Flickable.StopAtBounds
            section.property: "section"
            section.delegate: MacText {
                required property string section
                width: list.width
                height: section ? GoldenGate.px(26) : 0
                leftPadding: GoldenGate.px(10)
                text: section
                size: GoldenGate.smallSize
                semibold: true
                color: GoldenGate.secondaryLabel
            }
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: list.width
                height: root.rowH
                readonly property bool sel: root.current === index
                Rectangle {
                    anchors.fill: parent
                    radius: GoldenGate.px(10)
                    color: GoldenGate.accent
                    visible: row.sel
                }
                Image {
                    id: ic
                    visible: !!row.modelData.app
                    x: GoldenGate.px(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: GoldenGate.px(28)
                    height: width
                    sourceSize: Qt.size(width * 2, height * 2)
                    smooth: true
                    source: row.modelData.app && row.modelData.app.icon ? (String(row.modelData.app.icon).startsWith("/") ? "file://" + row.modelData.app.icon : Quickshell.iconPath(row.modelData.app.icon, true)) : ""
                }
                MacIcon {
                    visible: !row.modelData.app
                    x: GoldenGate.px(12)
                    anchors.verticalCenter: parent.verticalCenter
                    name: row.modelData.mac || "circle-help"
                    size: GoldenGate.px(20)
                    color: row.sel ? "#ffffff" : GoldenGate.label
                }
                MacText {
                    anchors.left: parent.left
                    anchors.leftMargin: GoldenGate.px(46)
                    anchors.right: subText.left
                    anchors.rightMargin: GoldenGate.px(8)
                    height: parent.height
                    text: row.modelData.label
                    color: row.sel ? "#ffffff" : GoldenGate.label
                }
                MacText {
                    id: subText
                    anchors.right: parent.right
                    anchors.rightMargin: GoldenGate.px(12)
                    width: Math.min(implicitWidth, parent.width * 0.4)
                    height: parent.height
                    text: row.modelData.sub
                    color: row.sel ? Qt.rgba(1, 1, 1, 0.8) : GoldenGate.secondaryLabel
                    size: GoldenGate.smallSize + GoldenGate.px(1)
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: m => root.pointed(this, m, row.index)
                    onClicked: root.runRow(row.modelData)
                }
            }
        }
        GridView {
            id: gridView
            visible: root.grid
            anchors.fill: parent
            anchors.margins: GoldenGate.px(10)
            clip: true
            cellWidth: width / root.gridCols
            cellHeight: GoldenGate.px(100)
            model: root.grid ? root.rows : []
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: gridView.cellWidth
                height: gridView.cellHeight
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: GoldenGate.px(3)
                    radius: GoldenGate.px(14)
                    color: root.current === cell.index ? Qt.alpha(GoldenGate.accent, 0.85) : "transparent"
                }
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: GoldenGate.px(10)
                    width: GoldenGate.px(56)
                    height: width
                    sourceSize: Qt.size(width * 2, height * 2)
                    smooth: true
                    source: cell.modelData.app && cell.modelData.app.icon ? (String(cell.modelData.app.icon).startsWith("/") ? "file://" + cell.modelData.app.icon : Quickshell.iconPath(cell.modelData.app.icon, true)) : ""
                }
                MacText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: GoldenGate.px(70)
                    width: parent.width - GoldenGate.px(8)
                    horizontalAlignment: Text.AlignHCenter
                    text: cell.modelData.label
                    size: GoldenGate.smallSize + GoldenGate.px(1)
                    color: root.current === cell.index ? "#ffffff" : GoldenGate.label
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: m => root.pointed(this, m, cell.index)
                    onClicked: root.runRow(cell.modelData)
                }
            }
        }
    }
}
