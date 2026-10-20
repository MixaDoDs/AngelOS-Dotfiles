pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Windows 11-like Start: search on top, pinned apps grid, "All apps" list,
// recommended row, user + power at the bottom. Right-click pins/unpins.
PxBox {
    id: root

    signal closeRequested
    // a right click on an app (StartApps.menuFor): StartOverlay opens the menu at x, y in `item`
    signal menuAsked(var items, Item item, real x, real y)
    property int current: -1
    property bool showAll: false
    property string query: ""
    // Settings → Bar → Start → Fine-tune (services/StartPrefs): width, the pinned grid,
    // icons, sections, colours, order
    readonly property var prefs: StartPrefs.of("win11")
    readonly property real sizeFactor: prefs.size
    readonly property int columns: prefs.columns > 0 ? Math.max(3, Math.min(10, prefs.columns)) : Math.max(4, Math.min(10, Math.round(6 * sizeFactor)))
    property real room: 0                       // StartOverlay: the screen's room for it

    // ---- the grid: every length is n units in whole pixels (px), so the menu can be any size
    // (Fine-tune → Scale, Width) and no edge, cell or icon lands between pixels ----
    function px(n) {
        return StartPrefs.px(prefs, n);
    }
    readonly property int iu: prefs.iu              // the art pixel of icons, a whole number
    // THE inset, from the outer edge: all four sides, above the footer, the footer's sides
    // (PxBox puts the content `inset` in from its edge: the frame; that is taken off)
    readonly property int pad: px(8)
    readonly property int gap: px(4)                // inside a section: rows, a row's own padding
    readonly property int sectionGap: px(6)         // between search, heading and body
    readonly property int innerW: width - pad * 2   // the column's width
    // a list row (search results, all apps, recommended): an icon box, then the text, always at textX
    readonly property int iconW: Math.max(px(12), iu * 12)
    readonly property int iconH: Math.max(px(11), iu * 11)
    readonly property int textX: gap + iconW + gap
    // pinned grid: whole-pixel cells; the pixels left over go to the sides, not into the cells
    readonly property int tileIcon: iu * Math.round(15 * prefs.icons)
    readonly property int cellW: Math.floor(innerW / columns)
    readonly property int cellH: Math.max(px(Math.round(22 * Math.max(0.8, prefs.icons))), tileIcon + px(7)) + (prefs.labels ? px(8) : 0)
    readonly property int gridSide: Math.floor((innerW - cellW * columns) / 2)
    // recommended: 2 a row
    readonly property bool recOn: !!prefs.recommended && !!prefs.pinned
    readonly property int recH: px(17)
    readonly property int recGap: px(2)
    readonly property int recRows: Math.ceil(recommended.length / 2)
    readonly property int recPart: recOn ? gap + Math.ceil(recHead.implicitHeight) + gap + recRows * recH + (recRows - 1) * recGap : 0
    readonly property int headH: Math.ceil(Math.max(head.implicitHeight, allBtn.implicitHeight))
    readonly property int footerH: prefs.user || prefs.power ? px(20) : 0
    // what is not the body: the menu's height = this + bodyH
    readonly property int chrome: pad + (prefs.search ? Math.ceil(field.implicitHeight) + sectionGap : 0) + headH + sectionGap + pad + (footerH > 0 ? footerH + inset : 0)
    // the pinned rows that fit in the room (big fonts, a big art pixel, a small screen): the
    // menu gives up rows rather than run off the screen
    readonly property int fitRows: room > 0 ? Math.floor((room - chrome - recPart) / cellH) : 6
    readonly property int maxRows: Math.max(1, Math.min(6, fitRows, prefs.rows > 0 ? prefs.rows : 3))
    // as many as the pins fill (no empty rows under a few pins), at most maxRows; the same in
    // every view, so the menu keeps its height between pinned, search and all apps
    readonly property int rows: prefs.pinned ? Math.max(1, Math.min(maxRows, Math.ceil(StartApps.pinned.length / columns))) : maxRows
    // the body (pinned + recommended, search results, all apps) is this tall in every view:
    // switching views never makes the menu jump, a long list scrolls inside
    readonly property int bodyH: rows * cellH + recPart
    readonly property color accentColor: prefs.accentColor
    readonly property var appList: StartPrefs.sorted("win11", StartApps.apps)
    // typing turns the grid into a Windows 11-like list: the calculator, apps and settings by relevance
    readonly property bool searching: query.trim() !== ""
    readonly property var results: searching ? StartApps.searchAll(query, 40) : []
    readonly property var shown: searching ? results : showAll || !prefs.pinned ? appList : StartApps.pinned.slice(0, columns * rows)
    readonly property var recommended: [
        {
            "text": I18n.t("Настройки", "Settings"),
            "hint": I18n.t("тема, обои, панель", "theme, wallpaper, bar"),
            "icon": "gear",
            "act": () => Shell.openSettings()
        },
        {
            "text": I18n.t("Обои", "Wallpaper"),
            "hint": I18n.t("выбрать картинку", "pick a picture"),
            "icon": "image",
            "act": () => Shell.openSettings("wallpaper")
        },
        {
            "text": I18n.t("Файлы", "Files"),
            "hint": I18n.t("домашняя папка", "home folder"),
            "icon": "folder",
            "act": () => Shell.exec([Config.system.fileManager || "xdg-open", Config.home])
        },
        {
            "text": I18n.t("Терминал", "Terminal"),
            "hint": Config.system.terminal || "kitty",
            "icon": "terminal",
            "act": () => Shell.terminal()
        },
        {
            "text": I18n.t("Обслуживание", "Maintenance"),
            "hint": I18n.t("проверить и почистить", "check and clean up"),
            "icon": "sparkle",
            "act": () => Care.open()
        }
    ]

    function setQuery(t) {
        field.text = t;
        query = t;
        current = t ? 0 : -1;
    }
    function reset() {
        current = -1;
        showAll = !prefs.pinned;
        query = "";
        field.text = "";
        if (prefs.typeSearch && prefs.search)
            Qt.callLater(() => field.focusField());
    }
    function run(app) {
        closeRequested();
        Qt.callLater(() => StartApps.launch(app));
    }
    // a search row: launch the app, open the setting, copy the sum
    function activate(row) {
        if (!row)
            return;
        if (!searching)
            run(row);
        else if (row.kind === "app")
            run(row.app);
        else if (row.kind === "setting")
            act(() => StartApps.openSetting(row.doc));
        else if (row.kind === "file")
            act(() => FileSearch.open(row.file));
        else if (row.kind === "calc") {
            Calc.copy(row.calc);
            if (row.calc.copy)
                closeRequested();
        }
    }
    function act(fn) {
        closeRequested();
        Qt.callLater(fn);
    }
    function move(dx, dy) {
        const n = shown.length;
        if (!n)
            return;
        if (current < 0) {
            current = 0;
            return;
        }
        const linear = (showAll && !query) || searching;
        const step = linear ? dy : dy * columns + dx;
        current = Math.max(0, Math.min(n - 1, current + (linear ? dy + dx : step)));
        if (showAll && !query)
            allList.positionViewAtIndex(current, ListView.Contain);
        if (searching)
            resultList.positionViewAtIndex(current, ListView.Contain);
    }
    // the overlay forwards the first key here; the search field takes the rest
    function key(e) {
        if (nav(e))
            return;
        if (e.text && e.text.trim() !== "" && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            field.text += e.text;
            query = field.text;
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
        else if (e.key === Qt.Key_Right && query === "")
            move(1, 0);
        else if (e.key === Qt.Key_Left && query === "")
            move(-1, 0);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
            activate(shown[Math.max(0, current)]);
        else
            return false;
        e.accepted = true;
        return true;
    }

    width: Math.round(prefs.unit * 250 * sizeFactor)
    height: chrome + bodyH
    color: Qt.alpha(Theme.menuSurface, prefs.alpha)
    edgeColor: Theme.menuBorder
    flat: true
    shadow: Config.appearance.shadows && prefs.shadow

    readonly property int selBorder: Math.max(1, Math.floor(iu / 2))

    component Tile: Item {
        id: tile
        required property var modelData
        required property int index
        readonly property bool sel: root.current === index
        width: root.cellW
        height: root.cellH
        Rectangle {
            anchors.fill: parent
            anchors.margins: root.iu
            color: tile.sel ? Qt.alpha(root.accentColor, 0.3) : tm.containsMouse ? Qt.alpha(root.accentColor, 0.14) : "transparent"
            border.width: tile.sel ? root.selBorder : 0
            border.color: root.accentColor
        }
        Column {
            anchors.centerIn: parent
            width: parent.width - root.gap
            spacing: root.px(2)
            AppIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                iconName: tile.modelData.icon || ""
                appId: tile.modelData.id || ""
                size: root.tileIcon
                scale: tm.pressed ? 0.88 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.ms(90)
                    }
                }
            }
            PxText {
                visible: root.prefs.labels
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tile.modelData.name || ""
                kind: "tiny"
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
        PxIcon {
            visible: StartApps.isPinned(tile.modelData) && !root.query
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.px(2)
            name: "pin"
            pixel: Math.max(1, root.iu - 1)
        }
        MouseArea {
            id: tm
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onEntered: root.current = tile.index
            onClicked: m => {
                const a = tile.modelData;
                if (m.button === Qt.MiddleButton)
                    StartApps.togglePin(a);
                else if (m.button === Qt.RightButton)
                    root.menuAsked(StartApps.menuFor(a, () => root.run(a)), tm, m.x, m.y);
                else
                    root.run(a);
            }
        }
    }
    // the icon of a list row: a fixed box, so the text after it starts at the same x on every row
    component RowIcon: StartGlyph {
        x: root.gap
        y: Math.floor((parent.height - height) / 2)
        width: root.iconW
        height: root.iconH
        iu: root.iu
    }

    Column {
        id: col
        x: root.pad - root.inset
        y: root.pad - root.inset
        width: root.innerW
        spacing: root.sectionGap

        PxField {
            id: field
            visible: root.prefs.search
            keepFocus: true
            width: parent.width
            height: Math.ceil(implicitHeight)
            icon: "search"
            placeholder: Config.launcher.settings !== false ? I18n.t("Приложения, настройки, 2+2…", "Apps, settings, 2+2…") : I18n.t("Поиск приложений…", "Search apps…")
            onEdited: {
                root.query = text;
                root.current = text ? 0 : -1;
            }
            onAccepted: if (root.shown.length)
                root.activate(root.shown[Math.max(0, root.current)])
            onKeyPressed: e => root.nav(e)
        }

        // the heading and "All apps ›": one height (the taller of the two) in every view
        Item {
            width: parent.width
            height: root.headH
            PxText {
                id: head
                text: root.query ? (root.results.length ? I18n.t("Лучшие совпадения", "Best matches") : I18n.t("Ничего не нашлось", "Nothing found")) : root.showAll ? I18n.t("Все приложения", "All apps") : I18n.t("Закреплённые", "Pinned")
                kind: "title"
                anchors.verticalCenter: parent.verticalCenter
            }
            PxButton {
                id: allBtn
                visible: !root.query && root.prefs.pinned
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                compact: true
                text: root.showAll ? I18n.t("‹ Назад", "‹ Back") : I18n.t("Все приложения ›", "All apps ›")
                onClicked: {
                    root.showAll = !root.showAll;
                    root.current = -1;
                }
            }
        }

        Item {
            width: parent.width
            height: root.bodyH

            // search results: one list, best first
            ListView {
                id: resultList
                visible: root.searching
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: visible ? root.results : []
                delegate: Rectangle {
                    id: hit
                    required property var modelData
                    required property int index
                    readonly property bool sel: root.current === index
                    readonly property bool isCalc: modelData.kind === "calc"
                    readonly property bool isFile: modelData.kind === "file"
                    width: resultList.width
                    height: isCalc ? root.px(22) : root.px(16)
                    color: sel ? Qt.alpha(root.accentColor, 0.3) : hm.containsMouse ? Qt.alpha(root.accentColor, 0.14) : "transparent"
                    border.width: sel ? root.selBorder : 0
                    border.color: root.accentColor
                    RowIcon {
                        app: hit.modelData.kind === "app" ? hit.modelData.app : null
                        file: hit.isFile ? hit.modelData.file : null
                        icon: hit.isCalc ? "calc" : hit.modelData.kind === "setting" ? hit.modelData.doc.icon || "gear" : hit.isFile ? FileSearch.pixelIcon(hit.modelData.file) : "sparkle"
                    }
                    Column {
                        x: root.textX
                        width: hitKind.x - root.gap - x
                        anchors.verticalCenter: parent.verticalCenter
                        PxText {
                            width: parent.width
                            elide: Text.ElideRight
                            kind: hit.isCalc ? "title" : "body"
                            font.bold: hit.sel || hit.isCalc
                            text: hit.isCalc ? hit.modelData.calc.title : hit.modelData.kind === "app" ? hit.modelData.app.name : hit.isFile ? hit.modelData.file.name : hit.modelData.doc.title
                        }
                        PxText {
                            width: parent.width
                            visible: text !== ""
                            elide: Text.ElideRight
                            kind: "tiny"
                            dim: true
                            text: hit.isCalc ? hit.modelData.calc.subtitle : hit.modelData.kind === "app" ? (hit.modelData.app.genericName || hit.modelData.app.comment || "") : hit.isFile ? FileSearch.where(hit.modelData.file) : (hit.modelData.doc.crumb || hit.modelData.doc.hint || "")
                        }
                    }
                    PxText {
                        id: hitKind
                        x: parent.width - root.gap - Math.ceil(implicitWidth)
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "tiny"
                        dim: true
                        text: hit.isCalc ? (hit.modelData.calc.copy ? "⧉" : "") : hit.modelData.kind === "app" ? I18n.t("приложение", "app") : hit.isFile ? (hit.modelData.file.isDir ? I18n.t("папка", "folder") : I18n.t("файл", "file")) : I18n.t("настройка", "setting")
                    }
                    MouseArea {
                        id: hm
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.current = hit.index
                        onClicked: m => {
                            const r = hit.modelData, mid = m.button === Qt.MiddleButton;
                            if (m.button === Qt.LeftButton || (r.kind !== "app" && !hit.isFile)) {
                                root.activate(r);
                            } else if (r.kind === "app") {
                                if (mid)
                                    StartApps.togglePin(r.app);
                                else
                                    root.menuAsked(StartApps.menuFor(r.app, () => root.activate(r)), hm, m.x, m.y);
                            } else {
                                const reveal = () => root.act(() => FileSearch.reveal(r.file));
                                if (mid)
                                    reveal();
                                else
                                    root.menuAsked(StartApps.fileMenuFor(reveal, () => root.activate(r)), hm, m.x, m.y);
                            }
                        }
                    }
                }
            }

            // pinned grid, centred: the leftover pixels are its side padding
            GridView {
                id: grid
                visible: !root.showAll && !root.searching
                x: root.gridSide
                width: root.cellW * root.columns
                height: root.rows * root.cellH
                cellWidth: root.cellW
                cellHeight: root.cellH
                interactive: count > root.columns * root.rows
                clip: true
                model: grid.visible ? root.shown : []
                delegate: Tile {}
            }

            Column {
                visible: root.recOn && !root.showAll && !root.searching
                y: grid.height + root.gap
                width: parent.width
                spacing: root.gap
                PxText {
                    id: recHead
                    text: I18n.t("Рекомендуем", "Recommended")
                    kind: "title"
                }
                Grid {
                    columns: 2
                    columnSpacing: root.recGap
                    rowSpacing: root.recGap
                    Repeater {
                        model: root.recommended
                        Rectangle {
                            id: rec
                            required property var modelData
                            required property int index
                            // two whole-pixel halves; an odd pixel goes to the right one
                            width: rec.index % 2 ? root.innerW - root.recGap - Math.floor((root.innerW - root.recGap) / 2) : Math.floor((root.innerW - root.recGap) / 2)
                            height: root.recH
                            color: rm.containsMouse ? Qt.alpha(root.accentColor, 0.14) : "transparent"
                            RowIcon {
                                icon: rec.modelData.icon
                            }
                            Column {
                                x: root.textX
                                width: rec.width - root.gap - x
                                anchors.verticalCenter: parent.verticalCenter
                                PxText {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: rec.modelData.text
                                }
                                PxText {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: rec.modelData.hint
                                    kind: "tiny"
                                    dim: true
                                }
                            }
                            MouseArea {
                                id: rm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.act(rec.modelData.act)
                            }
                        }
                    }
                }
            }

            // all apps, alphabetical with letter headers
            ListView {
                id: allList
                visible: root.showAll && root.query === ""
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: allList.visible ? root.shown : []
                delegate: Item {
                    id: li
                    required property var modelData
                    required property int index
                    readonly property string letter: String(modelData.name || "?").charAt(0).toUpperCase()
                    readonly property bool first: index === 0 || letter !== String(root.shown[index - 1].name || "?").charAt(0).toUpperCase()
                    readonly property int letterH: first ? Math.ceil(letterText.implicitHeight) + root.px(2) : 0
                    width: allList.width
                    height: li.letterH + row.height
                    PxText {
                        id: letterText
                        visible: li.first
                        x: root.gap
                        text: li.letter
                        kind: "title"
                        color: root.accentColor
                        topPadding: root.px(2)
                    }
                    Rectangle {
                        id: row
                        y: li.letterH
                        width: allList.width
                        height: root.px(14)
                        color: root.current === li.index ? Qt.alpha(root.accentColor, 0.3) : lm.containsMouse ? Qt.alpha(root.accentColor, 0.14) : "transparent"
                        RowIcon {
                            app: li.modelData
                            appSize: root.iu * Math.round(10 * root.prefs.icons)
                        }
                        PxText {
                            x: root.textX
                            width: parent.width - root.gap - x
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                            text: li.modelData.name
                        }
                        MouseArea {
                            id: lm
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.current = li.index
                            onClicked: m => {
                                const a = li.modelData;
                                if (m.button === Qt.MiddleButton)
                                    StartApps.togglePin(a);
                                else if (m.button === Qt.RightButton)
                                    root.menuAsked(StartApps.menuFor(a, () => root.run(a)), lm, m.x, m.y);
                                else
                                    root.run(a);
                            }
                        }
                    }
                }
            }
        }
    }

    // user + the button row, on the same inset as everything above
    Rectangle {
        id: footer
        visible: root.footerH > 0
        anchors.bottom: parent.bottom
        width: parent.width
        height: root.footerH
        color: Qt.alpha(Theme.menuHeader, 0.55)
        Rectangle {
            width: parent.width
            height: root.iu
            color: Theme.menuBorder
        }
        StartUser {
            visible: root.prefs.user
            x: root.pad - root.inset
            y: Math.floor((parent.height - height) / 2)
            size: root.iu * 13
            frameColor: root.accentColor
            onOpened: root.closeRequested()
        }
        // the buttons (the user's, Settings → Start buttons): equal cells, right-aligned on the
        // inset, vertically centred
        StartButtonRow {
            visible: root.prefs.power
            unit: root.prefs.unit
            iu: root.iu
            x: parent.width - (root.pad - root.inset) - width
            y: Math.floor((parent.height - height) / 2)
        }
    }
}
