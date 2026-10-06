pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// iPhone-like Start: the whole screen, pages of big app icons, a dock with the
// pinned apps, search on top. Wheel / arrows / PgUp-PgDn flip pages.
Item {
    id: root

    signal closeRequested
    property real reveal: 1            // 0 → 1 while opening (driven by StartOverlay)
    property int current: -1
    property string query: ""
    // Settings → Bar → Start → Fine-tune (services/StartPrefs)
    readonly property var prefs: StartPrefs.of("fullscreen")
    readonly property color accentColor: prefs.accentColor
    readonly property int tile: Math.round(Theme.u * 46 * prefs.icons)
    readonly property int autoColumns: Math.max(3, Math.min(8, Math.floor((width - Theme.u * 40) / tile)))
    readonly property int autoRows: Math.max(2, Math.min(5, Math.floor((height - Theme.u * 150) / (tile + Theme.u * 8))))
    readonly property int columns: prefs.columns > 0 ? Math.min(prefs.columns, Math.max(2, Math.floor((width - Theme.u * 20) / (tile + Theme.u * 4)))) : autoColumns
    readonly property int rows: prefs.rows > 0 ? Math.min(prefs.rows, Math.max(1, Math.floor((height - Theme.u * 120) / (tile + Theme.u * 16)))) : autoRows
    readonly property int perPage: columns * rows
    readonly property var list: query.trim() !== "" ? StartApps.search(query).slice(0, perPage) : StartPrefs.sorted("fullscreen", StartApps.apps)
    // like Spotlight: the sum and matching settings above the apps; Enter opens the best match
    readonly property var hits: query.trim() !== "" ? StartApps.searchAll(query, 30) : []
    // (no app matches — ".jpeg" — leaves room for more files)
    readonly property var extras: hits.filter(r => r.kind !== "app").slice(0, list.length ? 4 : 8)
    function activate(row) {
        if (!row)
            return;
        if (row.kind === "app")
            run(row.app);
        else if (row.kind === "setting") {
            closeRequested();
            Qt.callLater(() => StartApps.openSetting(row.doc));
        } else if (row.kind === "file") {
            closeRequested();
            Qt.callLater(() => FileSearch.open(row.file));
        } else if (row.kind === "calc") {
            Calc.copy(row.calc);
            if (row.calc.copy)
                closeRequested();
        }
    }
    readonly property int pageCount: Math.max(1, Math.ceil(list.length / perPage))
    readonly property var dock: prefs.pinned ? StartApps.pinned.slice(0, Math.min(7, columns)) : []
    readonly property int page: pages.currentIndex

    function setQuery(t) {
        field.text = t;
        query = t;
        current = -1;
    }
    function reset() {
        current = -1;
        query = "";
        field.text = "";
        pages.positionViewAtIndex(0, ListView.Beginning);
        pages.currentIndex = 0;
    }
    function run(app) {
        closeRequested();
        Qt.callLater(() => StartApps.launch(app));
    }
    function flip(step) {
        pages.currentIndex = Math.max(0, Math.min(pageCount - 1, pages.currentIndex + step));
        current = -1;
    }
    function move(dx, dy) {
        const start = page * perPage;
        const count = Math.min(perPage, list.length - start);
        if (count <= 0)
            return;
        if (current < start || current >= start + count) {
            current = start;
            return;
        }
        const i = current - start;
        let col = i % columns + dx, row = Math.floor(i / columns) + dy;
        if (col < 0 && page > 0) {
            flip(-1);
            current = page * perPage + Math.min(perPage - 1, row * columns + columns - 1);
            return;
        }
        if (col >= columns && page < pageCount - 1) {
            flip(1);
            current = page * perPage + Math.min(row * columns, list.length - page * perPage - 1);
            return;
        }
        col = Math.max(0, Math.min(columns - 1, col));
        row = Math.max(0, Math.min(rows - 1, row));
        current = start + Math.min(count - 1, row * columns + col);
    }
    function key(e) {
        if (nav(e))
            return;
        if (e.text && e.text.trim() !== "" && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            field.text += e.text;
            query = field.text;
            pages.currentIndex = 0;
            field.focusField();
            e.accepted = true;
        }
    }
    function nav(e) {
        if (e.key === Qt.Key_Escape || e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R)
            closeRequested();
        else if (e.key === Qt.Key_Down)
            move(0, 1);
        else if (e.key === Qt.Key_Up)
            move(0, -1);
        else if (e.key === Qt.Key_Right)
            move(1, 0);
        else if (e.key === Qt.Key_Left)
            move(-1, 0);
        else if (e.key === Qt.Key_PageDown)
            flip(1);
        else if (e.key === Qt.Key_PageUp)
            flip(-1);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            if (current < 0 && hits.length)
                activate(hits[0]);
            else
                run(list[Math.max(page * perPage, current)]);
        }
        else
            return false;
        e.accepted = true;
        return true;
    }

    // dim + tint over the blurred desktop
    Rectangle {
        anchors.fill: parent
        // Fine-tune → Opacity: how much of the desktop shows through
        color: Qt.alpha(Theme.dark ? "#05060a" : Theme.desk, root.prefs.opacity > 0 ? root.prefs.opacity / 100 : Theme.dark ? 0.55 : 0.45)
        opacity: root.reveal
    }
    MouseArea {
        // empty space closes, the wheel flips pages
        anchors.fill: parent
        onClicked: root.closeRequested()
        onWheel: w => root.flip(w.angleDelta.y > 0 || w.angleDelta.x > 0 ? -1 : 1)
    }

    component AppTile: Item {
        id: t
        required property var app
        property int gindex: -1                 // index in root.list
        property bool dockTile: false
        readonly property bool sel: !dockTile && root.current === gindex
        // cascade: tiles near the centre land first
        property real delay: 0
        readonly property real appear: Math.max(0, Math.min(1, root.reveal * 1.6 - delay * 0.6))
        width: root.tile
        height: root.tile + (dockTile ? 0 : Theme.u * 10)
        opacity: appear
        scale: (0.6 + 0.4 * appear) * (m.pressed ? 0.9 : m.containsMouse || sel ? 1.06 : 1)
        Behavior on scale {
            NumberAnimation {
                duration: Motion.ms(120)
                easing.type: Easing.OutCubic
            }
        }
        Rectangle {
            id: plate
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.tile - Theme.u * 8
            height: width
            radius: width * 0.26
            color: Qt.alpha(Theme.face, Theme.dark ? 0.82 : 0.9)
            border.width: t.sel ? Theme.u : Math.max(1, Theme.u / 2)
            border.color: t.sel ? root.accentColor : Qt.alpha(Theme.edge, 0.35)
            AppIcon {
                anchors.centerIn: parent
                iconName: t.app ? t.app.icon || "" : ""
                appId: t.app ? t.app.id || "" : ""
                size: Math.round(plate.width * 0.68)
            }
            Rectangle {
                visible: !!t.app && StartApps.isPinned(t.app) && !t.dockTile
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: -Theme.u
                width: Theme.u * 5
                height: width
                radius: width / 2
                color: root.accentColor
            }
        }
        PxText {
            visible: !t.dockTile && root.prefs.labels
            anchors.top: plate.bottom
            anchors.topMargin: Theme.u * 2
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.tile + Theme.u * 4
            horizontalAlignment: Text.AlignHCenter
            text: t.app ? t.app.name : ""
            kind: "tiny"
            elide: Text.ElideRight
            color: "#ffffff"
            style: Text.Outline
            styleColor: Qt.alpha("#000000", 0.55)
        }
        MouseArea {
            id: m
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onEntered: if (!t.dockTile)
                root.current = t.gindex
            onClicked: e => e.button === Qt.RightButton ? StartApps.togglePin(t.app) : root.run(t.app)
        }
    }

    // ---- clock + search ----
    Column {
        id: top
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.u * 18 - (1 - root.reveal) * Theme.u * 16
        opacity: root.reveal
        spacing: Theme.u * 3
        PxText {
            id: clock
            visible: root.prefs.clock
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "big"
            font.pixelSize: Theme.sizeBig * 2
            color: "#ffffff"
            style: Text.Outline
            styleColor: Qt.alpha("#000000", 0.35)
            text: I18n.time(now.date, false)
        }
        PxText {
            visible: root.prefs.clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ffffff"
            text: now.date.toLocaleDateString(I18n.locale, "dddd, d MMMM")
        }
        Item {
            width: 1
            height: Theme.u * 4
        }
        PxField {
            id: field
            visible: root.prefs.search
            keepFocus: true
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(root.width - Theme.u * 40, Theme.u * 170)
            icon: "search"
            placeholder: Config.launcher.settings !== false ? I18n.t("Поиск: приложения, настройки, 2+2", "Search: apps, settings, 2+2") : I18n.t("Поиск", "Search")
            onEdited: {
                root.query = text;
                root.current = -1;
                pages.currentIndex = 0;
            }
            onAccepted: {
                if (root.current < 0 && root.hits.length)
                    root.activate(root.hits[0]);
                else if (root.list.length)
                    root.run(root.list[Math.max(0, root.current)]);
            }
            onKeyPressed: e => root.nav(e)
        }
        // the calculator and settings found
        Column {
            visible: root.extras.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            width: field.width
            spacing: Theme.u * 2
            Repeater {
                model: root.extras
                Rectangle {
                    id: extra
                    required property var modelData
                    required property int index
                    readonly property bool best: root.current < 0 && root.hits.length > 0 && root.hits[0] === modelData
                    readonly property bool isCalc: modelData.kind === "calc"
                    readonly property bool isFile: modelData.kind === "file"
                    width: parent.width
                    height: (isCalc ? Theme.u * 22 : Theme.u * 17)
                    radius: Theme.u * 6
                    color: Qt.alpha(Theme.panel, best || em.containsMouse ? 0.8 : 0.55)
                    border.width: best ? Math.max(1, Theme.u / 2) : 0
                    border.color: Qt.alpha("#ffffff", 0.6)
                    PxIcon {
                        id: extraIcon
                        x: Theme.u * 5
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: extraThumb.ok ? 0 : 1
                        name: extra.isCalc ? "calc" : extra.isFile ? FileSearch.pixelIcon(extra.modelData.file) : extra.modelData.doc.icon || "gear"
                    }
                    FileThumb {
                        id: extraThumb
                        visible: ok
                        anchors.centerIn: extraIcon
                        width: Theme.u * 13
                        height: width
                        hit: extra.isFile ? extra.modelData.file : null
                    }
                    Column {
                        anchors.left: extraIcon.right
                        anchors.leftMargin: Theme.u * 5
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.u * 5
                        anchors.verticalCenter: parent.verticalCenter
                        PxText {
                            width: parent.width
                            elide: Text.ElideRight
                            kind: extra.isCalc ? "title" : "body"
                            font.bold: true
                            text: extra.isCalc ? extra.modelData.calc.title : extra.isFile ? extra.modelData.file.name : extra.modelData.doc.title
                        }
                        PxText {
                            width: parent.width
                            visible: text !== ""
                            elide: Text.ElideRight
                            kind: "tiny"
                            dim: true
                            text: extra.isCalc ? extra.modelData.calc.subtitle : extra.isFile ? FileSearch.where(extra.modelData.file) : I18n.t("Настройки", "Settings") + (extra.modelData.doc.crumb ? " › " + extra.modelData.doc.crumb : "")
                        }
                    }
                    MouseArea {
                        id: em
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activate(extra.modelData)
                    }
                }
            }
        }
    }
    SystemClock {
        id: now
        precision: SystemClock.Minutes
    }

    // ---- pages of apps ----
    ListView {
        id: pages
        anchors.top: top.bottom
        anchors.topMargin: Theme.u * 12
        anchors.bottom: dots.top
        anchors.bottomMargin: Theme.u * 4
        width: parent.width
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: 260
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        model: root.pageCount
        delegate: Item {
            id: pg
            required property int index
            width: pages.width
            height: pages.height
            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: root.columns
                columnSpacing: Theme.u * 4
                rowSpacing: Theme.u * 6
                Repeater {
                    // pg is gone for a moment while the pages are rebuilt (the list changed)
                    model: pg ? root.list.slice(pg.index * root.perPage, (pg.index + 1) * root.perPage) : []
                    AppTile {
                        required property var modelData
                        required property int index
                        app: modelData
                        gindex: (pg ? pg.index * root.perPage : 0) + index
                        // cascade outwards from the centre of the page
                        delay: Math.min(1, Math.hypot((index % root.columns - (root.columns - 1) / 2) / root.columns, (Math.floor(index / root.columns) - (root.rows - 1) / 2) / root.rows) * 1.4)
                    }
                }
            }
        }
    }
    Row {
        id: dots
        anchors.bottom: dockBar.top
        anchors.bottomMargin: Theme.u * 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.u * 3
        visible: root.pageCount > 1
        opacity: root.reveal
        Repeater {
            model: root.pageCount
            Rectangle {
                required property int index
                width: index === root.page ? Theme.u * 8 : Theme.u * 3
                height: Theme.u * 3
                radius: height / 2
                color: index === root.page ? "#ffffff" : Qt.alpha("#ffffff", 0.45)
                Behavior on width {
                    NumberAnimation {
                        duration: Motion.ms(160)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Theme.u * 2
                    onClicked: pages.currentIndex = parent.index
                }
            }
        }
    }

    // the user and power, top left (Fine-tune → Sections)
    Row {
        x: Theme.u * 12
        y: Theme.u * 12 - (1 - root.reveal) * Theme.u * 16
        opacity: root.reveal
        spacing: Theme.u * 6
        StartUser {
            visible: root.prefs.user
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.u * 18
            frameColor: root.accentColor
            textColor: "#ffffff"
            kind: "title"
            onOpened: root.closeRequested()
        }
        Row {
            visible: root.prefs.power
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.u * 3
            PxButton {
                compact: true
                icon: "lock"
                onClicked: {
                    root.closeRequested();
                    Qt.callLater(() => Shell.lock());
                }
            }
            PxButton {
                compact: true
                icon: "power"
                onClicked: {
                    root.closeRequested();
                    Qt.callLater(() => Shell.sessionOpen = true);
                }
            }
        }
    }

    // ---- dock ----
    Rectangle {
        id: dockBar
        visible: root.dock.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.u * 10 - (1 - root.reveal) * Theme.u * 30
        width: dockRow.width + Theme.u * 12
        height: root.tile + Theme.u * 6
        radius: Theme.u * 12
        color: Qt.alpha(Theme.panel, 0.55)
        border.width: Math.max(1, Theme.u / 2)
        border.color: Qt.alpha("#ffffff", 0.25)
        opacity: root.reveal
        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: Theme.u * 3
            Repeater {
                model: root.dock
                AppTile {
                    required property var modelData
                    app: modelData
                    dockTile: true
                }
            }
        }
    }
}
